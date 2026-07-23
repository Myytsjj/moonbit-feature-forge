// FAST Corner Detector (FAST-9 algorithm with Non-Maximum Suppression)

///|
let circle_offsets : Array[(Int, Int)] = [
  (0, -3),
  (1, -3),
  (2, -2),
  (3, -1),
  (3, 0),
  (3, 1),
  (2, 2),
  (1, 3),
  (0, 3),
  (-1, 3),
  (-2, 2),
  (-3, 1),
  (-3, 0),
  (-3, -1),
  (-2, -2),
  (-1, -3),
]

///|
fn is_corner_fast9(
  img : GrayImage,
  x : Int,
  y : Int,
  threshold : Int,
) -> (Bool, Double) {
  let center_val = img.get(x, y)
  let bright_thresh = center_val + threshold
  let dark_thresh = center_val - threshold

  // Quick test: Check cardinal pixels 0, 8, 4, 12
  let p0 = img.get(x + circle_offsets[0].0, y + circle_offsets[0].1)
  let p8 = img.get(x + circle_offsets[8].0, y + circle_offsets[8].1)
  let p4 = img.get(x + circle_offsets[4].0, y + circle_offsets[4].1)
  let p12 = img.get(x + circle_offsets[12].0, y + circle_offsets[12].1)

  let mut count_bright = 0
  let mut count_dark = 0

  if p0 > bright_thresh {
    count_bright = count_bright + 1
  } else if p0 < dark_thresh {
    count_dark = count_dark + 1
  }
  if p8 > bright_thresh {
    count_bright = count_bright + 1
  } else if p8 < dark_thresh {
    count_dark = count_dark + 1
  }
  if p4 > bright_thresh {
    count_bright = count_bright + 1
  } else if p4 < dark_thresh {
    count_dark = count_dark + 1
  }
  if p12 > bright_thresh {
    count_bright = count_bright + 1
  } else if p12 < dark_thresh {
    count_dark = count_dark + 1
  }

  // Corner candidate must have at least 2 cardinal points matching
  if count_bright < 2 && count_dark < 2 {
    return (false, 0.0)
  }

  // Sample all 16 ring pixels
  let ring = Array::make(16, 0)
  let mut i = 0
  while i < 16 {
    let (dx, dy) = circle_offsets[i]
    ring[i] = img.get(x + dx, y + dy)
    i = i + 1
  }

  // Check for 9 contiguous pixels brighter or darker
  let mut is_corner = false
  let mut max_diff_sum = 0

  let mut start = 0
  while start < 16 {
    let mut contiguous_bright = true
    let mut contiguous_dark = true
    let mut diff_sum = 0
    let mut k = 0
    while k < 9 {
      let idx = (start + k) % 16
      let val = ring[idx]
      if val <= bright_thresh {
        contiguous_bright = false
      }
      if val >= dark_thresh {
        contiguous_dark = false
      }
      let diff = val - center_val
      diff_sum = diff_sum + (if diff < 0 { -diff } else { diff })
      k = k + 1
    }

    if contiguous_bright || contiguous_dark {
      is_corner = true
      if diff_sum > max_diff_sum {
        max_diff_sum = diff_sum
      }
    }
    start = start + 1
  }

  (is_corner, Double::from_int(max_diff_sum))
}

///|
pub fn detect_fast(
  img : GrayImage,
  threshold : Int,
  use_nms : Bool,
) -> Array[Keypoint] {
  let keypoints : Array[Keypoint] = []
  let border = 3
  if img.width < border * 2 || img.height < border * 2 {
    return keypoints
  }

  // Candidate grid
  let score_grid = GrayImage::new(img.width, img.height)
  let candidates : Array[(Int, Int, Double)] = []

  let mut y = border
  while y < img.height - border {
    let mut x = border
    while x < img.width - border {
      let (is_corner, score) = is_corner_fast9(img, x, y, threshold)
      if is_corner {
        score_grid.set(x, y, score.to_int())
        candidates.push((x, y, score))
      }
      x = x + 1
    }
    y = y + 1
  }

  if !use_nms {
    let mut idx = 0
    while idx < candidates.length() {
      let (cx, cy, cscore) = candidates[idx]
      keypoints.push(Keypoint::new(cx, cy, cscore, 0.0))
      idx = idx + 1
    }
    return keypoints
  }

  // Apply Non-Maximum Suppression (3x3 grid)
  let mut idx = 0
  while idx < candidates.length() {
    let (cx, cy, cscore) = candidates[idx]
    let mut is_local_max = true
    let mut dy = -1
    while dy <= 1 {
      let mut dx = -1
      while dx <= 1 {
        if dx != 0 || dy != 0 {
          let neighbor_score = Double::from_int(
            score_grid.get(cx + dx, cy + dy),
          )
          if neighbor_score >= cscore {
            is_local_max = false
          }
        }
        dx = dx + 1
      }
      dy = dy + 1
    }

    if is_local_max {
      keypoints.push(Keypoint::new(cx, cy, cscore, 0.0))
    }
    idx = idx + 1
  }

  keypoints
}
