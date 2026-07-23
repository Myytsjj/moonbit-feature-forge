// MoonBit Feature Forge - Demonstration & Benchmark Runner

fn main {
  println("==========================================================")
  println("   MoonBit Feature Forge: High Performance Feature Engine ")
  println("==========================================================")
  println("Initializing synthetic images (120x120 pixels)...")

  let img1 = @lib.GrayImage::new(120, 120)
  let img2 = @lib.GrayImage::new(120, 120)

  // Render high contrast geometric features (squares & circles)
  let mut y = 30
  while y <= 90 {
    let mut x = 30
    while x <= 90 {
      if (x >= 40 && x <= 60 && y >= 40 && y <= 60) ||
        (x - 75) * (x - 75) + (y - 75) * (y - 75) <= 144 {
        img1.set(x, y, 240)
        // Image 2 has translation (+4, +3)
        img2.set(x + 4, y + 3, 240)
      }
      x = x + 1
    }
    y = y + 1
  }

  println("Step 1: Extracting FAST keypoints & ORB 256-bit descriptors...")
  let (kps1, descs1) = @lib.extract_features(img1, 25)
  let (kps2, descs2) = @lib.extract_features(img2, 25)

  println(" -> Image 1 detected \{kps1.length()} keypoints & descriptors.")
  println(" -> Image 2 detected \{kps2.length()} keypoints & descriptors.")

  println("\nStep 2: Performing Hamming distance matching & ratio test...")
  let matches = @lib.match_and_filter(descs1, descs2, 0.85)
  println(" -> Found \{matches.length()} valid feature match pairs.")

  println("\nStep 3: Executing RANSAC 2D affine model fitting & inlier filtering...")
  let ransac_res = @lib.ransac_affine(matches, kps1, kps2, 100, 4.0)
  let tf = ransac_res.transform

  println(" -> RANSAC Inlier Count: \{ransac_res.inliers.length()}")
  println(" -> Inlier Ratio: \{ransac_res.inlier_ratio * 100.0}%")
  println(
    " -> Estimated Affine Matrix: [a: \{tf.a}, b: \{tf.b}, tx: \{tf.tx}]",
  )
  println(
    "                            [c: \{tf.c}, d: \{tf.d}, ty: \{tf.ty}]",
  )
  println("==========================================================")
  println("Pipeline execution finished successfully!")
}
