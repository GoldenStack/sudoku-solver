const std = @import("std");

/// Determine the static list of 20 neighbors for the given tile.
pub fn neighbors_for_tile(x: u8, y: u8) [20]NeighborLUT {
    @setEvalBranchQuota(10000);

    // Manually track the index because it's simpler to avoid having a compile-
    // time allocated list.
    var neighbors = [_]NeighborLUT{0} ** 20;
    var index: NeighborLUT = 0;

    const block_x = (x / 3) * 3;
    const block_y = (y / 3) * 3;

    for (block_x..block_x + 3) |ax| {
        for (block_y..block_y + 3) |ay| {
            if (ax != x or ay != y) {
                neighbors[index] = ay * 9 + ax;
                index += 1;
            }
        }
    }

    for (0..9, 0..9) |row, col| {
        if (x / 3 != col / 3) {
            neighbors[index] = col + y * 9;
            index += 1;
        }

        if (y / 3 != row / 3) {
            neighbors[index] = x + row * 9;
            index += 1;
        }
    }

    if (index != 20) {
        @compileError("Expected exactly 20 neighbors for each tile!");
    }

    return neighbors;
}

/// Determine the list of 20 neighbors for each of the 81 tiles.
fn neighbors_for_board() [81][20]NeighborLUT {
    var items = [_][20]NeighborLUT{[_]NeighborLUT{0} ** 20} ** 81;

    for (&items, 0..) |*item, index| {
        item.* = neighbors_for_tile(index % 9, index / 9);
    }

    return items;
}

pub const Neighbors = neighbors_for_board();

pub fn row_col_sqr_for_tile(index: usize) struct { Index, Index, Index } {
    const row = index / 9;
    const col = index % 9;
    const sqr = (row / 3) * 3 + col / 3;

    return .{ row, col, sqr };
}

fn row_col_sqr_for_board() [81]struct { Index, Index, Index } {
    var items: [81]struct { Index, Index, Index } = undefined;

    for (&items, 0..) |*item, index| {
        item.* = row_col_sqr_for_tile(index);
    }

    return items;
}

pub const RCS = row_col_sqr_for_board();

pub const Tile = u32;
pub const NeighborLUT = u16;

pub const Mask = u32;

pub const Index = u8;

pub const Board = struct {
    states: [81]Tile,
    row_mask: [9]Mask,
    col_mask: [9]Mask,
    sqr_mask: [9]Mask,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.writeAll("===== BOARD =====\n");
        for (0..9) |row| {
            for (0..9) |col| {
                const state = self.states[row * 9 + col];
                if (state == std.math.maxInt(Tile)) {
                    try writer.print("_ ", .{});
                } else {
                    try writer.print("{} ", .{std.math.log2(state)});
                }
            }
            try writer.writeAll("\n");
        }

        try writer.writeAll("\n=== REMAINING ===\n");
        try writer.writeAll("rows: \n");
        for (0..9) |row| {
            try writer.print("{}: ", .{row});
            for (0..9) |val| {
                if (self.row_mask[row] & (@as(Tile, 1) << @truncate(val)) != 0) {
                    try writer.print("{} ", .{val});
                }
            }
            try writer.writeAll("\n");
        }

        try writer.writeAll("\ncolumns: \n");
        for (0..9) |col| {
            try writer.print("{}: ", .{col});
            for (0..9) |val| {
                if (self.col_mask[col] & (@as(Tile, 1) << @truncate(val)) != 0) {
                    try writer.print("{} ", .{val});
                }
            }
            try writer.writeAll("\n");
        }

        try writer.writeAll("\nsquares: \n");
        for (0..9) |sqr| {
            try writer.print("{}: ", .{sqr});
            for (0..9) |val| {
                if (self.sqr_mask[sqr] & (@as(Tile, 1) << @truncate(val)) != 0) {
                    try writer.print("{} ", .{val});
                }
            }
            try writer.writeAll("\n");
        }

        try writer.writeAll("\ncells: \n");
        for (0..81) |index| {
            const row, const col, const sqr = i2p(index);

            try writer.print("({}, {}, {}): ", .{ row, col, sqr });

            const tile = self.row_mask[row] & self.col_mask[col] & self.sqr_mask[sqr];
            for (0..9) |val| {
                if (tile & (@as(Tile, 1) << @truncate(val)) != 0) {
                    try writer.print("{} ", .{val});
                }
            }

            try writer.writeAll("\n");
        }
    }
};

/// Construct the board mask from the list of the numerical value of each tile,
/// or zero if unknown.
pub fn board_from_tiles(tiles: [81]u8) Board {
    var board: Board = .{
        .states = [_]Tile{std.math.maxInt(Tile)} ** 81,
        .row_mask = [_]Mask{0b111111111} ** 9,
        .col_mask = [_]Mask{0b111111111} ** 9,
        .sqr_mask = [_]Mask{0b111111111} ** 9,
    };

    for (&tiles, 0..) |*tile, index| {
        if (tile.* != 0) {
            _ = set(&board, @intCast(index), @as(Tile, 1) << @truncate(tile.* - 1));
        }
    }

    return board;
}

pub fn board_from_solved(tiles: [81]u8) Board {
    var cast_tiles: [81]Tile = undefined;
    for (tiles, &cast_tiles) |tile, *cast| {
        cast.* = @as(Tile, 1) << @truncate(tile - 1);
    }

    return .{
        .states = cast_tiles,
        .row_mask = [_]Mask{0} ** 9,
        .col_mask = [_]Mask{0} ** 9,
        .sqr_mask = [_]Mask{0} ** 9,
    };
}

inline fn i2p(index: Index) struct { Index, Index, Index } {
    return RCS[index];
}

/// Sets the value of the given tile `index` to the provided mask. The mask
/// **must** have a population count of 1.
fn set(board: *Board, index: Index, mask: Tile) bool {
    const row, const col, const sqr = i2p(index);

    std.debug.assert(@popCount(mask) == 1);

    if (board.states[index] == mask) {
        return true;
    }

    std.debug.assert(board.states[index] == std.math.maxInt(Tile));

    std.debug.assert(board.row_mask[row] & mask != 0);
    std.debug.assert(board.col_mask[col] & mask != 0);
    std.debug.assert(board.sqr_mask[sqr] & mask != 0);

    board.states[index] = mask;
    board.row_mask[row] ^= mask;
    board.col_mask[col] ^= mask;
    board.sqr_mask[sqr] ^= mask;

    // Iterate through the 20 pre-calculated neighbors
    return @call(.always_tail, set_neighbors, .{ board, index });
}

/// After we modified a tile and the masks of its row, column, and square, it
/// is possible that any of its neighbors are narrowed down to 1 possibility.
/// To calculate this, we must iterate through every cell in its row, column,
/// and square, and check if any of the intersections (i.e. the value of the
/// tile) has only only one bit remaining.
/// It is possible that every neighboring cell already had this ruled out,
/// making this change have had no effect on it. However, if it already did,
/// this would have been detected. In the main solver, we have to check this
/// because the cell might have its value stored already, but here it'd have
/// the sentinel.
/// Thus, we can do a simple check.
inline fn set_neighbors(board: *Board, index: Index) bool {
    inline for (Neighbors[index]) |neighbor| {
        // TODO: We could also check (board.other_mask1[other1] | board.other_mask2[other2]) & mask != 0
        if (board.states[neighbor] == std.math.maxInt(Tile)) {
            const row, const col, const sqr = i2p(@intCast(neighbor));

            // Find the current value of the neighbor.
            const value = board.row_mask[row] & board.col_mask[col] & board.sqr_mask[sqr];

            // If there are zero set bits after this, the board cannot be solved
            if (value == 0) return false;

            // If there is only one possible value for the cell, set it.
            if (value & (value - 1) == 0 and !set(board, @intCast(neighbor), value)) {
                return false;
            }
        }
    }

    // If nothing bad happened, it must have been a success!
    return true;
}

/// Recursively brute-force solves a board by trying each possible valid number
/// for the most narrowed-down cell.
pub fn solve(board: *Board) bool {
    // Search for the unsolved (>=2 possible values) tile with the least
    // possible values. This has a fast path for any cell with two possible
    // values left.
    var best_tile: Index = std.math.maxInt(Index);
    var least_ones: Index = std.math.maxInt(Index);

    for (0..81) |index| {
        if (board.states[index] != std.math.maxInt(Tile)) continue;
        const row, const col, const sqr = i2p(@intCast(index));

        const tile = board.row_mask[row] & board.col_mask[col] & board.sqr_mask[sqr];

        const ones_in_tile = @popCount(tile);

        // If 2 <= possible values < current best, update it.
        std.debug.assert(ones_in_tile > 1);
        if (ones_in_tile < least_ones) {
            best_tile = @intCast(index);
            least_ones = ones_in_tile;
            if (ones_in_tile == 2) break; // Fast path for the smallest possible
        }
    }

    // If there's no tile, the board is solved.
    if (best_tile == std.math.maxInt(Index)) return true;

    // Make a copy of the board to restore later.
    const old_board = board.*;

    const row, const col, const sqr = i2p(best_tile);

    var value = board.row_mask[row] & board.col_mask[col] & board.sqr_mask[sqr];

    while (value != 0) {
        // Extract the first set bit as a mask.
        // This should compile to `blsi` on x86_64, which is rather fast.
        // This is inspired by a blog post from Daniel Lemire, adapted to
        // unsigned integers via two's complement.
        // https://lemire.me/blog/2018/02/21/iterating-over-set-bits-quickly/
        const set_bit = value & (~value + 1);

        // If we can solve the board with this change, just return it.
        if (set(board, best_tile, set_bit) and solve(board)) {
            return true;
        }

        // Otherwise, revert board and unset the bit (as it can't be this one).
        board.* = old_board;
        value ^= set_bit;
    }

    // The given board was impossible.
    return false;
}
