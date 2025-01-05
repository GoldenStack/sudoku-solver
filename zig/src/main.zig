const std = @import("std");
const sudoku = @import("sudoku.zig");
const examples = @import("examples.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // Verify that the code can actually solve the examples
    try stdout.print("Verified Easy: {any}\n", .{examples.verify_example(examples.EASY, examples.EASY_SOLUTION)});
    try stdout.print("Verified Medium: {any}\n", .{examples.verify_example(examples.MEDIUM, examples.MEDIUM_SOLUTION)});
    try stdout.print("Verified Hard: {any}\n", .{examples.verify_example(examples.HARD, examples.HARD_SOLUTION)});

    // Test settings
    const warmup_iterations = 50_000;
    const iterations = 500_000;

    const test_case = examples.EASY;

    // Warmup rounds
    try stdout.print("Warming up...\n", .{});
    for (0..warmup_iterations) |_| {
        var raw_board = sudoku.board_from_tiles(test_case);
        const board = &raw_board;
        _ = sudoku.solve(board);
    }

    // Actual testing
    try stdout.print("Starting iterations...\n", .{});
    const start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        var raw_board = sudoku.board_from_tiles(test_case);
        const board = &raw_board;
        _ = sudoku.solve(board);
    }

    const duration = std.time.nanoTimestamp() - start;

    const duration_float = @as(f64, @floatFromInt(duration));
    const iterations_float = @as(f64, @floatFromInt(iterations));

    const ns_per_iter = duration_float / iterations_float;
    const duration_ms = duration_float / 1e6;
    const per_second = 1e9 / ns_per_iter;

    try stdout.print("Average time for {} iterations: {d:.3}µs (took {d:.3}ms; {d:.0}/sec)\n", .{ iterations, ns_per_iter / 1000, duration_ms, per_second });
}
