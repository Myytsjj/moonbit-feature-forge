// RANSAC Outlier Rejection & 2D Affine Transformation Estimation Engine

///|
pub(all) struct AffineTransform {
  a : Double
  b : Double
  tx : Double
  c : Double
  d : Double
  ty : Double
}

///|
pub fn AffineTransform::identity() -> AffineTransform {
  { a: 1.0, b: 0.0, tx: 0.0, c: 0.0, d: 1.0, ty: 0.0 }
}

///|
pub fn AffineTransform::apply(
  self : AffineTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let nx = self.a * x + self.b * y + self.tx
  let ny = self.c * x + self.d * y + self.ty
  (nx, ny)
}

///|
pub(all) struct RansacResult {
  transform : AffineTransform
  inliers : Array[Match]
  inlier_ratio : Double
}

///|
priv struct Lcg {
  mut seed : Int
}

///|
fn Lcg::next(self : Lcg, max_val : Int) -> Int {
  if max_val <= 0 {
    return 0
  }
  self.seed = (self.seed * 1103515245 + 12345) & 0x7FFFFFFF
  self.seed % max_val
}

///|
fn estimate_affine(
  p1 : (Double, Double),
  p2 : (Double, Double),
  p3 : (Double, Double),
  q1 : (Double, Double),
  q2 : (Double, Double),
  q3 : (Double, Double),
) -> AffineTransform? {
  let (x1, y1) = p1
  let (x2, y2) = p2
  let (x3, y3) = p3
  let (u1, v1) = q1
  let (u2, v2) = q2
  let (u3, v3) = q3

  let det = x1 * (y2 - y3) - y1 * (x2 - x3) + (x2 * y3 - x3 * y2)
  if det < 0.0001 && det > -0.0001 {
    return None
  }

  let det_inv = 1.0 / det

  let a = ((u1 - u2) * (y2 - y3) - (y1 - y2) * (u2 - u3)) * det_inv
  let b = ((x1 - x2) * (u2 - u3) - (u1 - u2) * (x2 - x3)) * det_inv
  let tx = u1 - a * x1 - b * y1

  let c = ((v1 - v2) * (y2 - y3) - (y1 - y2) * (v2 - v3)) * det_inv
  let d = ((x1 - x2) * (v2 - v3) - (v1 - v2) * (x2 - x3)) * det_inv
  let ty = v1 - c * x1 - d * y1

  Some({ a, b, tx, c, d, ty })
}

///|
pub fn ransac_affine(
  matches : Array[Match],
  kps1 : Array[Keypoint],
  kps2 : Array[Keypoint],
  max_iters : Int,
  threshold : Double,
) -> RansacResult {
  let valid_matches : Array[Match] = []
  let mut valid_index = 0
  while valid_index < matches.length() {
    let candidate = matches[valid_index]
    if match_has_valid_points(candidate, kps1, kps2) {
      valid_matches.push(candidate)
    }
    valid_index = valid_index + 1
  }
  if valid_matches.length() < 3 {
    return {
      transform: AffineTransform::identity(),
      inliers: valid_matches,
      inlier_ratio: 0.0,
    }
  }

  let mut best_inliers : Array[Match] = []
  let mut best_transform = AffineTransform::identity()
  let rng = { seed: 42 }

  let thresh_sq = threshold * threshold

  let mut iter = 0
  while iter < max_iters {
    let idx1 = rng.next(valid_matches.length())
    let mut idx2 = rng.next(valid_matches.length())
    while idx2 == idx1 {
      idx2 = rng.next(valid_matches.length())
    }
    let mut idx3 = rng.next(valid_matches.length())
    while idx3 == idx1 || idx3 == idx2 {
      idx3 = rng.next(valid_matches.length())
    }

    let m1 = valid_matches[idx1]
    let m2 = valid_matches[idx2]
    let m3 = valid_matches[idx3]

    let kp1_1 = kps1[m1.query_idx]
    let kp1_2 = kps1[m2.query_idx]
    let kp1_3 = kps1[m3.query_idx]

    let kp2_1 = kps2[m1.train_idx]
    let kp2_2 = kps2[m2.train_idx]
    let kp2_3 = kps2[m3.train_idx]

    let p1 = (Double::from_int(kp1_1.x), Double::from_int(kp1_1.y))
    let p2 = (Double::from_int(kp1_2.x), Double::from_int(kp1_2.y))
    let p3 = (Double::from_int(kp1_3.x), Double::from_int(kp1_3.y))

    let q1 = (Double::from_int(kp2_1.x), Double::from_int(kp2_1.y))
    let q2 = (Double::from_int(kp2_2.x), Double::from_int(kp2_2.y))
    let q3 = (Double::from_int(kp2_3.x), Double::from_int(kp2_3.y))

    match estimate_affine(p1, p2, p3, q1, q2, q3) {
      Some(tf) => {
        let current_inliers : Array[Match] = []
        let mut i = 0
        while i < valid_matches.length() {
          let m = valid_matches[i]
          let src_kp = kps1[m.query_idx]
          let dst_kp = kps2[m.train_idx]

          let (proj_x, proj_y) = tf.apply(
            Double::from_int(src_kp.x),
            Double::from_int(src_kp.y),
          )
          let dx = proj_x - Double::from_int(dst_kp.x)
          let dy = proj_y - Double::from_int(dst_kp.y)
          let err_sq = dx * dx + dy * dy

          if err_sq <= thresh_sq {
            current_inliers.push(m)
          }
          i = i + 1
        }

        if current_inliers.length() > best_inliers.length() {
          best_inliers = current_inliers
          best_transform = tf
        }
      }
      None => ()
    }
    iter = iter + 1
  }

  let ratio = Double::from_int(best_inliers.length()) /
    Double::from_int(valid_matches.length())
  { transform: best_transform, inliers: best_inliers, inlier_ratio: ratio }
}

///|
pub(all) struct HomographyRansacResult {
  model : Homography
  inliers : Array[Match]
  inlier_ratio : Double
  stats : ReprojectionStats
  iterations : Int
  seed : Int
}

///|
fn match_has_valid_points(
  item : Match,
  kps1 : Array[Keypoint],
  kps2 : Array[Keypoint],
) -> Bool {
  item.query_idx >= 0 &&
  item.query_idx < kps1.length() &&
  item.train_idx >= 0 &&
  item.train_idx < kps2.length()
}

///|
fn keypoint_as_float(point : Keypoint) -> FloatPoint2 {
  FloatPoint2::new(Double::from_int(point.x), Double::from_int(point.y))
}

///|
pub fn ransac_homography(
  matches : Array[Match],
  kps1 : Array[Keypoint],
  kps2 : Array[Keypoint],
  max_iters : Int,
  threshold : Double,
  seed : Int,
) -> HomographyRansacResult {
  let empty_stats : ReprojectionStats = {
    count: 0,
    mean: 0.0,
    rms: 0.0,
    maximum: 0.0,
  }
  if matches.length() < 4 || max_iters <= 0 || threshold <= 0.0 {
    return {
      model: Homography::identity(),
      inliers: [],
      inlier_ratio: 0.0,
      stats: empty_stats,
      iterations: 0,
      seed,
    }
  }
  let rng : Lcg = { seed, }
  let mut best_model = Homography::identity()
  let mut best_inliers : Array[Match] = []
  let threshold_squared = threshold * threshold
  let mut iteration = 0
  while iteration < max_iters {
    let first = rng.next(matches.length())
    let mut second = rng.next(matches.length())
    while second == first {
      second = rng.next(matches.length())
    }
    let mut third = rng.next(matches.length())
    while third == first || third == second {
      third = rng.next(matches.length())
    }
    let mut fourth = rng.next(matches.length())
    while fourth == first || fourth == second || fourth == third {
      fourth = rng.next(matches.length())
    }
    let sample_indices = [first, second, third, fourth]
    let source : Array[FloatPoint2] = []
    let target : Array[FloatPoint2] = []
    let mut sample_valid = true
    let mut sample_index = 0
    while sample_index < sample_indices.length() {
      let sampled = matches[sample_indices[sample_index]]
      if match_has_valid_points(sampled, kps1, kps2) {
        source.push(keypoint_as_float(kps1[sampled.query_idx]))
        target.push(keypoint_as_float(kps2[sampled.train_idx]))
      } else {
        sample_valid = false
      }
      sample_index = sample_index + 1
    }
    if sample_valid {
      match estimate_homography(source, target) {
        None => ()
        Some(model) => {
          let current_inliers : Array[Match] = []
          let mut match_index = 0
          while match_index < matches.length() {
            let candidate_match = matches[match_index]
            if match_has_valid_points(candidate_match, kps1, kps2) {
              let error = reprojection_error(
                model,
                keypoint_as_float(kps1[candidate_match.query_idx]),
                keypoint_as_float(kps2[candidate_match.train_idx]),
              )
              if error <= threshold_squared {
                current_inliers.push(candidate_match)
              }
            }
            match_index = match_index + 1
          }
          if current_inliers.length() > best_inliers.length() {
            best_model = model
            best_inliers = current_inliers
          }
        }
      }
    }
    iteration = iteration + 1
  }

  let inlier_source : Array[FloatPoint2] = []
  let inlier_target : Array[FloatPoint2] = []
  let mut i = 0
  while i < best_inliers.length() {
    let inlier_match = best_inliers[i]
    inlier_source.push(keypoint_as_float(kps1[inlier_match.query_idx]))
    inlier_target.push(keypoint_as_float(kps2[inlier_match.train_idx]))
    i = i + 1
  }
  let stats = reprojection_stats(best_model, inlier_source, inlier_target)
  let ratio = Double::from_int(best_inliers.length()) /
    Double::from_int(matches.length())
  {
    model: best_model,
    inliers: best_inliers,
    inlier_ratio: ratio,
    stats,
    iterations: max_iters,
    seed,
  }
}
