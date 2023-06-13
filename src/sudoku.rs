
pub type TileType = u16;

pub const ALL_POSSIBLE: TileType = 0b111111111;

pub const SIZE: usize = 9;

pub const TILE_NEIGHBORS: usize = 20; // 8 in section + 6 in each direction
pub const BOARD_SIZE: usize = SIZE * SIZE;

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
        while index < 9 { // Should be separated into x and y for fewer magic numbers
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

#[derive(Clone, Copy)]
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
    pub fn set_mask(&mut self, index: usize, mask: u16) -> bool {
        self.tiles[index] = mask;
        self.set_neighbors_mask(index, mask)
    }

    #[inline(always)]
    pub fn set_neighbors_mask(&mut self, index: usize, mask: u16) -> bool {
        for neighbor in NEIGHBOR_MAP[index] {

            let old = self.tiles[neighbor];
            let new = old & !mask & ALL_POSSIBLE;

            if new.count_ones() == 0 {
                return false;
            }
            
            self.tiles[neighbor] = new;

            if new.count_ones() == 1 && old.count_ones() == 2 {
                if !self.set_neighbors_mask(neighbor, new) {
                    return false;
                }
            }

        };

        true
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

        let old_tiles = self.tiles.clone();

        let mut tile_val = self.tiles[optimal];

        let mut num = 0;
        while tile_val != 0 {
            if tile_val & 1 == 1 {
                if self.set_mask(optimal, 0b1 << num) {
                    if self.solve() {
                        return true;
                    }
                }
                self.tiles = old_tiles;
            }
            tile_val >>= 1;
            num += 1;
        }
        false
    }
}


impl std::fmt::Debug for Board {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {

        let align = self.tiles
                .map(u16::count_ones)
                .iter().max()
                .map(|v| *v as usize)
                .unwrap();

        for y in 0..9 {
            if y % 3 == 0 {
                write!(f, "{}\n", "---".repeat(10))?;
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
                        display += &&count.to_string();
                    }
                    tile >>= 1;
                    count += 1;
                }
                write!(f, "{: >align$} ", display)?;
            }
            write!(f, "\n")?;
        }
        Ok(())
    }
}