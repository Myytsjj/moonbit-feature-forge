// MoonBit Feature Forge command-line demonstration and benchmark runner.

///|
fn make_scene(size : Int) -> (@lib.GrayImage, @lib.GrayImage) {
  let first = @lib.GrayImage::new(size, size)
  let second = @lib.GrayImage::new(size, size)
  let mut y = 18
  while y < size - 18 {
    let mut x = 18
    while x < size - 18 {
      let square = x >= 32 && x < 58 && y >= 32 && y < 58
      let ring = (x - size / 2) * (x - size / 2) +
        (y - size / 2) * (y - size / 2) <=
        20 * 20
      let diagonal = (x - y >= -2 && x - y <= 2) ||
        (x + y >= size - 3 && x + y <= size + 1)
      if square || ring || diagonal {
        first.set(x, y, 240)
        let tx = x + 4
        let ty = y + 3
        if tx < size && ty < size {
          second.set(tx, ty, 240)
        }
      }
      x = x + 1
    }
    y = y + 1
  }
  (first, second)
}

///|
fn run_demo() -> Unit {
  let (first, second) = make_scene(120)
  let result = @lib.run_pipeline(first, second, @lib.FeatureConfig::default())
  println("MoonBit Feature Forge")
  println("pipeline=demo size=120x120")
  println(
    "features1=\{result.keypoints1.length()} features2=\{result.keypoints2.length()} matches=\{result.matches.length()}",
  )
  println(
    "affine_inliers=\{result.affine.inliers.length()} homography_inliers=\{result.homography.inliers.length()}",
  )
  println(
    "affine_ratio=\{result.affine.inlier_ratio} homography_rms=\{result.homography.stats.rms}",
  )
  println(@lib.format_pipeline_summary(result))
}

///|
fn run_benchmark() -> Unit {
  let (first, second) = make_scene(160)
  let iterations = 3
  let config = @lib.FeatureConfig::default()
  let start = @env.now()
  let mut last = @lib.run_pipeline(first, second, config)
  let mut iteration = 1
  while iteration < iterations {
    last = @lib.run_pipeline(first, second, config)
    iteration = iteration + 1
  }
  let elapsed = @env.now() - start
  let report = @lib.BenchmarkResult::new(
    160,
    160,
    iterations,
    last.keypoints1.length(),
    last.keypoints2.length(),
    last.matches.length(),
    last.homography.inlier_ratio,
    elapsed.to_double(),
  )
  println(@lib.format_benchmark_summary(report))
  println("target=default seed=42")
}

///|
fn main {
  let args = @env.args()
  if args.length() > 1 && args[1] == "benchmark" {
    run_benchmark()
  } else {
    run_demo()
  }
}
