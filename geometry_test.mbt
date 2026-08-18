///|
fn close_enough(left : Double, right : Double, tolerance : Double) -> Bool {
  let difference = if left > right { left - right } else { right - left }
  difference <= tolerance
}

///|
fn square_points(
  offset_x : Double,
  offset_y : Double,
) -> (Array[FloatPoint2], Array[FloatPoint2]) {
  let source : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(10.0, 0.0),
    FloatPoint2::new(10.0, 10.0),
    FloatPoint2::new(0.0, 10.0),
  ]
  let target : Array[FloatPoint2] = [
    FloatPoint2::new(offset_x, offset_y),
    FloatPoint2::new(10.0 + offset_x, offset_y),
    FloatPoint2::new(10.0 + offset_x, 10.0 + offset_y),
    FloatPoint2::new(offset_x, 10.0 + offset_y),
  ]
  (source, target)
}

///|
test "homography estimates translation and projects points" {
  let (source, target) = square_points(5.0, 7.0)
  let model = match estimate_homography(source, target) {
    Some(value) => value
    None => fail("expected a valid homography")
  }
  let projected = match model.project(FloatPoint2::new(3.0, 4.0)) {
    Some(value) => value
    None => fail("expected a finite projection")
  }
  assert_true(close_enough(projected.x, 8.0, 0.001))
  assert_true(close_enough(projected.y, 11.0, 0.001))
}

///|
test "homography inverse round trips a point" {
  let (source, target) = square_points(5.0, 7.0)
  let model = match estimate_homography(source, target) {
    Some(value) => value
    None => fail("expected a valid homography")
  }
  let inverse = match model.inverse() {
    Some(value) => value
    None => fail("expected an invertible homography")
  }
  let target_point = match model.project(FloatPoint2::new(2.0, 6.0)) {
    Some(value) => value
    None => fail("expected a finite projection")
  }
  let round_trip = match inverse.project(target_point) {
    Some(value) => value
    None => fail("expected a finite inverse projection")
  }
  assert_true(close_enough(round_trip.x, 2.0, 0.001))
  assert_true(close_enough(round_trip.y, 6.0, 0.001))
}

///|
test "collinear points are rejected by affine and homography solvers" {
  let source : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(1.0, 0.0),
    FloatPoint2::new(2.0, 0.0),
    FloatPoint2::new(3.0, 0.0),
  ]
  let target : Array[FloatPoint2] = [
    FloatPoint2::new(1.0, 2.0),
    FloatPoint2::new(2.0, 2.0),
    FloatPoint2::new(3.0, 2.0),
    FloatPoint2::new(4.0, 2.0),
  ]
  assert_true(estimate_affine_from_points(source, target) is None)
  assert_true(estimate_homography(source, target) is None)
}

///|
test "reprojection statistics summarize a perfect model" {
  let (source, target) = square_points(5.0, 7.0)
  let model = match estimate_homography(source, target) {
    Some(value) => value
    None => fail("expected a valid homography")
  }
  let stats = reprojection_stats(model, source, target)
  assert_eq(stats.count, 4)
  assert_true(close_enough(stats.mean, 0.0, 0.001))
  assert_true(close_enough(stats.maximum, 0.0, 0.001))
}

///|
test "homography RANSAC rejects an outlier correspondence" {
  let kps1 : Array[Keypoint] = [
    Keypoint::new(0, 0, 10.0, 0.0),
    Keypoint::new(10, 0, 10.0, 0.0),
    Keypoint::new(10, 10, 10.0, 0.0),
    Keypoint::new(0, 10, 10.0, 0.0),
    Keypoint::new(30, 30, 1.0, 0.0),
  ]
  let kps2 : Array[Keypoint] = [
    Keypoint::new(5, 7, 10.0, 0.0),
    Keypoint::new(15, 7, 10.0, 0.0),
    Keypoint::new(15, 17, 10.0, 0.0),
    Keypoint::new(5, 17, 10.0, 0.0),
    Keypoint::new(100, 100, 1.0, 0.0),
  ]
  let matches : Array[Match] = [
    Match::new(0, 0, 1),
    Match::new(1, 1, 1),
    Match::new(2, 2, 1),
    Match::new(3, 3, 1),
    Match::new(4, 4, 20),
  ]
  let result = ransac_homography(matches, kps1, kps2, 80, 1.0, 42)
  assert_true(result.inliers.length() >= 4)
  assert_true(result.inlier_ratio >= 0.8)
  assert_true(result.stats.maximum <= 1.0)
}
