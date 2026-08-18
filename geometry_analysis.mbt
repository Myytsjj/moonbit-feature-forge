// Geometric utilities for inspecting matches and validating estimated models.

///|
pub(all) struct GeometryQuality {
  count : Int
  mean_error : Double
  rms_error : Double
  maximum_error : Double
  passed : Bool
}

///|
pub(all) struct AffineDecomposition {
  scale_x : Double
  scale_y : Double
  rotation : Double
  shear : Double
  translation_x : Double
  translation_y : Double
  reflected : Bool
}

///|
fn geometry_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn geometry_sqrt(value : Double) -> Double {
  if value <= 0.000000000001 {
    return 0.0
  }
  let mut estimate = if value > 1.0 { value } else { 1.0 }
  let mut i = 0
  while i < 24 {
    estimate = (estimate + value / estimate) / 2.0
    i = i + 1
  }
  estimate
}

///|
pub fn point_bounds(points : Array[FloatPoint2]) -> Rect {
  if points.length() == 0 {
    return Rect::new(0, 0, 0, 0)
  }
  let mut left = points[0].x
  let mut top = points[0].y
  let mut right = points[0].x
  let mut bottom = points[0].y
  let mut i = 1
  while i < points.length() {
    let point = points[i]
    if point.x < left {
      left = point.x
    }
    if point.y < top {
      top = point.y
    }
    if point.x > right {
      right = point.x
    }
    if point.y > bottom {
      bottom = point.y
    }
    i = i + 1
  }
  Rect::new(left.to_int(), top.to_int(), right.to_int(), bottom.to_int())
}

///|
pub fn point_cloud_centroid(points : Array[FloatPoint2]) -> FloatPoint2 {
  if points.length() == 0 {
    return FloatPoint2::new(0.0, 0.0)
  }
  let mut x = 0.0
  let mut y = 0.0
  let mut i = 0
  while i < points.length() {
    x = x + points[i].x
    y = y + points[i].y
    i = i + 1
  }
  let count = Double::from_int(points.length())
  FloatPoint2::new(x / count, y / count)
}

///|
pub fn point_distance(left : FloatPoint2, right : FloatPoint2) -> Double {
  let dx = left.x - right.x
  let dy = left.y - right.y
  geometry_sqrt(dx * dx + dy * dy)
}

///|
pub fn triangle_area(
  first : FloatPoint2,
  second : FloatPoint2,
  third : FloatPoint2,
) -> Double {
  let value = (second.x - first.x) * (third.y - first.y) -
    (second.y - first.y) * (third.x - first.x)
  geometry_abs(value) / 2.0
}

///|
pub fn polygon_area(points : Array[FloatPoint2]) -> Double {
  if points.length() < 3 {
    return 0.0
  }
  let mut twice = 0.0
  let mut i = 0
  while i < points.length() {
    let next = (i + 1) % points.length()
    twice = twice + points[i].x * points[next].y - points[next].x * points[i].y
    i = i + 1
  }
  geometry_abs(twice) / 2.0
}

///|
pub fn polygon_centroid(points : Array[FloatPoint2]) -> FloatPoint2 {
  if points.length() < 3 {
    return point_cloud_centroid(points)
  }
  let mut cross_total = 0.0
  let mut x_total = 0.0
  let mut y_total = 0.0
  let mut i = 0
  while i < points.length() {
    let next = (i + 1) % points.length()
    let cross = points[i].x * points[next].y - points[next].x * points[i].y
    cross_total = cross_total + cross
    x_total = x_total + (points[i].x + points[next].x) * cross
    y_total = y_total + (points[i].y + points[next].y) * cross
    i = i + 1
  }
  if geometry_abs(cross_total) < 0.000000001 {
    point_cloud_centroid(points)
  } else {
    FloatPoint2::new(
      x_total / (3.0 * cross_total),
      y_total / (3.0 * cross_total),
    )
  }
}

///|
fn geometry_cross(
  origin : FloatPoint2,
  left : FloatPoint2,
  right : FloatPoint2,
) -> Double {
  (left.x - origin.x) * (right.y - origin.y) -
  (left.y - origin.y) * (right.x - origin.x)
}

///|
fn geometry_point_before(left : FloatPoint2, right : FloatPoint2) -> Bool {
  left.x < right.x || (left.x == right.x && left.y < right.y)
}

///|
fn sort_geometry_points(points : Array[FloatPoint2]) -> Unit {
  let mut i = 1
  while i < points.length() {
    let current = points[i]
    let mut j = i
    while j > 0 && geometry_point_before(current, points[j - 1]) {
      points[j] = points[j - 1]
      j = j - 1
    }
    points[j] = current
    i = i + 1
  }
}

///|
fn geometry_same_point(left : FloatPoint2, right : FloatPoint2) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
pub fn convex_hull(points : Array[FloatPoint2]) -> Array[FloatPoint2] {
  if points.length() <= 1 {
    return points
  }
  let sorted : Array[FloatPoint2] = []
  let mut i = 0
  while i < points.length() {
    let mut duplicate = false
    let mut j = 0
    while j < sorted.length() {
      if geometry_same_point(points[i], sorted[j]) {
        duplicate = true
      }
      j = j + 1
    }
    if !duplicate {
      sorted.push(points[i])
    }
    i = i + 1
  }
  sort_geometry_points(sorted)
  if sorted.length() <= 2 {
    return sorted
  }
  let lower : Array[FloatPoint2] = []
  i = 0
  while i < sorted.length() {
    while lower.length() >= 2 &&
          geometry_cross(
            lower[lower.length() - 2],
            lower[lower.length() - 1],
            sorted[i],
          ) <=
          0.0 {
      ignore(lower.pop())
    }
    lower.push(sorted[i])
    i = i + 1
  }
  let upper : Array[FloatPoint2] = []
  i = sorted.length() - 1
  while i >= 0 {
    while upper.length() >= 2 &&
          geometry_cross(
            upper[upper.length() - 2],
            upper[upper.length() - 1],
            sorted[i],
          ) <=
          0.0 {
      ignore(upper.pop())
    }
    upper.push(sorted[i])
    i = i - 1
  }
  ignore(lower.pop())
  ignore(upper.pop())
  let result : Array[FloatPoint2] = []
  i = 0
  while i < lower.length() {
    result.push(lower[i])
    i = i + 1
  }
  i = 0
  while i < upper.length() {
    result.push(upper[i])
    i = i + 1
  }
  result
}

///|
pub fn point_in_polygon(
  point : FloatPoint2,
  polygon : Array[FloatPoint2],
) -> Bool {
  if polygon.length() < 3 {
    return false
  }
  let mut inside = false
  let mut i = 0
  let mut j = polygon.length() - 1
  while i < polygon.length() {
    let first = polygon[i]
    let second = polygon[j]
    let crosses = (first.y > point.y) != (second.y > point.y)
    if crosses {
      let x_at_y = (second.x - first.x) *
        (point.y - first.y) /
        (second.y - first.y) +
        first.x
      if point.x < x_at_y {
        inside = !inside
      }
    }
    j = i
    i = i + 1
  }
  inside
}

///|
pub fn polygon_is_convex(points : Array[FloatPoint2]) -> Bool {
  if points.length() < 3 {
    return false
  }
  let mut sign = 0
  let mut i = 0
  while i < points.length() {
    let cross = geometry_cross(
      points[i],
      points[(i + 1) % points.length()],
      points[(i + 2) % points.length()],
    )
    if geometry_abs(cross) > 0.000000001 {
      let current_sign = if cross > 0.0 { 1 } else { -1 }
      if sign == 0 {
        sign = current_sign
      } else if sign != current_sign {
        return false
      }
    }
    i = i + 1
  }
  sign != 0
}

///|
pub fn quadrilateral_area(width : Int, height : Int) -> Double {
  let safe_width = if width < 0 { 0 } else { width }
  let safe_height = if height < 0 { 0 } else { height }
  Double::from_int(safe_width * safe_height)
}

///|
pub fn homography_corners(
  model : Homography,
  width : Int,
  height : Int,
) -> Array[FloatPoint2] {
  let safe_width = if width < 0 { 0 } else { width }
  let safe_height = if height < 0 { 0 } else { height }
  let source : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(Double::from_int(safe_width), 0.0),
    FloatPoint2::new(
      Double::from_int(safe_width),
      Double::from_int(safe_height),
    ),
    FloatPoint2::new(0.0, Double::from_int(safe_height)),
  ]
  transform_points(model, source)
}

///|
pub fn transform_points(
  model : Homography,
  points : Array[FloatPoint2],
) -> Array[FloatPoint2] {
  let result : Array[FloatPoint2] = []
  let mut i = 0
  while i < points.length() {
    match model.project(points[i]) {
      None => ()
      Some(value) => result.push(value)
    }
    i = i + 1
  }
  result
}

///|
pub fn homography_quality_report(
  model : Homography,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> GeometryQuality {
  let stats = reprojection_stats(model, source, target)
  {
    count: stats.count,
    mean_error: stats.mean,
    rms_error: stats.rms,
    maximum_error: stats.maximum,
    passed: stats.count > 0 && stats.maximum < 3.0,
  }
}

///|
pub fn geometry_quality_score(
  quality : GeometryQuality,
  tolerance : Double,
) -> Double {
  if quality.count == 0 || tolerance <= 0.0 {
    return 0.0
  }
  let error_score = if quality.mean_error >= tolerance {
    0.0
  } else {
    1.0 - quality.mean_error / tolerance
  }
  let count_score = if quality.count >= 20 {
    1.0
  } else {
    Double::from_int(quality.count) / 20.0
  }
  error_score * count_score
}

///|
pub fn decompose_affine(transform : AffineTransform) -> AffineDecomposition {
  let scale_x = geometry_sqrt(
    transform.a * transform.a + transform.c * transform.c,
  )
  let determinant = transform.a * transform.d - transform.b * transform.c
  let scale_y = if scale_x <= 0.000000001 {
    geometry_sqrt(transform.b * transform.b + transform.d * transform.d)
  } else {
    geometry_abs(determinant) / scale_x
  }
  let rotation = if scale_x <= 0.000000001 {
    0.0
  } else {
    let ratio = transform.c / scale_x
    if ratio > 1.0 {
      1.5707963267948966
    } else if ratio < -1.0 {
      -1.5707963267948966
    } else {
      let angle = ratio - ratio * ratio * ratio / 3.0
      if transform.a < 0.0 {
        3.141592653589793 - angle
      } else {
        angle
      }
    }
  }
  let shear = if scale_x <= 0.000000001 {
    0.0
  } else {
    (transform.a * transform.b + transform.c * transform.d) /
    (scale_x * scale_x)
  }
  {
    scale_x,
    scale_y,
    rotation,
    shear,
    translation_x: transform.tx,
    translation_y: transform.ty,
    reflected: determinant < 0.0,
  }
}

///|
pub fn line_intersection(
  first : FloatPoint2,
  second : FloatPoint2,
  third : FloatPoint2,
  fourth : FloatPoint2,
) -> FloatPoint2? {
  let dx1 = second.x - first.x
  let dy1 = second.y - first.y
  let dx2 = fourth.x - third.x
  let dy2 = fourth.y - third.y
  let determinant = dx1 * dy2 - dy1 * dx2
  if geometry_abs(determinant) < 0.000000001 {
    return None
  }
  let t = ((third.x - first.x) * dy2 - (third.y - first.y) * dx2) / determinant
  Some(FloatPoint2::new(first.x + t * dx1, first.y + t * dy1))
}

///|
pub fn affine_transform_points(
  transform : AffineTransform,
  points : Array[FloatPoint2],
) -> Array[FloatPoint2] {
  let result : Array[FloatPoint2] = []
  let mut i = 0
  while i < points.length() {
    let (x, y) = transform.apply(points[i].x, points[i].y)
    result.push(FloatPoint2::new(x, y))
    i = i + 1
  }
  result
}

///|
pub fn affine_bounds(
  transform : AffineTransform,
  width : Int,
  height : Int,
) -> Rect {
  let points : Array[FloatPoint2] = [
    FloatPoint2::new(0.0, 0.0),
    FloatPoint2::new(Double::from_int(width), 0.0),
    FloatPoint2::new(Double::from_int(width), Double::from_int(height)),
    FloatPoint2::new(0.0, Double::from_int(height)),
  ]
  point_bounds(affine_transform_points(transform, points))
}

///|
pub fn homography_is_orientation_preserving(
  model : Homography,
  width : Int,
  height : Int,
) -> Bool {
  let corners = homography_corners(model, width, height)
  corners.length() >= 3 &&
  triangle_signed_area(corners[0], corners[1], corners[2]) > 0.0
}

///|
fn triangle_signed_area(
  first : FloatPoint2,
  second : FloatPoint2,
  third : FloatPoint2,
) -> Double {
  (
    (second.x - first.x) * (third.y - first.y) -
    (second.y - first.y) * (third.x - first.x)
  ) /
  2.0
}

///|
pub fn quadrilateral_condition(points : Array[FloatPoint2]) -> Double {
  if points.length() < 4 {
    return 0.0
  }
  let diagonal1 = point_distance(points[0], points[2])
  let diagonal2 = point_distance(points[1], points[3])
  let shortest = if diagonal1 < diagonal2 { diagonal1 } else { diagonal2 }
  let longest = if diagonal1 > diagonal2 { diagonal1 } else { diagonal2 }
  if shortest <= 0.000000001 {
    0.0
  } else {
    longest / shortest
  }
}

///|
pub fn is_degenerate_triangle(
  first : FloatPoint2,
  second : FloatPoint2,
  third : FloatPoint2,
  tolerance : Double,
) -> Bool {
  let limit = if tolerance < 0.0 { 0.0 } else { tolerance }
  triangle_area(first, second, third) <= limit
}

///|
pub fn is_degenerate_polygon(
  points : Array[FloatPoint2],
  tolerance : Double,
) -> Bool {
  let limit = if tolerance < 0.0 { 0.0 } else { tolerance }
  polygon_area(points) <= limit
}

///|
pub fn point_spread(points : Array[FloatPoint2]) -> Double {
  if points.length() < 2 {
    return 0.0
  }
  let center = point_cloud_centroid(points)
  let mut total = 0.0
  let mut i = 0
  while i < points.length() {
    let distance = point_distance(points[i], center)
    total = total + distance * distance
    i = i + 1
  }
  geometry_sqrt(total / Double::from_int(points.length()))
}

///|
pub fn homography_residual_profile(
  model : Homography,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> Array[Double] {
  let result : Array[Double] = []
  let count = if source.length() < target.length() {
    source.length()
  } else {
    target.length()
  }
  let mut i = 0
  while i < count {
    result.push(geometry_sqrt(reprojection_error(model, source[i], target[i])))
    i = i + 1
  }
  result
}

///|
pub fn affine_residual_profile(
  transform : AffineTransform,
  source : Array[FloatPoint2],
  target : Array[FloatPoint2],
) -> Array[Double] {
  let result : Array[Double] = []
  let count = if source.length() < target.length() {
    source.length()
  } else {
    target.length()
  }
  let mut i = 0
  while i < count {
    let (x, y) = transform.apply(source[i].x, source[i].y)
    result.push(point_distance(FloatPoint2::new(x, y), target[i]))
    i = i + 1
  }
  result
}

///|
pub fn residual_mean(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut i = 0
  while i < values.length() {
    total = total + values[i]
    i = i + 1
  }
  total / Double::from_int(values.length())
}

///|
pub fn residual_rms(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut i = 0
  while i < values.length() {
    total = total + values[i] * values[i]
    i = i + 1
  }
  geometry_sqrt(total / Double::from_int(values.length()))
}

///|
pub fn residual_maximum(values : Array[Double]) -> Double {
  let mut maximum = 0.0
  let mut i = 0
  while i < values.length() {
    if values[i] > maximum {
      maximum = values[i]
    }
    i = i + 1
  }
  maximum
}
