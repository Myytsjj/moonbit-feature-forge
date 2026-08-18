///|
test "affine and homography warps preserve identity" {
  let image = GrayImage::new(3, 3)
  image.set(1, 1, 200)
  let affine = warp_affine_image(
    image,
    AffineTransform::identity(),
    3,
    3,
    WarpOptions::default(),
  )
  assert_eq(affine.get(1, 1), 200)
  let homography = warp_homography_image(
    image,
    Homography::identity(),
    3,
    3,
    WarpOptions::default(),
  )
  assert_eq(homography.get(1, 1), 200)
  assert_eq(warp_valid_mask(Homography::identity(), 3, 3, 3, 3).get(1, 1), 255)
}

///|
test "translation search and normalized correlation are deterministic" {
  let reference = GrayImage::new(12, 12)
  reference.set(5, 5, 255)
  let moving = reference.translate(2, 1, BorderMode::Constant(0))
  let search = search_translation(reference, moving, 3, 3)
  assert_eq(search.dx, -2)
  assert_eq(search.dy, -1)
  assert_true(search.evaluated > 1)
  assert_true(normalized_correlation(reference, reference) > 0.99)
}

///|
test "patch search and invalid warp inputs return stable results" {
  let image = GrayImage::new(8, 8)
  image.set(4, 4, 255)
  let patch = image.crop(Rect::new(3, 3, 6, 6))
  let found = search_patch(image, patch, 2, 2, 3)
  assert_eq(found.x, 3)
  assert_eq(found.y, 3)
  let empty = search_patch(image, GrayImage::new(0, 0), 1, 1, 2)
  assert_eq(empty.evaluated, 0)
}
