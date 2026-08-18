///|
test "separable kernels and rank filters preserve bounded image data" {
  let image = GrayImage::new(5, 1)
  image.set(2, 0, 255)
  let smoothed = smooth_triangle(image, 1)
  assert_true(smoothed.get(2, 0) < 255)
  let noisy = GrayImage::new(3, 1)
  noisy.set(0, 0, 0)
  noisy.set(1, 0, 255)
  noisy.set(2, 0, 0)
  assert_eq(median_filter(noisy, 1).get(1, 0), 0)
  assert_eq(rank_filter(noisy, 1, 100).get(1, 0), 255)
  assert_eq(quantize_image(noisy, 1).get(1, 0), 0)
}

///|
test "threshold and texture operations handle uniform images" {
  let image = GrayImage::new(4, 4)
  image.fill(80)
  assert_true(otsu_threshold(image) >= 0)
  assert_eq(threshold_sauvola(image, 2, 0.2, 0.0).get(1, 1), 255)
  let texture = local_binary_pattern(image, 1)
  assert_eq(texture.get(1, 1), 255)
  assert_eq(texture_histogram(texture)[255], 16)
}

///|
test "edge and arithmetic helpers respect dimensions and empty input" {
  let empty = GrayImage::new(0, 0)
  assert_eq(edge_density(empty, 10), 0.0)
  let left = GrayImage::new(2, 1)
  left.set(0, 0, 10)
  let right = GrayImage::new(2, 1)
  right.set(0, 0, 20)
  assert_eq(image_add(left, right).get(0, 0), 30)
  assert_eq(image_subtract(left, right).get(0, 0), 0)
  assert_eq(image_blend(left, right, 0.5).get(0, 0), 15)
}
