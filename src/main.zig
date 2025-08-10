const std = @import("std");
const Chameleon = @import("chameleon");

// TODO: Optimize this pile of garbage
pub fn playWithWord(allocator: std.mem.Allocator, word: []const u8) !void {
    var cham = Chameleon.initRuntime(.{
        .allocator = allocator,
    });
    defer cham.deinit();
    if (cham.no_color) {
        return error.NeedsColor;
    }
    _ = cham.black();
    cham.preset = true;

    var word_lcount = std.hash_map.AutoHashMapUnmanaged(u8, usize).empty;
    defer word_lcount.deinit(allocator);

    for (word) |c| {
        try word_lcount.put(allocator, c, (word_lcount.get(c) orelse 0)+1);
    }

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    {
        const bad = try cham.bgGrey().fmt(" ", .{});
        const okay = try cham.bgYellow().fmt(" ", .{});
        const good = try cham.bgGreen().fmt(" ", .{});
        try stdout.print(
            \\======================Welcome to wordle!====================
            \\Keys:
            \\    - {s}: Letter is not in the word
            \\    - {s}: Letter is in the word, but not in that position
            \\    - {s}: Letter is in the word, and in that position
            \\============================================================
            \\
            \\
        , .{bad, okay, good});
        allocator.free(bad);
        allocator.free(okay);
        allocator.free(good);
    }

    var attempts: usize = 1;
    var is_correct = false;
    while (attempts <= 6) {
        try stdout.print("Guess a {} letter word: ", .{word.len});

        var guess = std.ArrayListUnmanaged(u8).empty;
        defer guess.deinit(allocator);
        try stdin.streamUntilDelimiter(guess.writer(allocator), '\n', null);
        if (guess.getLastOrNull() == '\n') {
            _ = guess.pop();
        }
        if (guess.getLastOrNull() == '\r') {
            _ = guess.pop();
        }

        _ = std.ascii.upperString(guess.items, guess.items);

        if (guess.items.len != word.len) {
            try stdout.print("The word must contain {} letters!\n", .{word.len});
            continue;
        }

        if (std.mem.eql(u8, guess.items, word)) {
            is_correct = true;
            try cham.bgGreen().print(stdout, "{s}\n", .{word});
            break;
        }

        var correct_lcount = std.hash_map.AutoHashMapUnmanaged(u8, usize).empty;
        defer correct_lcount.deinit(allocator);

        // 0 is grey, 1 is yellow, 2 is green
        const letter_colors = try allocator.alloc(u2, word.len);
        defer allocator.free(letter_colors);

        for (guess.items, word, 0..) |gc, wc, i| {
            if (!std.mem.containsAtLeastScalar(u8, word, 1, gc)) {
                letter_colors[i] = 0;
                continue;
            }
            if ((correct_lcount.get(gc) orelse 0) < word_lcount.get(gc).? and gc != wc) {
                letter_colors[i] = 1;
                try correct_lcount.put(allocator, gc, (correct_lcount.get(gc) orelse 0)+1);
                continue;
            }
            if (gc == wc) {
                letter_colors[i] = 2;
                try correct_lcount.put(allocator, gc, (correct_lcount.get(gc) orelse 0)+1);
                if (correct_lcount.get(gc).? > word_lcount.get(gc).?) {
                    for (letter_colors[0..i], 0..) |let_col, ii| {
                        if (let_col == 1 and guess.items[ii] == gc) {
                            letter_colors[ii] = 0;
                            try correct_lcount.put(allocator, gc, correct_lcount.get(gc).?-1);
                            break;
                        }
                    }
                }
                continue;
            }
            letter_colors[i] = 0;
        }

        for (guess.items, letter_colors) |c, col| {
            switch (col) {
                0 => try cham.bgGrey().print(stdout, "{c}", .{c}),
                1 => try cham.bgYellow().print(stdout, "{c}", .{c}),
                2 => try cham.bgGreen().print(stdout, "{c}", .{c}),
                else => unreachable,
            }
        }
        try stdout.writeByte('\n');

        attempts += 1;
    }

    if (is_correct) {
        try stdout.print("You got it right! You guessed it in {} attempts\n", .{attempts});
    } else {
        try stdout.print("Better luck next time! The word was {s}\n", .{word});
    }
}

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var cli = std.http.Client{
        .allocator = allocator,
    };
    defer cli.deinit();

    var word = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 9);
    defer word.deinit(allocator);
    const res = cli.fetch(.{
        .location = .{ .url = "https://random-word-api.vercel.app/api?words=1&length=5&type=uppercase", },
        .method = .GET,
        .response_storage = .{ .static = &word, },
    }) catch |e| {
        std.debug.print("ERR: Unable to get a word: {}\n", .{e});
        return e;
    };

    if (res.status.class() != .success) {
        std.debug.print("ERR: Unable to get a word: {s} ({})\n", .{res.status.phrase() orelse "Unknown", @intFromEnum(res.status)});
        return error.CouldNotFetchWord;
    }

    try playWithWord(allocator, word.items[2..7]);
}
