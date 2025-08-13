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

pub fn set(board: *Board, index: usize, mask: Tile) bool {
    board[index] = mask;
    return set_neighbors(board, index, mask);
}

pub fn set_neighbors(board: *Board, index: usize, mask: Tile) bool {
    inline for (Neighbors[index]) |neighbor| {
        const old = board[neighbor];
        const new = old & ~mask & 0b111111111;

        if (new == 0) return false;
        if (new != old) {
            board[neighbor] = new;

            // TODO: Potentially optimize further by having a list of neighbors for every tile that EXCLUDES every given tile. would save one iteration
            if (new & (new - 1) == 0 and ((old ^ mask) & ((old ^ mask) - 1)) == 0 and !set_neighbors(board, neighbor, new)) {
                return false;
            }
        }
    }

    return true;
}

pub fn solve(board: *Board) bool {
    var best_tile: ?usize = null;
    var least_ones: usize = 127; // Arbitrary value

    for (0..81) |index| {
        const ones_in_tile = @popCount(board[index]);

        if (ones_in_tile > 1 and ones_in_tile < least_ones) {
            best_tile = index;
            least_ones = ones_in_tile;
            if (ones_in_tile == 2) break;
        }
    }

    if (best_tile == null) {
        return true;
    }

    const old_board = board.*;

    const tile = best_tile.?;
    var value = board[tile];

    while (value != 0) {
        // Extract the first set bit as a mask.
        // This should compile to `blsi` on x86_64, which is rather fast.
        // This is inspired by a blog post from Daniel Lemire, adapted to
        // unsigned integers via twos complement.
        // https://lemire.me/blog/2018/02/21/iterating-over-set-bits-quickly/
        const set_bit = value & (~value + 1);

        if (set(board, tile, set_bit) and solve(board)) {
            return true;
        }

        // Otherwise, revert board and unset the bit (as it can't be this one).
        board.* = old_board;
        value ^= set_bit;
    }

    return false; // No possibilities resulted in a solve. Rip!
}
