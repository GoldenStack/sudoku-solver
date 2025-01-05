use std::fmt::{self, Debug};

pub type TileType = u32;

pub const ALL_POSSIBLE: TileType = 0b111111111;

pub const SIZE: usize = 9;
pub const BOARD_SIZE: usize = SIZE * SIZE;

pub const TILE_NEIGHBORS: usize = 20; // 8 in section + 6 in each direction

pub type Neighbors = [usize; TILE_NEIGHBORS];
pub type CachedNeighbors = [Neighbors; BOARD_SIZE];

pub const NEIGHBOR_MAP: CachedNeighbors = {
    const fn get_neighbors(x: usize, y: usize) -> Neighbors {
        let mut neighbors = [0; TILE_NEIGHBORS];
        let mut counter: usize = 0;

        let low_x = (x / 3) * 3;
        let low_y = (y / 3) * 3;

        let mut ax = 0;
        while ax < 3 {
            let mut ay = 0;
            while ay < 3 {
                let ry = low_y + ay;
                let rx = low_x + ax;
                if rx != x || ry != y {
                    neighbors[counter] = ry * SIZE + rx;
                    counter += 1;
                }
                ay += 1;
            }
            ax += 1;
        }

        let mut index = 0;
        while index < 9 {
            // Should be separated into x and y for fewer magic numbers
            if (x / 3) != (index / 3) {
                neighbors[counter] = index + y * SIZE;
                counter += 1;
            }
            if (y / 3) != (index / 3) {
                neighbors[counter] = x + index * SIZE;
                counter += 1;
            }

            index += 1;
        }

        neighbors
    }

    let mut items = [[0; TILE_NEIGHBORS]; BOARD_SIZE];

    let mut index: usize = 0;
    while index < BOARD_SIZE {
        items[index] = get_neighbors(index % SIZE, index / SIZE);
        index += 1;
    }

    items
};

#[derive(Clone)]
pub struct Board {
    tiles: [TileType; BOARD_SIZE],
}

impl Board {
    pub fn from_tiles(tiles: [u8; BOARD_SIZE]) -> Self {
        let mut board = Board::new();

        for (index, tile) in tiles.iter().enumerate() {
            if *tile != 0 {
                board.set(index, *tile);
            }
        }

        board
    }

    pub fn new() -> Self {
        Board {
            tiles: [ALL_POSSIBLE; BOARD_SIZE],
        }
    }

    pub fn tiles(&self) -> &[TileType; BOARD_SIZE] {
        &self.tiles
    }

    pub fn set(&mut self, index: usize, tile: u8) -> bool {
        let mask = 0b1 << (tile - 1);
        self.set_mask(index, mask)
    }

    #[inline(always)]
    pub fn set_mask(&mut self, index: usize, mask: TileType) -> bool {
        self.tiles[index] = mask;
        self.set_neighbors_mask(index, mask)
    }

    #[inline(never)]
    fn set_neighbors_mask(&mut self, index: usize, mask: TileType) -> bool {
        let neighbors = &NEIGHBOR_MAP[index];

        macro_rules! set_neighbors_mask_loop {
            ($($index:expr),*) => {
                $(
                    if self.set_neighbor_mask(neighbors[$index], mask) {
                        return false;
                    }
                )*
            };
        }

        set_neighbors_mask_loop!(
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
        );

        true
    }

    #[inline(always)]
    fn set_neighbor_mask(&mut self, neighbor: usize, mask: TileType) -> bool {
        let old = *unsafe { self.tiles.get_unchecked(neighbor) };
        let new = old & (!mask & ALL_POSSIBLE);

        if new == 0 {
            return true;
        }

        *unsafe { self.tiles.get_unchecked_mut(neighbor) } = new;

        let has_1_one = new & (new - 1) == 0;
        has_1_one
            && ((old ^ mask) & ((old ^ mask) - 1)) == 0
            && !self.set_neighbors_mask(neighbor, new)
    }

    pub fn solve(&mut self) -> bool {
        let mut optimal = None;
        let mut optimal_ones = 999; // Arbitrary value
        for (index, tile) in self.tiles.iter().enumerate() {
            let ones = tile.count_ones();
            if ones > 1 && ones < optimal_ones {
                optimal = Some(index);
                optimal_ones = ones;
            }
        }

        let optimal = match optimal {
            Some(v) => v,
            None => return true,
        };

        let old_tiles = self.tiles;

        let mut tile_val = self.tiles[optimal];

        let mut num = 0;
        while tile_val != 0 {
            if tile_val & 1 == 1 {
                if self.set_mask(optimal, 0b1 << num) && self.solve() {
                    return true;
                }
                self.tiles = old_tiles;
            }
            tile_val >>= 1;
            num += 1;
        }
        false
    }
}

impl Debug for Board {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let align = self
            .tiles
            .map(TileType::count_ones)
            .iter()
            .max()
            .map(|v| *v as usize)
            .unwrap();

        for y in 0..9 {
            if y % 3 == 0 {
                writeln!(f, "{}", "---".repeat(10))?;
            }

            for x in 0..9 {
                if x % 3 == 0 {
                    write!(f, "| ")?;
                }

                let mut tile = self.tiles[x + y * SIZE];
                let mut display: String = String::new();
                let mut count = 1;
                while tile != 0 {
                    if tile & 1 != 0 {
                        display += &count.to_string();
                    }
                    tile >>= 1;
                    count += 1;
                }
                write!(f, "{: >align$} ", display)?;
            }
            writeln!(f)?;
        }
        Ok(())
    }
}
