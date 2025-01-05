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

pub fn board_from_tiles(tiles: [81]u8) u729 {
    var raw_board: u729 = std.math.maxInt(u729);
    const board: *u729 = &raw_board;

    for (&tiles, 0..) |*tile, index| {
        if (tile.* != 0) {
            _ = set(board, @intCast(index), tile.*);
        }
    }

    return board.*;
}

pub fn get(board: u729, index: u8) u9 {
    return @truncate(board >> (@as(u10, index) * 9));
}

pub fn set(board: *u729, index: u8, value: u8) bool {
    const mask = @as(u9, 1) << @intCast(value - 1);

    return set_mask(board, index, mask);
}

pub fn set_mask(board: *u729, index: u8, mask: u9) bool {
    board.* &= ~(@as(u729, ~mask) << (@as(u10, index) * 9));

    return set_neighbors_mask(board, index, mask);
}

fn set_neighbors_mask(board: *u729, index: usize, mask: u9) bool {
    for (Neighbors[index]) |neighbor| {
        // std.debug.print("TILE: {any}, NEIGHBOR: {any}\n", .{index, neighbor});

        const old = get(board.*, @intCast(neighbor));
        const new = old & ~mask & 0b111111111;

        if (new == 0) { // No possibilities for new, so board was wrong
            return false;
        }

        board.* &= ~(@as(u729, ~new) << @intCast(neighbor * 9));

        // todo can probably optimize this; like if popCount(new)==1 and old & mask (or whatever i need to write to indicate if it was a change?? a and not b or smt)
        if (@popCount(new) == 1 and @popCount(old) == 2) {
            if (!set_neighbors_mask(board, neighbor, new)) {
                return false;
            }
        }
    }

    return true;
}

pub fn solve(board: *u729) bool {
    var best_tile: ?usize = null;
    var least_ones: usize = 127; // Arbitrary value

    for (0..81) |index| {
        const tile = get(board.*, @intCast(index));
        const ones_in_tile = @popCount(tile);

        if (ones_in_tile > 1 and ones_in_tile < least_ones) {
            best_tile = index;
            least_ones = ones_in_tile;
        }
    }

    if (best_tile == null) {
        return true;
    }

    const old_board = board.*;

    const tile = best_tile.?;
    var tile_value = get(board.*, @intCast(tile));
    var checked_number: usize = 0;

    while (tile_value != 0) : ({
        tile_value >>= 1;
        checked_number += 1;
    }) {
        if (tile_value & 1 == 0) continue;

        if (set_mask(board, @intCast(tile), @as(u9, 1) << @intCast(checked_number))) {
            if (solve(board)) {
                return true;
            }
        }

        board.* = old_board;
    }

    return false; // No possibilities resulted in a solve. Rip!
}
