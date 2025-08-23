const std = @import("std");

// TODO: Optimize this pile of garbage
pub fn playWithWord(allocator: std.mem.Allocator, word: []const u8) !void {
    var word_lcount = std.hash_map.AutoHashMapUnmanaged(u8, usize).empty;
    defer word_lcount.deinit(allocator);

    for (word) |c| {
        try word_lcount.put(allocator, c, (word_lcount.get(c) orelse 0)+1);
    }

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(stdout_buf[0..]);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(stdin_buf[0..]);
    const stdin = &stdin_reader.interface;

    try stdout.print(
        \\======================Welcome to wordle!====================
        \\Keys:
        \\    - {s}: Letter is not in the word
        \\    - {s}: Letter is in the word, but not in that position
        \\    - {s}: Letter is in the word, and in that position
        \\============================================================
        \\
        \\
    , .{"\x1b[100m \x1b[0m", "\x1b[43m \x1b[0m", "\x1b[42m \x1b[0m"});

    var attempts: usize = 1;
    var is_correct = false;
    while (attempts <= 6) {
        try stdout.print("Guess a {} letter word: ", .{word.len});
        try stdout.flush();

        var guess: std.ArrayList(u8) = undefined;
        {
            var alloc_writer = std.Io.Writer.Allocating.init(allocator);
           _ = try stdin.streamDelimiter(&alloc_writer.writer, '\n');
           _ = try stdin.takeByte();
            guess = alloc_writer.toArrayList();
        }
        defer guess.deinit(allocator);
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
            try stdout.print("\x1b[30;42m{s}\x1b[0m\n", .{guess.items});
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

        try stdout.writeAll("\x1b[30m");
        for (guess.items, letter_colors) |c, col| {
            switch (col) {
                0 => try stdout.writeAll("\x1b[100m"),
                1 => try stdout.writeAll("\x1b[43m"),
                2 => try stdout.writeAll("\x1b[42m"),
                else => unreachable,
            }
            try stdout.writeByte(c);
        }
        try stdout.writeAll("\x1b[0m");
        try stdout.writeByte('\n');

        attempts += 1;
    }

    if (is_correct) {
        try stdout.print("You got it right! You guessed it in {} attempts\n", .{attempts});
    } else {
        try stdout.print("Better luck next time! The word was {s}\n", .{word});
    }
    try stdout.flush();
}

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    if (std.process.hasEnvVarConstant("NO_COLOR")) {
        return error.NeedsColor;
    }

    var cli = std.http.Client{
        .allocator = allocator,
    };
    defer cli.deinit();

    var word: [9]u8 = undefined;
    var buffer_writer = std.Io.Writer.fixed(word[0..]);
    const res = cli.fetch(.{
        .location = .{ .url = "https://random-word-api.vercel.app/api?words=1&length=5&type=uppercase", },
        .method = .GET,
        .response_writer = &buffer_writer,
    }) catch |e| {
        std.debug.print("ERR: Unable to get a word: {}\n", .{e});
        return e;
    };

    if (res.status.class() != .success) {
        std.debug.print("ERR: Unable to get a word: {s} ({})\n", .{res.status.phrase() orelse "Unknown", @intFromEnum(res.status)});
        return error.CouldNotFetchWord;
    }

    try playWithWord(allocator, word[2..7]);
}
