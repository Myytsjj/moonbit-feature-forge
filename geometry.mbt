// Affine/projective geometry and reprojection diagnostics.

///|
pub(all) struct Homography {
  h00 : Double
  h01 : Double
  h02 : Double
  h10 : Double
  h11 : Double
  h12 : Double
  h20 : Double
  h21 : Double
  h22 : Double
}

///|
pub fn Homography::identity() -> Homography {
  {
    h00: 1.0,
    h01: 0.0,
    h02: 0.0,
    h10: 0.0,
    h11: 1.0,
    h12: 0.0,
    h20: 0.0,
    h21: 0.0,
    h22: 1.0,
  }
}

///|
fn abs_geometry(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn sqrt_geometry(value : Double) -> Double {
  if value <= 0.000000000001 {
    0.0
  } else {
    let mut estimate = if value > 1.0 { value } else { 1.0 }
    let mut iteration = 0
    while iteration < 24 {
      estimate = (estimate + value / estimate) / 2.0
      iteration = iteration + 1
    }
    estimate
  }
}

///|
pub fn Homography::project(
  self : Homography,
  point : FloatPoint2,
) -> FloatPoint2? {
  let denominator = self.h20 * point.x + self.h21 * point.y + self.h22
  if abs_geometry(denominator) < 0.000000001 {
    None
  } else {
    Some(
      FloatPoint2::new(
        (self.h00 * point.x + self.h01 * point.y + self.h02) / denominator,
        (self.h10 * point.x + self.h11 * point.y + self.h12) / denominator,
      ),
    )
  }
}

///|
pub fn Homography::inverse(self : Homography) -> Homography? {
  let determinant = self.h00 * (self.h11 * self.h22 - self.h12 * self.h21) -
    self.h01 * (self.h10 * self.h22 - self.h12 * self.h20) +
    self.h02 * (self.h10 * self.h21 - self.h11 * self.h20)
  if abs_geometry(determinant) < 0.000000001 {
    return None
  }
  let inverse = 1.0 / determinant
  Some({
    h00: (self.h11 * self.h22 - self.h12 * self.h21) * inverse,
    h01: (self.h02 * self.h21 - self.h01 * self.h22) * inverse,
    h02: (self.h01 * self.h12 - self.h02 * self.h11) * inverse,
    h10: (self.h12 * self.h20 - self.h10 * self.h22) * inverse,
    h11: (self.h00 * self.h22 - self.h02 * self.h20) * inverse,
    h12: (self.h02 * self.h10 - self.h00 * self.h12) * inverse,
    h20: (self.h10 * self.h21 - self.h11 * self.h20) * inverse,
    h21: (self.h01 * self.h20 - self.h00 * self.h21) * inverse,
    h22: (self.h00 * self.h11 - self.h01 * self.h10) * inverse,
  })
}

///|
fn solve_eight_by_eight(matrix : Array[Double]) -> Array[Double]? {
  let work : Array[Double] = []
  let mut copy_index = 0
  while copy_index < matrix.length() {
    work.push(matrix[copy_index])
    copy_index = copy_index + 1
  }
  let mut pivot_row = 0
  while pivot_row < 8 {
    let mut pivot = pivot_row
    let mut candidate = pivot_row + 1
    while candidate < 8 {
      if abs_geometry(work[candidate * 9 + pivot_row]) >
        abs_geometry(work[pivot * 9 + pivot_row]) {
        pivot = candidate
      }
      candidate = candidate + 1
    }
    if abs_geometry(work[pivot * 9 + pivot_row]) < 0.000000001 {
      return None
    }
    if pivot != pivot_row {
      let mut column = pivot_row
      while column <= 8 {
        let temp = work[pivot_row * 9 + column]
        work[pivot_row * 9 + column] = work[pivot * 9 + column]
        work[pivot * 9 + column] = temp
        column = column + 1
      }
    }
    let pivot_value = work[pivot_row * 9 + pivot_row]
    let mut column = pivot_row
    while column <= 8 {
      work[pivot_row * 9 + column] = work[pivot_row * 9 + column] / pivot_value
      column = column + 1
    }
    let mut row = 0
    while row < 8 {
      if row != pivot_row {
        let factor = work[row * 9 + pivot_row]
        column = pivot_row
        while column <= 8 {
          work[row * 9 + column] = work[row * 9 + column] -
            factor * work[pivot_row * 9 + column]
          column = column + 1
        }
      }
      row = row + 1
    }
    pivot_row = pivot_row + 1
  }
  let solution = Array::make(8, 0.0)
  let mut i = 0
  while i < 8 {
    solution[i] = work[i * 9 + 8]
    i = i + 1
  }
  Some(solution)
}

///|
pub fn estimate_homography(
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> Homography? {
  if source.length() < 4 || target.length() < 4 {
    return None
  }
  let matrix = Array::make(72, 0.0)
  let mut i = 0
  while i < 4 {
    let src = source[i]
    let dst = target[i]
    let row_u = i * 2
    let row_v = row_u + 1
    let x = src.x
    let y = src.y
    let u = dst.x
    let v = dst.y
    matrix[row_u * 9 + 0] = x
    matrix[row_u * 9 + 1] = y
    matrix[row_u * 9 + 2] = 1.0
    matrix[row_u * 9 + 6] = -u * x
    matrix[row_u * 9 + 7] = -u * y
    matrix[row_u * 9 + 8] = u
    matrix[row_v * 9 + 3] = x
    matrix[row_v * 9 + 4] = y
    matrix[row_v * 9 + 5] = 1.0
    matrix[row_v * 9 + 6] = -v * x
    matrix[row_v * 9 + 7] = -v * y
    matrix[row_v * 9 + 8] = v
    i = i + 1
  }
  match solve_eight_by_eight(matrix) {
    None => None
    Some(solution) =>
      Some({
        h00: solution[0],
        h01: solution[1],
        h02: solution[2],
        h10: solution[3],
        h11: solution[4],
        h12: solution[5],
        h20: solution[6],
        h21: solution[7],
        h22: 1.0,
      })
  }
}

///|
pub fn estimate_affine_from_points(
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> AffineTransform? {
  if source.length() < 3 || target.length() < 3 {
    return None
  }
  estimate_affine(
    (source[0].x, source[0].y),
    (source[1].x, source[1].y),
    (source[2].x, source[2].y),
    (target[0].x, target[0].y),
    (target[1].x, target[1].y),
    (target[2].x, target[2].y),
  )
}

///|
pub(all) struct ReprojectionStats {
  count : Int
  mean : Double
  rms : Double
  maximum : Double
}

///|
pub fn reprojection_error(
  model : Homography,
  source : FloatPoint2,
  target : FloatPoint2,
) -> Double {
  match model.project(source) {
    None => 1000000000.0
    Some(projected) => {
      let dx = projected.x - target.x
      let dy = projected.y - target.y
      let squared = dx * dx + dy * dy
      squared
    }
  }
}

///|
pub fn reprojection_stats(
  model : Homography,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> ReprojectionStats {
  let count = if source.length() < target.length() {
    source.length()
  } else {
    target.length()
  }
  if count == 0 {
    return { count: 0, mean: 0.0, rms: 0.0, maximum: 0.0 }
  }
  let mut total = 0.0
  let mut squared_total = 0.0
  let mut maximum = 0.0
  let mut i = 0
  while i < count {
    let squared = reprojection_error(model, source[i], target[i])
    let distance = sqrt_geometry(squared)
    total = total + distance
    squared_total = squared_total + squared
    if distance > maximum {
      maximum = distance
    }
    i = i + 1
  }
  {
    count,
    mean: total / Double::from_int(count),
    rms: sqrt_geometry(squared_total / Double::from_int(count)),
    maximum,
  }
}
