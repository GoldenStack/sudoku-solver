# sudoku solver

Brute-force but still fairly optimized sudoku solver in several languages.

## Speed

On my computer the Rust version solves the easy puzzle in about 777ns (almost
1.3 million per second) and the hardest puzzle in about 370µs.

The Zig one takes 1120ns and 441µs respectively, but I tried out a new algorithm
on it. When ported to the initial one (the same one as Rust) it takes 861ns and
346µs (about 2,900 per second), respectively.

I found this a bit strange since Rust is faster for the simple benchmark but is
slower for the complex one. I didn't really feel like looking into it though, so
that'll be a mystery for now.

## Usage

Rust:
```sh
(cd rust && RUSTFLAGS='-C target-cpu=native' cargo run --release)
```

Zig:
```sh
(cd zig && zig build run --release=fast)
```
