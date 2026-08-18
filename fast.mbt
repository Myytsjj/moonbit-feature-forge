// FAST Corner Detector (FAST-9 algorithm with Non-Maximum Suppression)

///|
pub(all) struct FastConfig {
  threshold : Int
  contiguous : Int
  use_nms : Bool
  max_keypoints : Int
  border : Int
  min_response : Double
}

///|
pub fn FastConfig::new(
  threshold : Int,
  contiguous : Int,
  use_nms : Bool,
  max_keypoints : Int,
  border : Int,
  min_response : Double,
) -> FastConfig {
  { threshold, contiguous, use_nms, max_keypoints, border, min_response }
}

///|
pub fn FastConfig::default() -> FastConfig {
  FastConfig::new(20, 9, true, 0, 3, 0.0)
}

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
fn is_corner_fast(
  img : GrayImage,
  x : Int,
  y : Int,
  threshold : Int,
  contiguous : Int,
) -> (Bool, Double) {
  let center_val = img.get(x, y)
  let bright_thresh = center_val + threshold
  let dark_thresh = center_val - threshold

  let required = if contiguous < 1 {
    1
  } else if contiguous > 16 {
    16
  } else {
    contiguous
  }

  // Quick test: Check cardinal pixels 0, 8, 4, 12 for FAST-9 and above.
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
  if required >= 9 && count_bright < 2 && count_dark < 2 {
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

  // Check for the requested number of contiguous pixels brighter or darker.
  let mut is_corner = false
  let mut max_diff_sum = 0

  let mut start = 0
  while start < 16 {
    let mut contiguous_bright = true
    let mut contiguous_dark = true
    let mut diff_sum = 0
    let mut k = 0
    while k < required {
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
  detect_fast_with_config(
    img,
    FastConfig::new(threshold, 9, use_nms, 0, 3, 0.0),
  )
}

///|
fn keypoint_before(left : Keypoint, right : Keypoint) -> Bool {
  if left.response > right.response {
    true
  } else if left.response < right.response {
    false
  } else if left.y < right.y {
    true
  } else if left.y > right.y {
    false
  } else {
    left.x < right.x
  }
}

///|
fn sort_keypoints(keypoints : Array[Keypoint]) -> Unit {
  let mut i = 1
  while i < keypoints.length() {
    let current = keypoints[i]
    let mut j = i
    while j > 0 && keypoint_before(current, keypoints[j - 1]) {
      keypoints[j] = keypoints[j - 1]
      j = j - 1
    }
    keypoints[j] = current
    i = i + 1
  }
}

///|
pub fn detect_fast_with_config(
  img : GrayImage,
  config : FastConfig,
) -> Array[Keypoint] {
  let keypoints : Array[Keypoint] = []
  let border = if config.border < 3 { 3 } else { config.border }
  if img.width <= border * 2 || img.height <= border * 2 {
    return keypoints
  }

  let score_grid = Array::make(img.width * img.height, 0.0)
  let candidates : Array[(Int, Int, Double)] = []
  let mut y = border
  while y < img.height - border {
    let mut x = border
    while x < img.width - border {
      let (is_corner, score) = is_corner_fast(
        img,
        x,
        y,
        config.threshold,
        config.contiguous,
      )
      if is_corner && score >= config.min_response {
        score_grid[y * img.width + x] = score
        candidates.push((x, y, score))
      }
      x = x + 1
    }
    y = y + 1
  }

  let mut idx = 0
  while idx < candidates.length() {
    let (cx, cy, cscore) = candidates[idx]
    let mut is_local_max = true
    if config.use_nms {
      let mut dy = -1
      while dy <= 1 {
        let mut dx = -1
        while dx <= 1 {
          let nx = cx + dx
          let ny = cy + dy
          let neighbor_score = if nx >= 0 &&
            nx < img.width &&
            ny >= 0 &&
            ny < img.height {
            score_grid[ny * img.width + nx]
          } else {
            0.0
          }
          let earlier_tie = ny < cy || (ny == cy && nx < cx)
          if (dx != 0 || dy != 0) &&
            (
              neighbor_score > cscore ||
              (neighbor_score == cscore && earlier_tie)
            ) {
            is_local_max = false
          }
          dx = dx + 1
        }
        dy = dy + 1
      }
    }
    if is_local_max {
      keypoints.push(Keypoint::new(cx, cy, cscore, 0.0))
    }
    idx = idx + 1
  }

  sort_keypoints(keypoints)
  if config.max_keypoints > 0 && keypoints.length() > config.max_keypoints {
    while keypoints.length() > config.max_keypoints {
      ignore(keypoints.pop())
    }
  }
  keypoints
}
