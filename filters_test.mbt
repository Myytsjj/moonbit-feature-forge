///|
test "box blur smooths an impulse without changing dimensions" {
  let img = GrayImage::new(5, 5)
  img.set(2, 2, 255)
  let blurred = box_blur(img, 1)
  assert_eq(blurred.width, 5)
  assert_eq(blurred.height, 5)
  assert_true(blurred.get(2, 2) > 20)
  assert_true(blurred.get(2, 2) < 40)
  assert_eq(blurred.get(0, 0), 0)
}

///|
test "constant images have zero sobel gradients" {
  let img = GrayImage::new(4, 4)
  img.fill(80)
  let gradients = sobel_gradients(img)
  assert_eq(gradients.gx[5], 0.0)
  assert_eq(gradients.gy[5], 0.0)
  let magnitude = gradient_magnitude(gradients)
  assert_eq(magnitude.get(1, 1), 0)
}

///|
test "sobel gradients identify a horizontal step" {
  let img = GrayImage::new(5, 5)
  let mut y = 0
  while y < 5 {
    img.set(3, y, 255)
    img.set(4, y, 255)
    y = y + 1
  }
  let gradients = sobel_gradients(img)
  assert_true(gradients.gx[2 * 5 + 2] > 0.0)
  assert_true(gradients.gy[2 * 5 + 2] == 0.0)
}

///|
test "gaussian blur performs a second smoothing pass" {
  let img = GrayImage::new(5, 5)
  img.set(2, 2, 255)
  let blurred = gaussian_blur(img, 1)
  assert_true(blurred.get(2, 2) > 0)
  assert_true(blurred.get(2, 2) < 30)
}

///|
test "gradient orientation points along the positive x axis" {
  let img = GrayImage::new(4, 2)
  img.set(2, 0, 255)
  img.set(3, 0, 255)
  img.set(2, 1, 255)
  img.set(3, 1, 255)
  let field = sobel_gradients(img)
  let angles = gradient_orientation(field)
  assert_true(angles[1] > -0.2 && angles[1] < 0.2)
}

///|
test "local contrast reports a step response" {
  let img = GrayImage::new(3, 1)
  img.set(0, 0, 10)
  img.set(1, 0, 10)
  img.set(2, 0, 90)
  let contrast = local_contrast(img, 1)
  assert_true(contrast.get(1, 0) > 0)
}
