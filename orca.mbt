// Adapted from RVO2 Agent.cc, commit 6b4eb00a93a9f3abf723235ff006d6aad3e2f212.
// Copyright 2008 University of North Carolina at Chapel Hill.
// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
fn agent_line(a : AgentState, b : AgentState, dt : Double) -> Constraint {
  let relative_position = b.position - a.position
  let relative_velocity = a.velocity - b.velocity
  let distance_sq = relative_position.length_squared()
  let radius = a.config.radius + b.config.radius
  let radius_sq = radius * radius
  let inv_horizon = 1.0 / a.config.time_horizon
  let mut direction : Vec2 = Vec2::zero()
  let mut correction : Vec2 = Vec2::zero()
  if distance_sq > radius_sq {
    let w = relative_velocity - relative_position.scale(inv_horizon)
    let w_sq = w.length_squared()
    let dp = w.dot(relative_position)
    if dp < 0.0 && dp * dp > radius_sq * w_sq {
      let w_len = w_sq.sqrt()
      let u = unit(w)
      direction = { x: u.y, y: -u.x, }
      correction = u.scale(radius * inv_horizon - w_len)
    } else {
      let leg = (distance_sq - radius_sq).max(0.0).sqrt()
      direction = if det(relative_position, w) > 0.0 {
        {
          x: relative_position.x * leg - relative_position.y * radius,
          y: relative_position.x * radius + relative_position.y * leg,
        }.scale(1.0 / distance_sq)
      } else {
        -{
          x: relative_position.x * leg + relative_position.y * radius,
          y: -relative_position.x * radius + relative_position.y * leg,
        }.scale(1.0 / distance_sq)
      }
      correction = direction.scale(relative_velocity.dot(direction)) -
        relative_velocity
    }
  } else {
    let w = relative_velocity - relative_position.scale(1.0 / dt)
    // Upstream divides by zero at exact coincident positions/velocities.
    // Antisymmetric stable-ID tie breaking keeps recovery finite and reciprocal.
    let fallback = if a.id < b.id {
      Vec2::new(-1.0, 0.0)
    } else {
      Vec2::new(1.0, 0.0)
    }
    let u = unit(w, fallback~)
    direction = { x: u.y, y: -u.x, }
    correction = u.scale(radius / dt - w.length())
  }
  { point: a.velocity + correction.scale(0.5), direction, obstacle: false, }
}

///|
fn obstacle_lines(agent : AgentState, edges : Array[Edge]) -> Array[Constraint] {
  let lines : Array[Constraint] = []
  let inverse = 1.0 / agent.config.obstacle_horizon
  let radius = agent.config.radius
  let radius_sq = radius * radius
  let velocity = agent.velocity
  for edge in edges {
    let r1 = edge.a - agent.position
    let r2 = edge.b - agent.position
    let mut covered = false
    for line in lines {
      if det(r1.scale(inverse) - line.point, line.direction) - inverse * radius >=
        -epsilon &&
        det(r2.scale(inverse) - line.point, line.direction) - inverse * radius >=
        -epsilon {
        covered = true
        break
      }
    }
    if covered {
      continue
    }
    let dist1 = r1.length_squared()
    let dist2 = r2.length_squared()
    let edge_vector = edge.b - edge.a
    let s = -r1.dot(edge_vector) / edge_vector.length_squared()
    let line_distance = (-r1 - edge_vector.scale(s)).length_squared()
    if s < 0.0 && dist1 <= radius_sq {
      if edge.convex_a {
        lines.push({
          point: Vec2::zero(),
          direction: unit({ x: -r1.y, y: r1.x, }),
          obstacle: true,
        })
      }
      continue
    }
    if s > 1.0 && dist2 <= radius_sq {
      if edge.convex_b && det(r2, edge.next_direction) >= 0.0 {
        lines.push({
          point: Vec2::zero(),
          direction: unit({ x: -r2.y, y: r2.x, }),
          obstacle: true,
        })
      }
      continue
    }
    if s >= 0.0 && s <= 1.0 && line_distance <= radius_sq {
      lines.push({
        point: Vec2::zero(),
        direction: -edge.direction,
        obstacle: true,
      })
      continue
    }
    let mut start = edge.a
    let mut finish = edge.b
    let mut d1 = edge.direction
    let mut d2 = edge.next_direction
    let mut previous = edge.previous_direction
    let mut convex1 = edge.convex_a
    let mut convex2 = edge.convex_b
    let mut same = false
    let mut left : Vec2 = Vec2::zero()
    let mut right : Vec2 = Vec2::zero()
    if s < 0.0 && line_distance <= radius_sq {
      if !convex1 {
        continue
      }
      finish = start
      d2 = d1
      convex2 = convex1
      same = true
      let leg = (dist1 - radius_sq).max(0.0).sqrt()
      left = { x: r1.x * leg - r1.y * radius, y: r1.x * radius + r1.y * leg, }.scale(
        1.0 / dist1,
      )
      right = { x: r1.x * leg + r1.y * radius, y: -r1.x * radius + r1.y * leg, }.scale(
        1.0 / dist1,
      )
    } else if s > 1.0 && line_distance <= radius_sq {
      if !convex2 {
        continue
      }
      start = finish
      previous = d1
      d1 = d2
      convex1 = convex2
      same = true
      let leg = (dist2 - radius_sq).max(0.0).sqrt()
      left = { x: r2.x * leg - r2.y * radius, y: r2.x * radius + r2.y * leg, }.scale(
        1.0 / dist2,
      )
      right = { x: r2.x * leg + r2.y * radius, y: -r2.x * radius + r2.y * leg, }.scale(
        1.0 / dist2,
      )
    } else {
      left = if convex1 {
        let leg = (dist1 - radius_sq).max(0.0).sqrt()
        { x: r1.x * leg - r1.y * radius, y: r1.x * radius + r1.y * leg, }.scale(
          1.0 / dist1,
        )
      } else {
        -d1
      }
      right = if convex2 {
        let leg = (dist2 - radius_sq).max(0.0).sqrt()
        { x: r2.x * leg + r2.y * radius, y: -r2.x * radius + r2.y * leg, }.scale(
          1.0 / dist2,
        )
      } else {
        d1
      }
    }
    let mut foreign_left = false
    let mut foreign_right = false
    if convex1 && det(left, -previous) >= 0.0 {
      left = -previous
      foreign_left = true
    }
    if convex2 && det(right, d2) <= 0.0 {
      right = d2
      foreign_right = true
    }
    let left_cut = (start - agent.position).scale(inverse)
    let right_cut = (finish - agent.position).scale(inverse)
    let cut_vector = right_cut - left_cut
    let t = if same {
      0.5
    } else {
      (velocity - left_cut).dot(cut_vector) / cut_vector.length_squared()
    }
    let tl = (velocity - left_cut).dot(left)
    let tr = (velocity - right_cut).dot(right)
    if (t < 0.0 && tl < 0.0) || (same && tl < 0.0 && tr < 0.0) {
      let u = unit(velocity - left_cut)
      lines.push({
        point: left_cut + u.scale(radius * inverse),
        direction: { x: u.y, y: -u.x, },
        obstacle: true,
      })
      continue
    }
    if t > 1.0 && tr < 0.0 {
      let u = unit(velocity - right_cut)
      lines.push({
        point: right_cut + u.scale(radius * inverse),
        direction: { x: u.y, y: -u.x, },
        obstacle: true,
      })
      continue
    }
    let dc = if t < 0.0 || t > 1.0 || same {
      1.0e100
    } else {
      (velocity - left_cut - cut_vector.scale(t)).length_squared()
    }
    let dl = if tl < 0.0 {
      1.0e100
    } else {
      (velocity - left_cut - left.scale(tl)).length_squared()
    }
    let dr = if tr < 0.0 {
      1.0e100
    } else {
      (velocity - right_cut - right.scale(tr)).length_squared()
    }
    let mut direction : Vec2 = Vec2::zero()
    let mut cutoff : Vec2 = Vec2::zero()
    if dc <= dl && dc <= dr {
      direction = -d1
      cutoff = left_cut
    } else if dl <= dr {
      if foreign_left {
        continue
      }
      direction = left
      cutoff = left_cut
    } else {
      if foreign_right {
        continue
      }
      direction = -right
      cutoff = right_cut
    }
    lines.push({
      point: cutoff +
      Vec2::new(-direction.y, direction.x).scale(radius * inverse),
      direction,
      obstacle: true,
    })
  }
  lines
}
