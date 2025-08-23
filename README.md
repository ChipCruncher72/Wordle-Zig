# A wordle game written in Zig

A simple wordle clone written in the [Zig Programming Language](https://ziglang.org/)


## Download

### Prerequisites:
- [git](https://git-scm.com/)
- [Zig 0.15.\*](https://ziglang.org/download/) (This code will not work with the master branch or any version prior to 0.15)
- A working terminal

Clone the repository and cd into it
```sh
~ $ git clone https://github.com/ChipCruncher72/Wordle-Zig
~ $ cd Wordle-Zig
```
Then run `zig build` and find the executable in `zig-out/bin`
```sh
Wordle-Zig $ zig build --release=fast
Wordle-Zig $ ls zig-out/bin
wordle_term       wordle_term.pdb
```
And that's it! All you have to do now is guess the word in six attempts!


## Notes
- You need a stable internet connection if you want to play, the program gets it's words from an API call
- Report any issues [here](https://github.com/ChipCruncher72/Wordle-Zig/issues/new/choose)
- Your terminal will need to support true color and not have the enviroment variable `NO_COLOR` set
