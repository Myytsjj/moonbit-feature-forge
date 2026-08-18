// Human-readable pipeline and quality summaries.

///|
pub(all) struct BenchmarkResult {
  width : Int
  height : Int
  iterations : Int
  features1 : Int
  features2 : Int
  matches : Int
  inlier_ratio : Double
  total_ms : Double
}

///|
pub fn BenchmarkResult::new(
  width : Int,
  height : Int,
  iterations : Int,
  features1 : Int,
  features2 : Int,
  matches : Int,
  inlier_ratio : Double,
  total_ms : Double,
) -> BenchmarkResult {
  {
    width,
    height,
    iterations,
    features1,
    features2,
    matches,
    inlier_ratio,
    total_ms,
  }
}

///|
pub fn format_pipeline_summary(result : PipelineResult) -> String {
  let affine = result.affine
  let homography = result.homography
  let match_stats = result.match_stats
  "features1=\{result.keypoints1.length()} features2=\{result.keypoints2.length()} matches=\{result.matches.length()} distance_mean=\{match_stats.mean} affine_inliers=\{affine.inliers.length()} homography_inliers=\{homography.inliers.length()}"
}

///|
pub fn format_benchmark_summary(result : BenchmarkResult) -> String {
  "benchmark=feature_pipeline size=\{result.width}x\{result.height} iterations=\{result.iterations} features1=\{result.features1} features2=\{result.features2} matches=\{result.matches} inlier_ratio=\{result.inlier_ratio} total_ms=\{result.total_ms}"
}

///|
pub fn inlier_ratio_percent(ratio : Double) -> Double {
  if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    100.0
  } else {
    ratio * 100.0
  }
}

///|
pub fn affine_quality(result : RansacResult) -> Double {
  let ratio = result.inlier_ratio
  if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
}

///|
pub fn homography_quality(result : HomographyRansacResult) -> Double {
  let ratio_score = if result.inlier_ratio < 0.0 {
    0.0
  } else if result.inlier_ratio > 1.0 {
    1.0
  } else {
    result.inlier_ratio
  }
  let error_score = if result.stats.maximum <= 0.0 {
    1.0
  } else {
    1.0 / (1.0 + result.stats.maximum)
  }
  ratio_score * error_score
}
