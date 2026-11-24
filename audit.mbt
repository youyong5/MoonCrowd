// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
/// A geometric overlap counted once, independently of neighbor selection.
#derive(Eq, Debug)
pub(all) struct AgentOverlap {
  first : Int32
  second : Int32
  clearance : Double
}

///|
/// Signed clearance to a solid obstacle (or two-sided wall).
#derive(Eq, Debug)
pub(all) struct ObstacleOverlap {
  agent : Int32
  obstacle : Int32
  clearance : Double
  center_inside : Bool
}

///|
/// An explicit O(n^2 + n*edges) audit of the current committed geometry.
/// Negative clearance indicates penetration; None means no relevant pairs.
#derive(Eq, Debug)
pub(all) struct AuditReport {
  step : Int32
  time : Double
  tolerance : Double
  agent_overlap_count : Int32
  obstacle_overlap_count : Int32
  details_truncated : Bool
  agent_overlaps : Array[AgentOverlap]
  obstacle_overlaps : Array[ObstacleOverlap]
  minimum_agent_clearance : Double?
  minimum_obstacle_clearance : Double?
}

///|
/// This report is clear within its tolerance at this instant only.
pub fn AuditReport::is_clear(self : AuditReport) -> Bool {
  self.agent_overlap_count == 0 && self.obstacle_overlap_count == 0
}

///|
fn minimum_option(current : Double?, value : Double) -> Double? {
  Some(
    match current {
      Some(previous) => previous.min(value)
      None => value
    },
  )
}

///|
/// Audit all current discs and obstacles, including missed/disabled neighbors.
/// This is observational: no repositioning, speed changes or solver changes.
/// Tangency and penetration within tolerance are not counted as overlaps.
pub fn Simulator::audit(
  self : Simulator,
  tolerance~ : Double = 1.0e-7,
  max_details~ : Int32 = 1024,
) -> AuditReport raise CrowdError {
  if !tolerance.is_finite() || tolerance < 0.0 || tolerance > 1.0e6 {
    raise InvalidInput("audit tolerance must be finite and in [0, 1e6]")
  }
  if max_details < 0 || max_details > 1000000 {
    raise InvalidInput("audit max_details must be in [0, 1000000]")
  }
  let active = self.states()
  let agent_overlaps : Array[AgentOverlap] = []
  let obstacle_overlaps : Array[ObstacleOverlap] = []
  let mut min_agents : Double? = None
  let mut min_obstacles : Double? = None
  let mut pair_count = 0
  let mut contact_count = 0
  for i in 0..<active.length() {
    let a = active[i]
    for j in (i + 1)..<active.length() {
      let b = active[j]
      let clearance = a.position.distance(b.position) -
        a.config.radius -
        b.config.radius
      min_agents = minimum_option(min_agents, clearance)
      if clearance < -tolerance {
        pair_count += 1
        if agent_overlaps.length() < max_details {
          agent_overlaps.push({ first: a.id, second: b.id, clearance, })
        }
      }
    }
    for obstacle_id, slot in self.obstacles {
      if slot is Some(points) {
        let mut distance_sq = 1.0e100
        for k in 0..<points.length() {
          distance_sq = distance_sq.min(
            segment_distance_sq(
              a.position,
              points[k],
              points[(k + 1) % points.length()],
            ),
          )
        }
        let center_inside = point_inside(a.position, points)
        let signed_distance = if center_inside {
          -distance_sq.sqrt()
        } else {
          distance_sq.sqrt()
        }
        let clearance = signed_distance - a.config.radius
        min_obstacles = minimum_option(min_obstacles, clearance)
        if clearance < -tolerance {
          contact_count += 1
          if obstacle_overlaps.length() < max_details {
            obstacle_overlaps.push({
              agent: a.id,
              obstacle: obstacle_id,
              clearance,
              center_inside,
            })
          }
        }
      }
    }
  }
  {
    step: self.tick,
    time: self.time(),
    tolerance,
    agent_overlap_count: pair_count,
    obstacle_overlap_count: contact_count,
    details_truncated: pair_count > agent_overlaps.length() ||
    contact_count > obstacle_overlaps.length(),
    agent_overlaps,
    obstacle_overlaps,
    minimum_agent_clearance: min_agents,
    minimum_obstacle_clearance: min_obstacles,
  }
}
