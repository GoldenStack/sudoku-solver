mod examples;
mod sudoku;

use examples::*;
use sudoku::*;

use std::time::{Duration, SystemTime};

fn main() {
    // Verify that the code actually can solve the examples
    println!("Verified Easy: {}", verify_example(EASY, EASY_SOLUTION));
    println!(
        "Verified Medium: {}",
        verify_example(MEDIUM, MEDIUM_SOLUTION)
    );
    println!("Verified Hard: {}", verify_example(HARD, HARD_SOLUTION));

    // Test settings
    let warmup_iterations = 50_000;
    let iterations = 500_000;

    let test_case = examples::EASY;

    // Warmup rounds
    println!("Warming up...");
    for _ in 0..warmup_iterations {
        let mut board = Board::from_tiles(test_case);
        board.solve();
    }

    // Actual testing
    println!("Starting iterations...");
    let start = SystemTime::now();

    for _ in 0..iterations {
        let mut board = Board::from_tiles(test_case);
        board.solve();
    }

    let end = SystemTime::now();
    let duration = end.duration_since(start).unwrap();
    let average = duration / iterations;
    let per_second = Duration::from_secs(1).as_nanos() / average.as_nanos();

    println!(
        "Average Time for {:?} iterations: {:?} (took {:.3?}; {:?}/sec)",
        iterations, average, duration, per_second
    );
}
