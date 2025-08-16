const std = @import("std");

pub fn neighbors_for_tile(x: u8, y: u8) [20]usize {
    @setEvalBranchQuota(10000);

    var neighbors = [_]usize{0} ** 20;
    var index: usize = 0;

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

fn neighbors_for_board() [81][20]usize {
    var items = [_][20]usize{[_]usize{0} ** 20} ** 81;

    for (&items, 0..) |*item, index| {
        item.* = neighbors_for_tile(index % 9, index / 9);
    }

    return items;
}

pub const Neighbors = neighbors_for_board();

pub const Tile = u32;
pub const Board = [81]Tile;

pub fn board_from_tiles(tiles: [81]u8) Board {
    var combined = [_]Tile{0b111111111} ** 81;
    const board = &combined;

    for (&tiles, 0..) |*tile, index| {
        if (tile.* != 0) {
            _ = set(board, index, @as(Tile, 1) << @intCast(tile.* - 1));
        }
    }

    return board.*;
}

/// Sets the value of the given tile `index` to the provided mask. The mask
/// **must** have a population count of 1.
fn set(board: *Board, index: usize, mask: Tile) bool {
    std.debug.assert(@popCount(mask) == 1);
    board[index] = mask;
    return @call(.always_tail, set_neighbors, .{board, index, mask});
}

/// Recursively sets the neighbors for the provided tile `index`. This does not
/// set the value of the tile itself.
fn set_neighbors(board: *Board, index: usize, mask: Tile) bool {
    // Iterate through the 20 pre-calculated neighbors
    inline for (Neighbors[index]) |neighbor| {
        // Find the old value of the neighbor.
        const old = board[neighbor];

        // Find the new value of the neighbor by unsetting the mask bit. This
        // previously had `& 0b111111111` at the end, but if `old` never has a
        // bit more significant than the ninth, it's not possible for this to
        // set any.
        const new = old & ~mask;

        // If there are zero set bits after this, the board cannot be solved.
        if (new == 0) return false;

        // Make sure that the tile was actually changed, and then update it.
        if (new != old) {
            board[neighbor] = new;

            // If `@popCount(new) == 1` (this is a method to check for it), we
            // have now solved this tile, so propagate the neighbor setting. If
            // this neighbor setting fails, we propagate that up (the board
            // cannot be solved).
            if (new & (new - 1) == 0 and !set_neighbors(board, neighbor, new)) {
                return false;
            }
        }
    }

    // If nothing bad happened it must have been a success!
    return true;
}

/// Recursively brute-force solves a board by trying each possible valid number
/// for the most narrowed-down cell.
pub fn solve(board: *Board) bool {
    // Search for the unsolved (>=2 possible values) tile with the least
    // possible values. This has a fast path for any cell with two possible
    // values left.
    var best_tile: ?usize = null;
    var least_ones: usize = 127; // Arbitrary value

    for (0..81) |index| {
        const ones_in_tile = @popCount(board[index]);

        // If 2 <= possible values < current best, update it.
        if (ones_in_tile > 1 and ones_in_tile < least_ones) {
            best_tile = index;
            least_ones = ones_in_tile;
            if (ones_in_tile == 2) break; // Fast path for the smallest possible
        }
    }

    // If there's no tile, the board is solved.
    if (best_tile == null) return true;

    // Make a copy of the board to restore later.
    const old_board = board.*;

    const tile = best_tile.?;
    var value = board[tile];

    while (value != 0) {
        // Extract the first set bit as a mask.
        // This should compile to `blsi` on x86_64, which is rather fast.
        // This is inspired by a blog post from Daniel Lemire, adapted to
        // unsigned integers via two's complement.
        // https://lemire.me/blog/2018/02/21/iterating-over-set-bits-quickly/
        const set_bit = value & (~value + 1);

        // If we can solve the board with this change, just return it.
        if (set(board, tile, set_bit) and solve(board)) {
            return true;
        }

        // Otherwise, revert board and unset the bit (as it can't be this one).
        board.* = old_board;
        value ^= set_bit;
    }

    // The given board was impossible.
    return false;
}
