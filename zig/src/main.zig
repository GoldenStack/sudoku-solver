const std = @import("std");
const sudoku = @import("sudoku.zig");
const examples = @import("examples.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var raw_board = sudoku.board_from_tiles(examples.EASY);
    const board = &raw_board;

    if (!sudoku.solve(board)) {
        std.debug.print("SOMETHING WENT VERY WRONG!!!\n", .{});
    }

    // const result = examples.verify_example(examples.EASY, examples.EASY_SOLUTION);

    // try stdout.print("{any}", .{result});

    _ = stdout;
}
