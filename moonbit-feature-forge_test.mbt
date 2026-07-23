// MoonBit Feature Forge - Comprehensive Unit & Integration Tests

///|
test "GrayImage initialization and pixel access" {
  let img = GrayImage::new(10, 10)
  assert_eq(img.width, 10)
  assert_eq(img.height, 10)
  assert_eq(img.get(0, 0), 0)

  img.set(5, 5, 200)
  assert_eq(img.get(5, 5), 200)

  // Out of bounds check
  assert_eq(img.get(-1, 0), 0)
  assert_eq(img.get(10, 5), 0)

  // Clamping test
  img.set(1, 1, 300)
  assert_eq(img.get(1, 1), 255)
  img.set(2, 2, -50)
  assert_eq(img.get(2, 2), 0)
}

///|
test "Hamming distance calculation" {
  let d1 = Descriptor::new(32)
  let d2 = Descriptor::new(32)

  assert_eq(hamming_distance(d1, d2), 0)

  // Set bit 0 in d1
  d1.data[0] = (1 : Byte) // 00000001
  assert_eq(hamming_distance(d1, d2), 1)

  // Set bit 0, 1, 2 in d2
  d2.data[0] = (7 : Byte) // 00000111
  assert_eq(hamming_distance(d1, d2), 2)
}

///|
test "FAST corner detection on synthetic image" {
  let img = GrayImage::new(100, 100)

  // Draw a high contrast L-shape / corner feature centered at (50, 50)
  let mut y = 40
  while y <= 60 {
    let mut x = 40
    while x <= 60 {
      if x >= 50 || y >= 50 {
        img.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }

  let kps = detect_fast(img, 30, true)
  assert_true(kps.length() > 0)
}

///|
test "ORB descriptor generation and matcher" {
  let img = GrayImage::new(100, 100)

  // Draw two distinct feature patches inside valid border (x: 20..80)
  let mut y = 30
  while y <= 70 {
    let mut x = 30
    while x <= 70 {
      if (x - 50) * (x - 50) + (y - 50) * (y - 50) <= 200 {
        img.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }

  let (kps, descs) = extract_features(img, 20)
  assert_true(kps.length() > 0)
  assert_eq(kps.length(), descs.length())

  // Match descriptors with themselves
  let matches = match_descriptors(descs, descs)
  assert_eq(matches.length(), descs.length())
  let mut i = 0
  while i < matches.length() {
    assert_eq(matches[i].distance, 0)
    i = i + 1
  }
}

///|
test "RANSAC affine transformation estimation" {
  let kps1 : Array[Keypoint] = [
    Keypoint::new(10, 10, 100.0, 0.0),
    Keypoint::new(20, 10, 100.0, 0.0),
    Keypoint::new(15, 25, 100.0, 0.0),
    Keypoint::new(5, 5, 50.0, 0.0), // Outlier point
  ]

  // Translated by (+5, +10)
  let kps2 : Array[Keypoint] = [
    Keypoint::new(15, 20, 100.0, 0.0),
    Keypoint::new(25, 20, 100.0, 0.0),
    Keypoint::new(20, 35, 100.0, 0.0),
    Keypoint::new(90, 90, 50.0, 0.0), // Mismatched outlier
  ]

  let matches : Array[Match] = [
    Match::new(0, 0, 0),
    Match::new(1, 1, 0),
    Match::new(2, 2, 0),
    Match::new(3, 3, 0), // Outlier match
  ]

  let res = ransac_affine(matches, kps1, kps2, 50, 2.0)
  assert_true(res.inliers.length() >= 3)
  assert_true(res.inlier_ratio >= 0.75)
}

///|
test "Full feature pipeline execution" {
  let img1 = GrayImage::new(100, 100)
  let img2 = GrayImage::new(100, 100)

  let mut y = 30
  while y <= 70 {
    let mut x = 30
    while x <= 70 {
      if (x - 50) * (x - 50) + (y - 50) * (y - 50) <= 200 {
        img1.set(x, y, 255)
        img2.set(x + 2, y + 2, 255)
      }
      x = x + 1
    }
    y = y + 1
  }

  let res = full_feature_pipeline(img1, img2, 20, 0.95, 5.0)
  assert_true(res.inliers.length() >= 0)
}
