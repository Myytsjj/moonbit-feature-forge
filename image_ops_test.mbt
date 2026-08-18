///|
test "crop clips to the image bounds" {
  let img = GrayImage::new(4, 3)
  img.set(0, 0, 10)
  img.set(3, 2, 90)
  let cropped = img.crop(Rect::new(-2, -1, 5, 5))
  assert_eq(cropped.width, 4)
  assert_eq(cropped.height, 3)
  assert_eq(cropped.get(0, 0), 10)
  assert_eq(cropped.get(3, 2), 90)
}

///|
test "histogram counts every clamped pixel" {
  let img = GrayImage::new(2, 2)
  img.set(0, 0, 0)
  img.set(1, 0, 255)
  img.set(0, 1, 255)
  img.set(1, 1, 12)
  let histogram = img.histogram()
  assert_eq(histogram.length(), 256)
  assert_eq(histogram[0], 1)
  assert_eq(histogram[12], 1)
  assert_eq(histogram[255], 2)
}

///|
test "sampling supports constant clamp and reflect borders" {
  let img = GrayImage::new(3, 1)
  img.set(0, 0, 10)
  img.set(1, 0, 20)
  img.set(2, 0, 30)
  assert_eq(img.sample(-1, 0, BorderMode::Constant(99)), 99)
  assert_eq(img.sample(-1, 0, BorderMode::Clamp), 10)
  assert_eq(img.sample(-1, 0, BorderMode::Reflect), 20)
}

///|
test "bilinear sampling interpolates the four neighbors" {
  let img = GrayImage::new(2, 2)
  img.set(0, 0, 0)
  img.set(1, 0, 100)
  img.set(0, 1, 100)
  img.set(1, 1, 200)
  let value = img.sample_bilinear(0.5, 0.5, BorderMode::Clamp)
  assert_true(value >= 99.0 && value <= 101.0)
}

///|
test "normalization maps the observed range to byte range" {
  let img = GrayImage::new(3, 1)
  img.set(0, 0, 10)
  img.set(1, 0, 20)
  img.set(2, 0, 30)
  let normalized = img.normalize()
  assert_eq(normalized.get(0, 0), 0)
  assert_eq(normalized.get(1, 0), 128)
  assert_eq(normalized.get(2, 0), 255)
}

///|
test "resize and translate preserve deterministic nearest pixels" {
  let img = GrayImage::new(2, 1)
  img.set(0, 0, 10)
  img.set(1, 0, 20)
  let resized = img.resize_nearest(4, 2)
  assert_eq(resized.get(0, 0), 10)
  assert_eq(resized.get(3, 1), 20)
  let translated = img.translate(1, 0, BorderMode::Constant(0))
  assert_eq(translated.get(0, 0), 0)
  assert_eq(translated.get(1, 0), 10)
}

///|
test "rotation uses the image center and preserves a right angle" {
  let img = GrayImage::new(3, 3)
  img.set(2, 1, 255)
  let rotated = img.rotate_about(
    1.5707963267948966,
    FloatPoint2::new(1.0, 1.0),
    BorderMode::Constant(0),
  )
  assert_true(rotated.get(1, 2) >= 240)
}
