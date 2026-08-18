///|
test "pyramid builds deterministic levels and coordinate mappings" {
  let img = GrayImage::new(8, 6)
  let pyramid = ImagePyramid::build(img, 3)
  assert_eq(pyramid.level_count(), 3)
  assert_eq(pyramid.level(0).width, 8)
  assert_eq(pyramid.level(0).height, 6)
  assert_eq(pyramid.level(1).width, 4)
  assert_eq(pyramid.level(1).height, 3)
  assert_eq(pyramid.level(2).width, 2)
  assert_eq(pyramid.level(2).height, 2)
  let point = FloatPoint2::new(6.0, 4.0)
  let level_point = pyramid.to_level(point, 1)
  assert_eq(level_point.x, 3.0)
  assert_eq(level_point.y, 2.0)
  let original = pyramid.to_original(level_point, 1)
  assert_eq(original.x, 6.0)
  assert_eq(original.y, 4.0)
}

///|
test "pyramid handles non-positive level counts" {
  let pyramid = ImagePyramid::build(GrayImage::new(4, 4), 0)
  assert_eq(pyramid.level_count(), 0)
  assert_eq(pyramid.level(0).width, 0)
}
