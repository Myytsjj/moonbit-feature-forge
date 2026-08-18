// Frame-to-frame feature association and spatial indexing for lightweight
// tracking applications. All choices are deterministic and descriptor-based.

///|
pub(all) struct KeypointGridIndex {
  width : Int
  height : Int
  grid_width : Int
  grid_height : Int
  keypoints : Array[Keypoint]
  buckets : Array[Array[Int]]
}

///|
fn tracking_cell(
  keypoint : Keypoint,
  width : Int,
  height : Int,
  grid_width : Int,
  grid_height : Int,
) -> Int {
  if width <= 0 || height <= 0 || grid_width <= 0 || grid_height <= 0 {
    return 0
  }
  let mut x = keypoint.x * grid_width / width
  let mut y = keypoint.y * grid_height / height
  if x < 0 {
    x = 0
  }
  if y < 0 {
    y = 0
  }
  if x >= grid_width {
    x = grid_width - 1
  }
  if y >= grid_height {
    y = grid_height - 1
  }
  y * grid_width + x
}

///|
pub fn KeypointGridIndex::build(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
  grid_width : Int,
  grid_height : Int,
) -> KeypointGridIndex {
  let safe_grid_width = if grid_width <= 0 { 1 } else { grid_width }
  let safe_grid_height = if grid_height <= 0 { 1 } else { grid_height }
  let buckets : Array[Array[Int]] = []
  let mut i = 0
  while i < safe_grid_width * safe_grid_height {
    buckets.push([])
    i = i + 1
  }
  i = 0
  while i < keypoints.length() {
    let cell = tracking_cell(
      keypoints[i],
      width,
      height,
      safe_grid_width,
      safe_grid_height,
    )
    buckets[cell].push(i)
    i = i + 1
  }
  {
    width,
    height,
    grid_width: safe_grid_width,
    grid_height: safe_grid_height,
    keypoints,
    buckets,
  }
}

///|
pub fn KeypointGridIndex::query_radius(
  self : KeypointGridIndex,
  center : FloatPoint2,
  radius : Double,
) -> Array[Int] {
  let result : Array[Int] = []
  if radius < 0.0 {
    return result
  }
  let radius_int = radius.to_int() + 1
  let center_keypoint = Keypoint::new(
    center.x.to_int(),
    center.y.to_int(),
    0.0,
    0.0,
  )
  let cell = tracking_cell(
    center_keypoint,
    self.width,
    self.height,
    self.grid_width,
    self.grid_height,
  )
  let cell_x = cell % self.grid_width
  let cell_y = cell / self.grid_width
  let cell_radius_x = radius_int *
    self.grid_width /
    (if self.width <= 0 { 1 } else { self.width }) +
    1
  let cell_radius_y = radius_int *
    self.grid_height /
    (if self.height <= 0 { 1 } else { self.height }) +
    1
  let mut dy = -cell_radius_y
  while dy <= cell_radius_y {
    let mut dx = -cell_radius_x
    while dx <= cell_radius_x {
      let nx = cell_x + dx
      let ny = cell_y + dy
      if nx >= 0 && nx < self.grid_width && ny >= 0 && ny < self.grid_height {
        let bucket = self.buckets[ny * self.grid_width + nx]
        let mut i = 0
        while i < bucket.length() {
          let index = bucket[i]
          let point = self.keypoints[index]
          let distance_x = Double::from_int(point.x) - center.x
          let distance_y = Double::from_int(point.y) - center.y
          if distance_x * distance_x + distance_y * distance_y <=
            radius * radius {
            result.push(index)
          }
          i = i + 1
        }
      }
      dx = dx + 1
    }
    dy = dy + 1
  }
  result
}

///|
pub fn KeypointGridIndex::nearest(
  self : KeypointGridIndex,
  center : FloatPoint2,
  radius : Double,
) -> Int? {
  let candidates = self.query_radius(center, radius)
  if candidates.length() == 0 {
    return None
  }
  let mut best = candidates[0]
  let mut best_distance = 1000000000.0
  let mut i = 0
  while i < candidates.length() {
    let point = self.keypoints[candidates[i]]
    let dx = Double::from_int(point.x) - center.x
    let dy = Double::from_int(point.y) - center.y
    let distance = dx * dx + dy * dy
    if distance < best_distance ||
      (distance == best_distance && candidates[i] < best) {
      best = candidates[i]
      best_distance = distance
    }
    i = i + 1
  }
  Some(best)
}

///|
pub fn KeypointGridIndex::occupancy(self : KeypointGridIndex) -> Array[Int] {
  let result = Array::make(self.buckets.length(), 0)
  let mut i = 0
  while i < self.buckets.length() {
    result[i] = self.buckets[i].length()
    i = i + 1
  }
  result
}

///|
pub fn KeypointGridIndex::maximum_occupancy(self : KeypointGridIndex) -> Int {
  let mut maximum = 0
  let mut i = 0
  while i < self.buckets.length() {
    if self.buckets[i].length() > maximum {
      maximum = self.buckets[i].length()
    }
    i = i + 1
  }
  maximum
}

///|
pub(all) struct FeatureAssociation {
  query_idx : Int
  train_idx : Int
  descriptor_distance : Int
  spatial_distance : Double
}

///|
fn tracking_distance(left : Keypoint, right : Keypoint) -> Double {
  let dx = Double::from_int(left.x - right.x)
  let dy = Double::from_int(left.y - right.y)
  let squared = dx * dx + dy * dy
  if squared <= 0.000000001 {
    0.0
  } else {
    let mut estimate = if squared > 1.0 { squared } else { 1.0 }
    let mut i = 0
    while i < 20 {
      estimate = (estimate + squared / estimate) / 2.0
      i = i + 1
    }
    estimate
  }
}

///|
pub fn associate_keypoints(
  query_keypoints : Array[Keypoint],
  query_descriptors : Array[Descriptor],
  train_keypoints : Array[Keypoint],
  train_descriptors : Array[Descriptor],
  maximum_descriptor_distance : Int,
  maximum_spatial_distance : Double,
) -> Array[FeatureAssociation] {
  let result : Array[FeatureAssociation] = []
  if maximum_descriptor_distance < 0 || maximum_spatial_distance < 0.0 {
    return result
  }
  let query_count = if query_keypoints.length() < query_descriptors.length() {
    query_keypoints.length()
  } else {
    query_descriptors.length()
  }
  let train_count = if train_keypoints.length() < train_descriptors.length() {
    train_keypoints.length()
  } else {
    train_descriptors.length()
  }
  let used : Array[Int] = []
  let mut query = 0
  while query < query_count {
    let mut best_train = -1
    let mut best_distance = 2147483647
    let mut best_spatial = 0.0
    let mut train = 0
    while train < train_count {
      if !matching_contains(used, train) {
        let descriptor_distance = hamming_distance(
          query_descriptors[query],
          train_descriptors[train],
        )
        let spatial_distance = tracking_distance(
          query_keypoints[query],
          train_keypoints[train],
        )
        if descriptor_distance <= maximum_descriptor_distance &&
          spatial_distance <= maximum_spatial_distance &&
          (
            descriptor_distance < best_distance ||
            (
              descriptor_distance == best_distance &&
              spatial_distance < best_spatial
            )
          ) {
          best_train = train
          best_distance = descriptor_distance
          best_spatial = spatial_distance
        }
      }
      train = train + 1
    }
    if best_train >= 0 {
      used.push(best_train)
      result.push({
        query_idx: query,
        train_idx: best_train,
        descriptor_distance: best_distance,
        spatial_distance: best_spatial,
      })
    }
    query = query + 1
  }
  result
}

///|
pub fn associations_to_matches(
  associations : Array[FeatureAssociation],
) -> Array[Match] {
  let result : Array[Match] = []
  let mut i = 0
  while i < associations.length() {
    result.push(
      Match::new(
        associations[i].query_idx,
        associations[i].train_idx,
        associations[i].descriptor_distance,
      ),
    )
    i = i + 1
  }
  result
}

///|
pub fn association_mean_distance(
  associations : Array[FeatureAssociation],
) -> Double {
  if associations.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut i = 0
  while i < associations.length() {
    total = total + associations[i].spatial_distance
    i = i + 1
  }
  total / Double::from_int(associations.length())
}

///|
pub(all) struct FeatureTrack {
  id : Int
  keypoints : Array[Keypoint]
  descriptors : Array[Descriptor]
  age : Int
  missed : Int
  active : Bool
}

///|
pub fn FeatureTrack::new(
  id : Int,
  keypoint : Keypoint,
  descriptor : Descriptor,
) -> FeatureTrack {
  {
    id,
    keypoints: [keypoint],
    descriptors: [descriptor],
    age: 1,
    missed: 0,
    active: true,
  }
}

///|
pub fn FeatureTrack::last_keypoint(self : FeatureTrack) -> Keypoint? {
  if self.keypoints.length() == 0 {
    None
  } else {
    Some(self.keypoints[self.keypoints.length() - 1])
  }
}

///|
pub fn FeatureTrack::append(
  self : FeatureTrack,
  keypoint : Keypoint,
  descriptor : Descriptor,
) -> FeatureTrack {
  self.keypoints.push(keypoint)
  self.descriptors.push(descriptor)
  {
    id: self.id,
    keypoints: self.keypoints,
    descriptors: self.descriptors,
    age: self.age + 1,
    missed: 0,
    active: true,
  }
}

///|
pub fn FeatureTrack::mark_missed(
  self : FeatureTrack,
  maximum_missed : Int,
) -> FeatureTrack {
  let missed = self.missed + 1
  {
    id: self.id,
    keypoints: self.keypoints,
    descriptors: self.descriptors,
    age: self.age,
    missed,
    active: missed <= (if maximum_missed < 0 { 0 } else { maximum_missed }),
  }
}

///|
pub fn FeatureTrack::path_length(self : FeatureTrack) -> Double {
  polyline_length(
    self.keypoints.map(fn(point) {
      FloatPoint2::new(Double::from_int(point.x), Double::from_int(point.y))
    }),
  )
}

///|
pub fn FeatureTrack::mean_response(self : FeatureTrack) -> Double {
  if self.keypoints.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut i = 0
  while i < self.keypoints.length() {
    total = total + self.keypoints[i].response
    i = i + 1
  }
  total / Double::from_int(self.keypoints.length())
}

///|
pub fn FeatureTrack::last_descriptor(self : FeatureTrack) -> Descriptor? {
  if self.descriptors.length() == 0 {
    None
  } else {
    Some(self.descriptors[self.descriptors.length() - 1])
  }
}

///|
pub fn FeatureTrack::stability(self : FeatureTrack) -> Double {
  if self.age <= 0 {
    0.0
  } else {
    let active_age = self.age - self.missed
    if active_age <= 0 {
      0.0
    } else {
      Double::from_int(active_age) / Double::from_int(self.age)
    }
  }
}

///|
pub(all) struct TrackSummary {
  count : Int
  active : Int
  total_age : Int
  mean_age : Double
  mean_path_length : Double
  mean_stability : Double
}

///|
pub fn summarize_tracks(tracks : Array[FeatureTrack]) -> TrackSummary {
  let mut active = 0
  let mut total_age = 0
  let mut path = 0.0
  let mut stability = 0.0
  let mut i = 0
  while i < tracks.length() {
    if tracks[i].active {
      active = active + 1
    }
    total_age = total_age + tracks[i].age
    path = path + tracks[i].path_length()
    stability = stability + tracks[i].stability()
    i = i + 1
  }
  let count = Double::from_int(tracks.length())
  {
    count: tracks.length(),
    active,
    total_age,
    mean_age: if tracks.length() == 0 {
      0.0
    } else {
      Double::from_int(total_age) / count
    },
    mean_path_length: if tracks.length() == 0 {
      0.0
    } else {
      path / count
    },
    mean_stability: if tracks.length() == 0 {
      0.0
    } else {
      stability / count
    },
  }
}

///|
pub fn initialize_tracks(
  keypoints : Array[Keypoint],
  descriptors : Array[Descriptor],
  start_id : Int,
) -> Array[FeatureTrack] {
  let result : Array[FeatureTrack] = []
  let count = if keypoints.length() < descriptors.length() {
    keypoints.length()
  } else {
    descriptors.length()
  }
  let mut i = 0
  while i < count {
    result.push(FeatureTrack::new(start_id + i, keypoints[i], descriptors[i]))
    i = i + 1
  }
  result
}

///|
pub fn update_tracks(
  tracks : Array[FeatureTrack],
  keypoints : Array[Keypoint],
  descriptors : Array[Descriptor],
  maximum_descriptor_distance : Int,
  maximum_spatial_distance : Double,
  maximum_missed : Int,
) -> Array[FeatureTrack] {
  let active_indices : Array[Int] = []
  let active_points : Array[Keypoint] = []
  let active_descriptors : Array[Descriptor] = []
  let mut i = 0
  while i < tracks.length() {
    if tracks[i].active {
      match tracks[i].last_keypoint() {
        None => ()
        Some(point) =>
          match tracks[i].last_descriptor() {
            None => ()
            Some(descriptor) => {
              active_indices.push(i)
              active_points.push(point)
              active_descriptors.push(descriptor)
            }
          }
      }
    }
    i = i + 1
  }
  let associations = associate_keypoints(
    active_points, active_descriptors, keypoints, descriptors, maximum_descriptor_distance,
    maximum_spatial_distance,
  )
  let result : Array[FeatureTrack] = []
  let used_new : Array[Int] = []
  i = 0
  while i < tracks.length() {
    let mut found = -1
    let mut a = 0
    while a < associations.length() {
      if active_indices[associations[a].query_idx] == i {
        found = a
      }
      a = a + 1
    }
    if found >= 0 {
      let association = associations[found]
      result.push(
        tracks[i].append(
          keypoints[association.train_idx],
          descriptors[association.train_idx],
        ),
      )
      used_new.push(association.train_idx)
    } else {
      result.push(tracks[i].mark_missed(maximum_missed))
    }
    i = i + 1
  }
  let mut next_id = 0
  i = 0
  while i < tracks.length() {
    if tracks[i].id >= next_id {
      next_id = tracks[i].id + 1
    }
    i = i + 1
  }
  i = 0
  while i < keypoints.length() && i < descriptors.length() {
    if !matching_contains(used_new, i) {
      result.push(FeatureTrack::new(next_id, keypoints[i], descriptors[i]))
      next_id = next_id + 1
    }
    i = i + 1
  }
  result
}

///|
pub fn active_tracks(tracks : Array[FeatureTrack]) -> Array[FeatureTrack] {
  let result : Array[FeatureTrack] = []
  let mut i = 0
  while i < tracks.length() {
    if tracks[i].active {
      result.push(tracks[i])
    }
    i = i + 1
  }
  result
}

///|
pub fn stable_tracks(
  tracks : Array[FeatureTrack],
  minimum_age : Int,
  minimum_stability : Double,
) -> Array[FeatureTrack] {
  let result : Array[FeatureTrack] = []
  let age = if minimum_age < 0 { 0 } else { minimum_age }
  let stability = if minimum_stability < 0.0 {
    0.0
  } else if minimum_stability > 1.0 {
    1.0
  } else {
    minimum_stability
  }
  let mut i = 0
  while i < tracks.length() {
    if tracks[i].active &&
      tracks[i].age >= age &&
      tracks[i].stability() >= stability {
      result.push(tracks[i])
    }
    i = i + 1
  }
  result
}

///|
pub fn track_path(points : Array[Keypoint]) -> Array[FloatPoint2] {
  let result : Array[FloatPoint2] = []
  let mut i = 0
  while i < points.length() {
    result.push(
      FloatPoint2::new(
        Double::from_int(points[i].x),
        Double::from_int(points[i].y),
      ),
    )
    i = i + 1
  }
  result
}

///|
pub fn track_velocity(track : FeatureTrack) -> FloatPoint2 {
  if track.keypoints.length() < 2 {
    return FloatPoint2::new(0.0, 0.0)
  }
  let first = track.keypoints[track.keypoints.length() - 2]
  let second = track.keypoints[track.keypoints.length() - 1]
  FloatPoint2::new(
    Double::from_int(second.x - first.x),
    Double::from_int(second.y - first.y),
  )
}

///|
pub fn track_displacement(track : FeatureTrack) -> FloatPoint2 {
  if track.keypoints.length() < 2 {
    return FloatPoint2::new(0.0, 0.0)
  }
  let first = track.keypoints[0]
  let last = track.keypoints[track.keypoints.length() - 1]
  FloatPoint2::new(
    Double::from_int(last.x - first.x),
    Double::from_int(last.y - first.y),
  )
}

///|
pub fn track_descriptor_consistency(track : FeatureTrack) -> Double {
  if track.descriptors.length() < 2 {
    return 1.0
  }
  let mut total = 0
  let mut i = 0
  while i + 1 < track.descriptors.length() {
    total = total +
      hamming_distance(track.descriptors[i], track.descriptors[i + 1])
    i = i + 1
  }
  let mean = Double::from_int(total) /
    Double::from_int(track.descriptors.length() - 1)
  1.0 / (1.0 + mean)
}

///|
pub fn track_quality(track : FeatureTrack) -> Double {
  let age_score = if track.age >= 10 {
    1.0
  } else {
    Double::from_int(track.age) / 10.0
  }
  age_score * track.stability() * track_descriptor_consistency(track)
}

///|
pub fn track_quality_histogram(
  tracks : Array[FeatureTrack],
  bins : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let mut i = 0
  while i < tracks.length() {
    let score = track_quality(tracks[i])
    let mut slot = (score * Double::from_int(bins)).to_int()
    if slot < 0 {
      slot = 0
    }
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
pub fn motion_histogram(
  tracks : Array[FeatureTrack],
  bins : Int,
  maximum_speed : Double,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let high = if maximum_speed <= 0.0 { 1.0 } else { maximum_speed }
  let mut i = 0
  while i < tracks.length() {
    let velocity = track_velocity(tracks[i])
    let speed_squared = velocity.x * velocity.x + velocity.y * velocity.y
    let mut speed = if speed_squared <= 0.0 {
      0.0
    } else {
      let mut estimate = if speed_squared > 1.0 { speed_squared } else { 1.0 }
      let mut n = 0
      while n < 16 {
        estimate = (estimate + speed_squared / estimate) / 2.0
        n = n + 1
      }
      estimate
    }
    if speed > high {
      speed = high
    }
    let mut slot = (speed * Double::from_int(bins) / high).to_int()
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
pub fn consensus_velocity(tracks : Array[FeatureTrack]) -> FloatPoint2 {
  let velocities : Array[FloatPoint2] = []
  let mut i = 0
  while i < tracks.length() {
    velocities.push(track_velocity(tracks[i]))
    i = i + 1
  }
  point_cloud_centroid(velocities)
}

///|
pub fn filter_tracks_by_velocity(
  tracks : Array[FeatureTrack],
  consensus : FloatPoint2,
  tolerance : Double,
) -> Array[FeatureTrack] {
  let result : Array[FeatureTrack] = []
  if tolerance < 0.0 {
    return result
  }
  let mut i = 0
  while i < tracks.length() {
    let velocity = track_velocity(tracks[i])
    let dx = velocity.x - consensus.x
    let dy = velocity.y - consensus.y
    let distance_squared = dx * dx + dy * dy
    if distance_squared <= tolerance * tolerance {
      result.push(tracks[i])
    }
    i = i + 1
  }
  result
}

///|
pub fn average_descriptor(descriptors : Array[Descriptor]) -> Descriptor {
  let stats = summarize_descriptors(descriptors)
  let result = Descriptor::new(stats.bytes)
  if descriptors.length() == 0 {
    return result
  }
  let mut byte_index = 0
  while byte_index < stats.bytes {
    let mut total = 0
    let mut count = 0
    let mut i = 0
    while i < descriptors.length() {
      if byte_index < descriptors[i].data.length() {
        total = total + descriptors[i].data[byte_index].to_int()
        count = count + 1
      }
      i = i + 1
    }
    if count > 0 {
      result.data[byte_index] = (total / count).to_byte()
    }
    byte_index = byte_index + 1
  }
  result
}

///|
pub fn descriptor_vote(descriptors : Array[Descriptor]) -> Descriptor {
  let stats = summarize_descriptors(descriptors)
  let result = Descriptor::new(stats.bytes)
  let mut byte_index = 0
  while byte_index < stats.bytes {
    let mut bit = 0
    while bit < 8 {
      let mut votes = 0
      let mut i = 0
      while i < descriptors.length() {
        if byte_index < descriptors[i].data.length() &&
          ((descriptors[i].data[byte_index].to_int() >> bit) & 1) != 0 {
          votes = votes + 1
        }
        i = i + 1
      }
      if votes * 2 >= descriptors.length() && descriptors.length() > 0 {
        result.data[byte_index] = (result.data[byte_index].to_int() | (1 << bit)).to_byte()
      }
      bit = bit + 1
    }
    byte_index = byte_index + 1
  }
  result
}

///|
pub fn track_descriptor_vote(track : FeatureTrack) -> Descriptor {
  descriptor_vote(track.descriptors)
}

///|
pub fn tracks_in_rect(
  tracks : Array[FeatureTrack],
  rect : Rect,
) -> Array[FeatureTrack] {
  let result : Array[FeatureTrack] = []
  let mut i = 0
  while i < tracks.length() {
    match tracks[i].last_keypoint() {
      None => ()
      Some(point) =>
        if rect_contains(rect, Point2::new(point.x, point.y)) {
          result.push(tracks[i])
        }
    }
    i = i + 1
  }
  result
}

///|
pub fn track_bounds(tracks : Array[FeatureTrack]) -> Rect {
  let points : Array[Keypoint] = []
  let mut i = 0
  while i < tracks.length() {
    match tracks[i].last_keypoint() {
      None => ()
      Some(point) => points.push(point)
    }
    i = i + 1
  }
  keypoint_bounds(points)
}

///|
pub fn track_coverage(
  tracks : Array[FeatureTrack],
  width : Int,
  height : Int,
) -> Double {
  if width <= 0 || height <= 0 {
    return 0.0
  }
  let bounds = track_bounds(tracks)
  Double::from_int(rect_area(bounds)) / Double::from_int(width * height)
}

///|
pub fn association_spatial_histogram(
  associations : Array[FeatureAssociation],
  bins : Int,
  maximum : Double,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let high = if maximum <= 0.0 { 1.0 } else { maximum }
  let mut i = 0
  while i < associations.length() {
    let mut slot = (associations[i].spatial_distance *
    Double::from_int(bins) /
    high).to_int()
    if slot < 0 {
      slot = 0
    }
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
pub fn association_quality(
  associations : Array[FeatureAssociation],
  maximum_descriptor_distance : Int,
  maximum_spatial_distance : Double,
) -> Double {
  if associations.length() == 0 ||
    maximum_descriptor_distance <= 0 ||
    maximum_spatial_distance <= 0.0 {
    return 0.0
  }
  let mut score = 0.0
  let mut i = 0
  while i < associations.length() {
    let descriptor_score = 1.0 -
      Double::from_int(associations[i].descriptor_distance) /
      Double::from_int(maximum_descriptor_distance)
    let spatial_score = 1.0 -
      associations[i].spatial_distance / maximum_spatial_distance
    score = score +
      (if descriptor_score < 0.0 { 0.0 } else { descriptor_score }) *
      (if spatial_score < 0.0 { 0.0 } else { spatial_score })
    i = i + 1
  }
  score / Double::from_int(associations.length())
}
