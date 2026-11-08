# sudoku solver

Brute-force microoptimized sudoku solver in several languages (currently 2).

Thanks to @mat-1 for helping with some optimization (specifically for Rust).

## Speed

On my computer the Rust version solves the easy puzzle in about 777ns (almost
1.3 million per second) and the hardest puzzle in about 370µs.

The Zig one takes 1120ns and 441µs respectively, but I tried out a new algorithm
on it. When ported to the initial one (the same one as Rust) it takes 861ns and
346µs (about 2,900 per second), respectively.

I found this a bit strange since Rust is faster for the simple benchmark but is
slower for the complex one. I didn't really feel like looking into it though, so
that'll be a mystery for now.

For puzzles that don't require making any guesses, comparative benchmarks
on my machine indicate that this solver runs 6-16% faster than competing
solvers (tdoku, etc.), and up to 4 orders of magnitude faster than other
miscellaneous solvers I've been able to find.

However, despite being the fastest for zero-guess boards, it does not make the
assumption that any board requires zero guesses. For boards where this is known
to be the case, much of the code can be removed, resulting in significant
performance gains.

### Optimizations

There exist several potential, but unimplemented, optimizations. I have detailed
several below, along with reasoning for why they have not been implemented.

- Tile caching: at the moment, we iterate through the whole board to look for
the best tile. Instead, it may be useful to store tiles with a low number of
remaining options (e.g. 2). This would require two bitwise operations and a
comparison upon each set. However, it would only improve the performance once
guesses are required in order to solve. As this solver is currently only highly
competitive for easy puzzles, we choose to keep our advantage for easy solves.

- Cell flattening: current implementations have `@sizeOf(Tile) - 9 = 23` extra
padding bits. If we instead use a `std.bit_set.ArrayBitSet`, we can pack this
into a much smaller size. This speeds up backtracking, as boards are smaller and
require less stack space and less copying. However, this also makes population
counting a problem: without the padding, extra masking and, often, population
counts across CPU word borders requires a lot of extra logic. To solve this, we
cache the population count of each cell, saving a few instructions.
Unfortunately, as per `sudoku-flat-cached.zig`, this does not result in
performance increases.

## Usage

Rust:
```sh
(cd rust && RUSTFLAGS='-C target-cpu=native' cargo run --release)
```

Zig:
```sh
(cd zig && zig build run --release=fast)
```
