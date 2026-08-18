///|
fn make_corner_scene() -> GrayImage {
  let img = GrayImage::new(96, 96)
  let mut y = 24
  while y <= 72 {
    let mut x = 24
    while x <= 72 {
      if x >= 48 || y >= 48 {
        img.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  img
}

///|
test "FAST configuration limits the returned keypoints" {
  let config = FastConfig::new(20, 9, true, 1, 3, 0.0)
  let keypoints = detect_fast_with_config(make_corner_scene(), config)
  assert_true(keypoints.length() <= 1)
}

///|
test "FAST configuration handles uniform images" {
  let config = FastConfig::new(20, 9, true, 0, 3, 0.0)
  let keypoints = detect_fast_with_config(GrayImage::new(32, 32), config)
  assert_eq(keypoints.length(), 0)
}

///|
test "ORB configuration controls descriptor bit count and orientation" {
  let img = make_corner_scene()
  let keypoints : Array[Keypoint] = [Keypoint::new(48, 48, 100.0, 0.0)]
  let config = OrbConfig::new(16, 64, true)
  let (valid, descriptors) = compute_orb_descriptors_with_config(
    img, keypoints, config,
  )
  assert_eq(valid.length(), 1)
  assert_eq(descriptors.length(), 1)
  assert_eq(descriptors[0].data.length(), 8)
}

///|
test "multiscale extraction is deterministic and preserves paired arrays" {
  let fast = FastConfig::new(20, 9, true, 32, 3, 0.0)
  let orb = OrbConfig::new(16, 256, true)
  let image = make_corner_scene()
  let (kps1, descs1) = extract_multiscale_features(image, fast, orb, 2)
  let (kps2, descs2) = extract_multiscale_features(image, fast, orb, 2)
  assert_eq(kps1.length(), descs1.length())
  assert_eq(kps1.length(), kps2.length())
  assert_eq(descs1.length(), descs2.length())
  if kps1.length() > 0 {
    assert_eq(kps1[0].x, kps2[0].x)
    assert_eq(kps1[0].y, kps2[0].y)
    assert_eq(descs1[0].data[0], descs2[0].data[0])
  }
}
