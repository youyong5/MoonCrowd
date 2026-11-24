// Adapted from RVO2 Agent.cc, commit 6b4eb00a93a9f3abf723235ff006d6aad3e2f212.
// Copyright 2008 University of North Carolina at Chapel Hill.
// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0
// See NOTICE and docs/UPSTREAM.md for attribution and adaptation boundaries.

///|
let epsilon : Double = 1.0e-5

///|
fn lp1(
  lines : Array[Constraint],
  index : Int32,
  radius : Double,
  target : Vec2,
  direction_opt : Bool,
) -> Vec2? {
  let line = lines[index]
  let dp = line.point.dot(line.direction)
  let disc = dp * dp + radius * radius - line.point.length_squared()
  if disc < 0.0 {
    return None
  }
  let root = disc.sqrt()
  let mut lo = -dp - root
  let mut hi = -dp + root
  for i in 0..<index {
    let denom = det(line.direction, lines[i].direction)
    let numer = det(lines[i].direction, line.point - lines[i].point)
    if denom.abs() <= epsilon {
      if numer < 0.0 {
        return None
      }
      continue
    }
    let t = numer / denom
    if denom >= 0.0 {
      hi = hi.min(t)
    } else {
      lo = lo.max(t)
    }
    if lo > hi {
      return None
    }
  }
  let t = if direction_opt {
    if target.dot(line.direction) > 0.0 {
      hi
    } else {
      lo
    }
  } else {
    line.direction.dot(target - line.point).max(lo).min(hi)
  }
  Some(line.point + line.direction.scale(t))
}

///|
fn lp2(
  lines : Array[Constraint],
  radius : Double,
  target : Vec2,
  direction_opt : Bool,
) -> (Int32, Vec2) {
  let mut result = if direction_opt {
    target.scale(radius)
  } else {
    clamp_length(target, radius)
  }
  for i in 0..<lines.length() {
    if det(lines[i].direction, lines[i].point - result) > 0.0 {
      match lp1(lines, i, radius, target, direction_opt) {
        Some(v) => result = v
        None => return (i, result)
      }
    }
  }
  (lines.length(), result)
}

///|
fn lp3(
  lines : Array[Constraint],
  num_obstacles : Int32,
  begin : Int32,
  radius : Double,
  initial : Vec2,
) -> Vec2 {
  let mut result = initial
  let mut distance = 0.0
  for i in begin..<lines.length() {
    if det(lines[i].direction, lines[i].point - result) > distance {
      let projected : Array[Constraint] = []
      for j in 0..<num_obstacles {
        projected.push(lines[j])
      }
      for j in num_obstacles..<i {
        let denominator = det(lines[i].direction, lines[j].direction)
        let point = if denominator.abs() <= epsilon {
          if lines[i].direction.dot(lines[j].direction) > 0.0 {
            continue
          }
          (lines[i].point + lines[j].point).scale(0.5)
        } else {
          lines[i].point +
          lines[i].direction.scale(
            det(lines[j].direction, lines[i].point - lines[j].point) /
            denominator,
          )
        }
        projected.push({
          point,
          direction: unit(lines[j].direction - lines[i].direction),
          obstacle: false,
        })
      }
      let (fail, candidate) = lp2(
        projected,
        radius,
        { x: -lines[i].direction.y, y: lines[i].direction.x, },
        true,
      )
      if fail == projected.length() {
        result = candidate
      }
      distance = det(lines[i].direction, lines[i].point - result)
    }
  }
  result
}
