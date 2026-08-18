///|
test "least squares affine fitting and residual summaries recover translation" {
  let source : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(10.0, 0.0),
    FloatPoint2::new(0.0, 10.0),
    FloatPoint2::new(8.0, 4.0),
  ]
  let target : Array[FloatPoint2] = [
    FloatPoint2::new(3.0, 4.0),
    FloatPoint2::new(13.0, 4.0),
    FloatPoint2::new(3.0, 14.0),
    FloatPoint2::new(11.0, 8.0),
  ]
  let fitted = fit_affine_points(source, target)
  assert_true(fitted.valid)
  assert_true(fitted.mean_error < 0.001)
  let summary = summarize_residuals([0.0, 1.0, 2.0], 1.0)
  assert_eq(summary.inliers, 2)
  assert_eq(summary.median, 1.0)
}

///|
test "RANSAC diagnostics and rectangle utilities clamp degenerate inputs" {
  assert_true(ransac_required_iterations(0.99, 1.0, 4, 100) >= 1)
  assert_true(ransac_success_probability(100, 0.5, 3) > 0.0)
  assert_eq(rect_area(Rect::new(0, 0, 4, 3)), 12)
  assert_eq(
    rect_area(rect_intersection(Rect::new(0, 0, 2, 2), Rect::new(4, 4, 5, 5))),
    0,
  )
  assert_true(rect_iou(Rect::new(0, 0, 2, 2), Rect::new(1, 1, 3, 3)) > 0.1)
}
