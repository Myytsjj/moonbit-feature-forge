///|
test "pipeline handles empty images without fabricated matches" {
  let result = run_pipeline(
    GrayImage::new(32, 32),
    GrayImage::new(32, 32),
    FeatureConfig::default(),
  )
  assert_eq(result.keypoints1.length(), 0)
  assert_eq(result.keypoints2.length(), 0)
  assert_eq(result.matches.length(), 0)
  assert_eq(result.match_stats.count, 0)
  assert_eq(result.affine.inliers.length(), 0)
  assert_eq(result.homography.inliers.length(), 0)
}

///|
test "pipeline is deterministic for a translated synthetic scene" {
  let image = GrayImage::new(96, 96)
  let mut y = 24
  while y <= 72 {
    let mut x = 24
    while x <= 72 {
      if x >= 48 || y >= 48 {
        image.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  let moved = image.translate(3, 2, BorderMode::Constant(0))
  let config = FeatureConfig::default()
  let first = run_pipeline(image, moved, config)
  let second = run_pipeline(image, moved, config)
  assert_eq(first.keypoints1.length(), second.keypoints1.length())
  assert_eq(first.keypoints2.length(), second.keypoints2.length())
  assert_eq(first.matches.length(), second.matches.length())
  assert_eq(first.match_stats.count, second.match_stats.count)
  assert_eq(first.affine.inliers.length(), second.affine.inliers.length())
  let summary = format_pipeline_summary(first)
  assert_true(summary.length() > 0)
  assert_eq(inlier_ratio_percent(0.25), 25.0)
  assert_eq(inlier_ratio_percent(-1.0), 0.0)
  assert_true(affine_quality(first.affine) >= 0.0)
  assert_true(homography_quality(first.homography) >= 0.0)
  let benchmark = BenchmarkResult::new(96, 96, 3, 12, 10, 8, 0.75, 17.0)
  assert_true(format_benchmark_summary(benchmark).length() > 0)
}
