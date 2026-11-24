// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0
// Original deterministic bounding-box tree; not a port of RVO2's KdTree.

///|
priv enum NeighborTree {
  Leaf(Array[AgentState])
  Branch(Vec2, Vec2, NeighborTree, NeighborTree)
}

///|
fn build_tree(agents : Array[AgentState], depth : Int32) -> NeighborTree {
  if agents.length() <= 8 {
    return Leaf(agents)
  }
  let mut min_x = agents[0].position.x
  let mut min_y = agents[0].position.y
  let mut max_x = min_x
  let mut max_y = min_y
  for a in agents {
    min_x = min_x.min(a.position.x)
    max_x = max_x.max(a.position.x)
    min_y = min_y.min(a.position.y)
    max_y = max_y.max(a.position.y)
  }
  let x_axis = max_x - min_x >= max_y - min_y
  agents.sort_by(fn(a, b) {
    let av = if x_axis { a.position.x } else { a.position.y }
    let bv = if x_axis { b.position.x } else { b.position.y }
    if av < bv {
      -1
    } else if av > bv {
      1
    } else {
      a.id.compare(b.id)
    }
  })
  let mid = agents.length() / 2
  let lo = agents[:mid].to_owned()
  let hi = agents[mid:].to_owned()
  Branch(
    Vec2::new(min_x, min_y),
    Vec2::new(max_x, max_y),
    build_tree(lo, depth + 1),
    build_tree(hi, depth + 1),
  )
}

///|
fn query_tree(
  tree : NeighborTree,
  agent : AgentState,
  output : Array[(Double, AgentState)],
) -> Unit {
  let range_sq = agent.config.neighbor_distance * agent.config.neighbor_distance
  match tree {
    Leaf(items) =>
      for other in items {
        if agent.id != other.id {
          let distance = (agent.position - other.position).length_squared()
          if distance < range_sq {
            output.push((distance, other))
          }
        }
      }
    Branch(lo, hi, left, right) => {
      let p = agent.position
      let dx = (lo.x - p.x).max(0.0).max(p.x - hi.x)
      let dy = (lo.y - p.y).max(0.0).max(p.y - hi.y)
      if dx * dx + dy * dy < range_sq {
        query_tree(left, agent, output)
        query_tree(right, agent, output)
      }
    }
  }
}

///|
fn neighbors(
  tree : NeighborTree,
  agent : AgentState,
) -> Array[(Double, AgentState)] {
  let found : Array[(Double, AgentState)] = []
  if agent.config.max_neighbors == 0 {
    return found
  }
  query_tree(tree, agent, found)
  found.sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      a.1.id.compare(b.1.id)
    }
  })
  found
}
