// Model fitting, polygon utilities, and robust-estimation diagnostics.

///|
pub(all) struct AffineFitResult {
  transform : AffineTransform
  residuals : Array[Double]
  mean_error : Double
  maximum_error : Double
  condition : Double
  valid : Bool
}

///|
pub(all) struct ResidualSummary {
  count : Int
  mean : Double
  median : Double
  rms : Double
  maximum : Double
  inliers : Int
  ratio : Double
}

///|
pub(all) struct ModelComparison {
  affine_score : Double
  homography_score : Double
  preferred : String
  affine_inliers : Int
  homography_inliers : Int
}

///|
fn advanced_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn advanced_sqrt(value : Double) -> Double {
  if value <= 0.000000000001 {
    return 0.0
  }
  let mut guess = if value > 1.0 { value } else { 1.0 }
  let mut i = 0
  while i < 24 {
    guess = (guess + value / guess) / 2.0
    i = i + 1
  }
  guess
}

///|
fn solve_small_system(
  matrix : Array[Array[Double]],
  size : Int,
) -> Array[Double]? {
  let augmented : Array[Array[Double]] = []
  let mut i = 0
  while i < size {
    let row = Array::make(size + 1, 0.0)
    let mut j = 0
    while j <= size {
      row[j] = matrix[i][j]
      j = j + 1
    }
    augmented.push(row)
    i = i + 1
  }
  let mut column = 0
  while column < size {
    let mut pivot = column
    let mut candidate = column + 1
    while candidate < size {
      if advanced_abs(augmented[candidate][column]) >
        advanced_abs(augmented[pivot][column]) {
        pivot = candidate
      }
      candidate = candidate + 1
    }
    if advanced_abs(augmented[pivot][column]) < 0.000000001 {
      return None
    }
    if pivot != column {
      let temp = augmented[pivot]
      augmented[pivot] = augmented[column]
      augmented[column] = temp
    }
    let divisor = augmented[column][column]
    let mut j = column
    while j <= size {
      augmented[column][j] = augmented[column][j] / divisor
      j = j + 1
    }
    let mut row_index = 0
    while row_index < size {
      if row_index != column {
        let factor = augmented[row_index][column]
        j = column
        while j <= size {
          augmented[row_index][j] = augmented[row_index][j] -
            factor * augmented[column][j]
          j = j + 1
        }
      }
      row_index = row_index + 1
    }
    column = column + 1
  }
  let result = Array::make(size, 0.0)
  i = 0
  while i < size {
    result[i] = augmented[i][size]
    i = i + 1
  }
  Some(result)
}

///|
pub fn fit_affine_points(
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> AffineFitResult {
  let count = if source.length() < target.length() {
    source.length()
  } else {
    target.length()
  }
  if count < 3 {
    return {
      transform: AffineTransform::identity(),
      residuals: [],
      mean_error: 0.0,
      maximum_error: 0.0,
      condition: 0.0,
      valid: false,
    }
  }
  let matrix_x : Array[Array[Double]] = []
  let matrix_y : Array[Array[Double]] = []
  let mut i = 0
  while i < count {
    let x = source[i].x
    let y = source[i].y
    let row_x = Array::make(7, 0.0)
    row_x[0] = x * x
    row_x[1] = x * y
    row_x[2] = x
    row_x[3] = 1.0
    row_x[4] = 0.0
    row_x[5] = 0.0
    row_x[6] = x * target[i].x
    let row_y = Array::make(7, 0.0)
    row_y[0] = x * x
    row_y[1] = x * y
    row_y[2] = x
    row_y[3] = 0.0
    row_y[4] = 0.0
    row_y[5] = 0.0
    row_y[6] = y * target[i].x
    matrix_x.push(row_x)
    matrix_y.push(row_y)
    i = i + 1
  }
  let normal : Array[Array[Double]] = []
  let mut normal_row = 0
  while normal_row < 6 {
    normal.push(Array::make(7, 0.0))
    normal_row = normal_row + 1
  }
  i = 0
  while i < count {
    let x = source[i].x
    let y = source[i].y
    let features : Array[Double] = [x, y, 1.0]
    let mut r = 0
    while r < 3 {
      let mut c = 0
      while c < 3 {
        normal[r][c] = normal[r][c] + features[r] * features[c]
        normal[r + 3][c + 3] = normal[r + 3][c + 3] + features[r] * features[c]
        c = c + 1
      }
      normal[r][6] = normal[r][6] + features[r] * target[i].x
      normal[r + 3][6] = normal[r + 3][6] + features[r] * target[i].y
      r = r + 1
    }
    i = i + 1
  }
  match solve_small_system(normal, 6) {
    None =>
      {
        transform: AffineTransform::identity(),
        residuals: [],
        mean_error: 0.0,
        maximum_error: 0.0,
        condition: 0.0,
        valid: false,
      }
    Some(solution) => {
      let transform = {
        a: solution[0],
        b: solution[1],
        tx: solution[2],
        c: solution[3],
        d: solution[4],
        ty: solution[5],
      }
      let residuals = affine_residual_profile(transform, source, target)
      let mean_error = residual_mean(residuals)
      let maximum_error = residual_maximum(residuals)
      let decomposition = decompose_affine(transform)
      let condition = if decomposition.scale_y <= 0.000000001 {
        1000000000.0
      } else if decomposition.scale_x > decomposition.scale_y {
        decomposition.scale_x / decomposition.scale_y
      } else {
        decomposition.scale_y / decomposition.scale_x
      }
      {
        transform,
        residuals,
        mean_error,
        maximum_error,
        condition,
        valid: true,
      }
    }
  }
}

///|
pub fn fit_affine_matches(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> AffineFitResult {
  let source : Array[FloatPoint2] = []
  let target : Array[FloatPoint2] = []
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if current.query_idx >= 0 &&
      current.query_idx < keypoints1.length() &&
      current.train_idx >= 0 &&
      current.train_idx < keypoints2.length() {
      source.push(
        FloatPoint2::new(
          Double::from_int(keypoints1[current.query_idx].x),
          Double::from_int(keypoints1[current.query_idx].y),
        ),
      )
      target.push(
        FloatPoint2::new(
          Double::from_int(keypoints2[current.train_idx].x),
          Double::from_int(keypoints2[current.train_idx].y),
        ),
      )
    }
    i = i + 1
  }
  fit_affine_points(source, target)
}

///|
fn advanced_sort(values : Array[Double]) -> Unit {
  let mut i = 1
  while i < values.length() {
    let value = values[i]
    let mut j = i
    while j > 0 && value < values[j - 1] {
      values[j] = values[j - 1]
      j = j - 1
    }
    values[j] = value
    i = i + 1
  }
}

///|
pub fn summarize_residuals(
  values : Array[Double],
  threshold : Double,
) -> ResidualSummary {
  if values.length() == 0 {
    return {
      count: 0,
      mean: 0.0,
      median: 0.0,
      rms: 0.0,
      maximum: 0.0,
      inliers: 0,
      ratio: 0.0,
    }
  }
  let sorted : Array[Double] = []
  let mut total = 0.0
  let mut square_total = 0.0
  let mut maximum = 0.0
  let mut inliers = 0
  let mut i = 0
  while i < values.length() {
    sorted.push(values[i])
    total = total + values[i]
    square_total = square_total + values[i] * values[i]
    if values[i] > maximum {
      maximum = values[i]
    }
    if values[i] <= threshold {
      inliers = inliers + 1
    }
    i = i + 1
  }
  advanced_sort(sorted)
  let middle = sorted.length() / 2
  let median = if sorted.length() % 2 == 1 {
    sorted[middle]
  } else {
    (sorted[middle - 1] + sorted[middle]) / 2.0
  }
  {
    count: values.length(),
    mean: total / Double::from_int(values.length()),
    median,
    rms: advanced_sqrt(square_total / Double::from_int(values.length())),
    maximum,
    inliers,
    ratio: Double::from_int(inliers) / Double::from_int(values.length()),
  }
}

///|
pub fn ransac_required_iterations(
  confidence : Double,
  inlier_ratio : Double,
  sample_size : Int,
  maximum : Int,
) -> Int {
  if maximum <= 0 || sample_size <= 0 {
    return 0
  }
  let safe_confidence = if confidence < 0.0 {
    0.0
  } else if confidence >= 1.0 {
    0.999999
  } else {
    confidence
  }
  let safe_ratio = if inlier_ratio < 0.0 {
    0.0
  } else if inlier_ratio > 1.0 {
    1.0
  } else {
    inlier_ratio
  }
  if safe_ratio >= 1.0 {
    return 1
  }
  if safe_ratio <= 0.0 {
    return maximum
  }
  let probability = 1.0 - safe_ratio
  let mut denominator_power = 1.0
  let mut i = 0
  while i < sample_size {
    denominator_power = denominator_power * probability
    i = i + 1
  }
  let mut numerator_power = 1.0
  let mut count = 0
  while count < 24 && numerator_power > 0.000001 {
    numerator_power = numerator_power * denominator_power
    count = count + 1
  }
  let confidence_factor = if safe_confidence >= 0.95 { 2 } else { 1 }
  let estimate = if numerator_power <= 0.0 {
    maximum
  } else {
    (count + 1) * confidence_factor
  }
  if estimate > maximum {
    maximum
  } else if estimate < 1 {
    1
  } else {
    estimate
  }
}

///|
pub fn ransac_success_probability(
  iterations : Int,
  inlier_ratio : Double,
  sample_size : Int,
) -> Double {
  if iterations <= 0 || sample_size <= 0 {
    return 0.0
  }
  let ratio = if inlier_ratio < 0.0 {
    0.0
  } else if inlier_ratio > 1.0 {
    1.0
  } else {
    inlier_ratio
  }
  let mut sample_probability = 1.0
  let mut i = 0
  while i < sample_size {
    sample_probability = sample_probability * ratio
    i = i + 1
  }
  let mut failure = 1.0
  i = 0
  while i < iterations {
    failure = failure * (1.0 - sample_probability)
    i = i + 1
  }
  1.0 - failure
}

///|
pub fn compare_models(
  affine : RansacResult,
  homography : HomographyRansacResult,
  affine_residual : Double,
  homography_residual : Double,
) -> ModelComparison {
  let safe_affine_residual = if affine_residual < 0.0 {
    0.0
  } else {
    affine_residual
  }
  let safe_homography_residual = if homography_residual < 0.0 {
    0.0
  } else {
    homography_residual
  }
  let affine_score = Double::from_int(affine.inliers.length()) /
    (1.0 + safe_affine_residual)
  let homography_score = Double::from_int(homography.inliers.length()) /
    (1.0 + safe_homography_residual)
  let preferred = if homography_score > affine_score {
    "homography"
  } else {
    "affine"
  }
  {
    affine_score,
    homography_score,
    preferred,
    affine_inliers: affine.inliers.length(),
    homography_inliers: homography.inliers.length(),
  }
}

///|
pub fn rect_contains(rect : Rect, point : Point2) -> Bool {
  point.x >= rect.x0 &&
  point.x < rect.x1 &&
  point.y >= rect.y0 &&
  point.y < rect.y1
}

///|
pub fn rect_area(rect : Rect) -> Int {
  let width = if rect.x1 > rect.x0 { rect.x1 - rect.x0 } else { 0 }
  let height = if rect.y1 > rect.y0 { rect.y1 - rect.y0 } else { 0 }
  width * height
}

///|
pub fn rect_intersection(left : Rect, right : Rect) -> Rect {
  let x0 = if left.x0 > right.x0 { left.x0 } else { right.x0 }
  let y0 = if left.y0 > right.y0 { left.y0 } else { right.y0 }
  let x1 = if left.x1 < right.x1 { left.x1 } else { right.x1 }
  let y1 = if left.y1 < right.y1 { left.y1 } else { right.y1 }
  if x1 < x0 || y1 < y0 {
    Rect::new(x0, y0, x0, y0)
  } else {
    Rect::new(x0, y0, x1, y1)
  }
}

///|
pub fn rect_union(left : Rect, right : Rect) -> Rect {
  let x0 = if left.x0 < right.x0 { left.x0 } else { right.x0 }
  let y0 = if left.y0 < right.y0 { left.y0 } else { right.y0 }
  let x1 = if left.x1 > right.x1 { left.x1 } else { right.x1 }
  let y1 = if left.y1 > right.y1 { left.y1 } else { right.y1 }
  Rect::new(x0, y0, x1, y1)
}

///|
pub fn rect_iou(left : Rect, right : Rect) -> Double {
  let intersection = rect_area(rect_intersection(left, right))
  let union = rect_area(left) + rect_area(right) - intersection
  if union <= 0 {
    0.0
  } else {
    Double::from_int(intersection) / Double::from_int(union)
  }
}

///|
pub fn rect_expand(rect : Rect, margin : Int) -> Rect {
  let safe = if margin < 0 { 0 } else { margin }
  Rect::new(rect.x0 - safe, rect.y0 - safe, rect.x1 + safe, rect.y1 + safe)
}

///|
pub fn distance_to_line(
  point : FloatPoint2,
  first : FloatPoint2,
  second : FloatPoint2,
) -> Double {
  let dx = second.x - first.x
  let dy = second.y - first.y
  let denominator = advanced_sqrt(dx * dx + dy * dy)
  if denominator <= 0.000000001 {
    point_distance(point, first)
  } else {
    advanced_abs(
      dy * point.x - dx * point.y + second.x * first.y - second.y * first.x,
    ) /
    denominator
  }
}

///|
pub fn project_to_segment(
  point : FloatPoint2,
  first : FloatPoint2,
  second : FloatPoint2,
) -> FloatPoint2 {
  let dx = second.x - first.x
  let dy = second.y - first.y
  let squared = dx * dx + dy * dy
  if squared <= 0.000000001 {
    return first
  }
  let mut t = ((point.x - first.x) * dx + (point.y - first.y) * dy) / squared
  if t < 0.0 {
    t = 0.0
  }
  if t > 1.0 {
    t = 1.0
  }
  FloatPoint2::new(first.x + t * dx, first.y + t * dy)
}

///|
pub fn polyline_length(points : Array[FloatPoint2]) -> Double {
  let mut total = 0.0
  let mut i = 1
  while i < points.length() {
    total = total + point_distance(points[i - 1], points[i])
    i = i + 1
  }
  total
}

///|
pub fn simplify_polyline(
  points : Array[FloatPoint2],
  tolerance : Double,
) -> Array[FloatPoint2] {
  if points.length() <= 2 || tolerance <= 0.0 {
    return points
  }
  let result : Array[FloatPoint2] = [points[0]]
  let mut last = points[0]
  let mut i = 1
  while i < points.length() - 1 {
    if point_distance(last, points[i]) >= tolerance {
      result.push(points[i])
      last = points[i]
    }
    i = i + 1
  }
  result.push(points[points.length() - 1])
  result
}

///|
pub fn inlier_centroid(
  matches : Array[Match],
  keypoints : Array[Keypoint],
) -> FloatPoint2 {
  let points : Array[FloatPoint2] = []
  let mut i = 0
  while i < matches.length() {
    let index = matches[i].query_idx
    if index >= 0 && index < keypoints.length() {
      points.push(
        FloatPoint2::new(
          Double::from_int(keypoints[index].x),
          Double::from_int(keypoints[index].y),
        ),
      )
    }
    i = i + 1
  }
  point_cloud_centroid(points)
}

///|
pub fn model_residual_summary(
  model : Homography,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
  threshold : Double,
) -> ResidualSummary {
  summarize_residuals(
    homography_residual_profile(model, source, target),
    threshold,
  )
}

///|
pub fn affine_model_residual_summary(
  model : AffineTransform,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
  threshold : Double,
) -> ResidualSummary {
  summarize_residuals(affine_residual_profile(model, source, target), threshold)
}
