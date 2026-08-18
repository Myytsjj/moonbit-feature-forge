///|
test "integral image clips rectangles and computes moments" {
  let image = GrayImage::new(3, 2)
  image.set(0, 0, 1)
  image.set(1, 0, 2)
  image.set(2, 0, 3)
  image.set(0, 1, 4)
  image.set(1, 1, 5)
  image.set(2, 1, 6)
  let integral = IntegralImage::build(image)
  assert_eq(integral.sum(Rect::new(-2, -2, 4, 4)), 21.0)
  assert_eq(integral.sum(Rect::new(1, 0, 3, 1)), 5.0)
  assert_true(integral.mean(Rect::new(0, 0, 3, 2)) > 3.49)
  assert_true(integral.variance(Rect::new(0, 0, 3, 2)) > 2.9)
}

///|
test "adaptive threshold and morphology handle empty and isolated pixels" {
  let empty = GrayImage::new(0, 0)
  assert_eq(adaptive_threshold(empty, 2, 0).width, 0)
  let image = GrayImage::new(5, 5)
  image.set(2, 2, 255)
  let dilated = binary_dilate(image, 1)
  assert_eq(dilated.get(1, 2), 255)
  assert_eq(binary_erode(image, 1).get(2, 2), 0)
  let opened = binary_open(image, 1)
  assert_eq(opened.get(2, 2), 0)
}

///|
test "component labeling reports bounds area and intensity" {
  let image = GrayImage::new(5, 4)
  image.set(0, 0, 255)
  image.set(1, 0, 255)
  image.set(1, 1, 100)
  image.set(4, 3, 255)
  let regions = label_components(image)
  assert_eq(regions.length(), 2)
  assert_eq(regions[0].area, 3)
  assert_eq(regions[0].bounds.x0, 0)
  assert_eq(regions[0].bounds.y0, 0)
  assert_eq(regions[0].bounds.x1, 2)
  assert_eq(regions[0].bounds.y1, 2)
  assert_true(regions[0].mean > 203.0 && regions[0].mean < 204.0)
  assert_eq(filter_regions(regions, 2, 3).length(), 1)
}

///|
test "projections and peaks are deterministic" {
  let image = GrayImage::new(4, 3)
  image.set(1, 0, 255)
  image.set(1, 1, 255)
  image.set(3, 2, 255)
  assert_eq(row_projection(image)[0], 255)
  assert_eq(column_projection(image)[1], 510)
  let peaks = projection_peaks([1, 4, 2, 5, 1], 3)
  assert_eq(peaks.length(), 2)
  assert_eq(peaks[0], 1)
  assert_eq(peaks[1], 3)
}

///|
test "global image moments are safe for empty input" {
  let empty = GrayImage::new(-1, 4)
  assert_eq(image_mean(empty), 0.0)
  assert_eq(image_variance(empty), 0.0)
  let moments = image_moments(empty)
  assert_eq(moments.0, 0.0)
  assert_eq(moments.1, 0.0)
}
