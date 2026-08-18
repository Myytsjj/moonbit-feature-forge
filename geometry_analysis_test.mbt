///|
test "point bounds polygon area and hull handle degenerate input" {
  let points : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(4.0, 0.0),
    FloatPoint2::new(4.0, 3.0),
    FloatPoint2::new(0.0, 3.0),
    FloatPoint2::new(2.0, 1.0),
  ]
  let bounds = point_bounds(points)
  assert_eq(bounds.x0, 0)
  assert_eq(bounds.y0, 0)
  assert_eq(bounds.x1, 4)
  assert_eq(bounds.y1, 3)
  assert_eq(
    polygon_area([
      FloatPoint2::new(0.0, 0.0),
      FloatPoint2::new(4.0, 0.0),
      FloatPoint2::new(4.0, 3.0),
      FloatPoint2::new(0.0, 3.0),
    ]),
    12.0,
  )
  assert_true(
    polygon_area([
      FloatPoint2::new(0.0, 0.0),
      FloatPoint2::new(4.0, 0.0),
      FloatPoint2::new(4.0, 3.0),
      FloatPoint2::new(0.0, 3.0),
    ]) >
    11.9,
  )
  assert_eq(convex_hull([]).length(), 0)
  assert_eq(convex_hull(points).length(), 4)
  let outer : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(4.0, 0.0),
    FloatPoint2::new(4.0, 3.0),
    FloatPoint2::new(0.0, 3.0),
  ]
  assert_true(point_in_polygon(FloatPoint2::new(2.0, 1.0), outer))
  assert_true(point_in_polygon(FloatPoint2::new(8.0, 1.0), outer) is false)
}

///|
test "homography quality and corner warp expose model health" {
  let model = Homography::identity()
  let corners = homography_corners(model, 10, 8)
  assert_eq(corners.length(), 4)
  let quality = homography_quality_report(model, corners, corners)
  assert_eq(quality.count, 4)
  assert_eq(quality.maximum_error, 0.0)
  let warped = transform_points(model, corners)
  assert_eq(warped.length(), 4)
}

///|
test "affine decomposition and line utilities are finite" {
  let transform = AffineTransform::identity()
  let decomposition = decompose_affine(transform)
  assert_eq(decomposition.scale_x, 1.0)
  assert_eq(decomposition.scale_y, 1.0)
  assert_true(
    line_intersection(
      FloatPoint2::new(0.0, 0.0),
      FloatPoint2::new(1.0, 1.0),
      FloatPoint2::new(0.0, 1.0),
      FloatPoint2::new(1.0, 0.0),
    )
    is Some(_),
  )
  assert_true(
    line_intersection(
      FloatPoint2::new(0.0, 0.0),
      FloatPoint2::new(1.0, 0.0),
      FloatPoint2::new(0.0, 1.0),
      FloatPoint2::new(1.0, 1.0),
    )
    is None,
  )
}
