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

pub const Board = struct {
    states: std.bit_set.ArrayBitSet(u32, 729),
    counts: [81]u32,
};

pub fn board_from_tiles(tiles: [81]u8) Board {
    var combined = Board{
        .states = .initFull(),
        .counts = [_]u32{9} ** 81,
    };
    const board = &combined;

    for (&tiles, 0..) |*tile, index| {
        if (tile.* != 0) {
            _ = set(board, index, tile.* - 1);
        }
    }

    return board.*;
}

pub fn board_from_solved(tiles: [81]u8) Board {
    var combined = Board{
        .states = .initEmpty(),
        .counts = [_]u32{1} ** 81,
    };
    const board = &combined;

    for (&tiles, 0..) |*tile, index| {
        board.states.set(index * 9 + (tile.* - 1));
    }

    return board.*;
}

pub fn get_any(board: Board, index: usize) usize {
    inline for (0..9) |i| {
        if (board.states.isSet(index * 9 + i)) return i;
    }
    unreachable;
}

pub fn set(board: *Board, index: usize, value: usize) bool {
    inline for (0..9) |i| {
        if (i == value) {
            board.states.set(index * 9 + i);
        } else {
            board.states.unset(index * 9 + i);
        }
    }
    board.counts[index] = 1;

    return set_neighbors(board, index, value);
}

fn set_neighbors(board: *Board, index: usize, value: usize) bool {
    inline for (Neighbors[index]) |neighbor| {
        if (board.states.isSet(neighbor * 9 + value)) {
            board.states.unset(neighbor * 9 + value);
            board.counts[neighbor] -= 1;

            const count = board.counts[neighbor];
            if (count == 0 or (count == 1 and !set_neighbors(board, neighbor, get_any(board.*, neighbor)))) {
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
        const ones_in_tile = board.counts[index];

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
    var possibilities = least_ones;
    var checked_number: usize = 0;

    while (possibilities > 0) : (checked_number += 1) {
        std.debug.assert(checked_number < 9);
        if (!board.states.isSet(tile * 9 + checked_number)) continue;

        if (set(board, tile, checked_number) and solve(board)) {
            return true;
        }

        possibilities -= 1;
        board.* = old_board;
    }

    return false; // No possibilities resulted in a solve. Rip!
}
