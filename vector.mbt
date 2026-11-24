// Copyright 2026 MoonCrowd contributors. SPDX-License-Identifier: Apache-2.0

///|
/// A value vector in a Cartesian, Y-up coordinate system.
#derive(Eq, Debug)
pub(all) struct Vec2 {
  x : Double
  y : Double
}

///|
pub fn Vec2::new(x : Double, y : Double) -> Vec2 {
  { x, y, }
}

///|
pub fn Vec2::zero() -> Vec2 {
  { x: 0.0, y: 0.0, }
}

///|
pub impl Add for Vec2 with fn add(a, b) {
  { x: a.x + b.x, y: a.y + b.y, }
}

///|
pub impl Sub for Vec2 with fn sub(a, b) {
  { x: a.x - b.x, y: a.y - b.y, }
}

///|
pub impl Neg for Vec2 with fn neg(a) {
  { x: -a.x, y: -a.y, }
}

///|
pub fn Vec2::scale(self : Vec2, k : Double) -> Vec2 {
  { x: self.x * k, y: self.y * k, }
}

///|
pub fn Vec2::dot(self : Vec2, b : Vec2) -> Double {
  self.x * b.x + self.y * b.y
}

///|
pub fn Vec2::length_squared(self : Vec2) -> Double {
  self.dot(self)
}

///|
pub fn Vec2::length(self : Vec2) -> Double {
  self.length_squared().sqrt()
}

///|
pub fn Vec2::distance(self : Vec2, b : Vec2) -> Double {
  (self - b).length()
}

///|
pub fn Vec2::is_finite(self : Vec2) -> Bool {
  self.x.is_finite() && self.y.is_finite()
}

///|
fn det(a : Vec2, b : Vec2) -> Double {
  a.x * b.y - a.y * b.x
}

///|
fn left_of(a : Vec2, b : Vec2, c : Vec2) -> Double {
  det(b - a, c - a)
}

///|
fn unit(v : Vec2, fallback~ : Vec2 = { x: 1.0, y: 0.0, }) -> Vec2 {
  let len = v.length()
  if len > 1.0e-12 {
    v.scale(1.0 / len)
  } else {
    fallback
  }
}

///|
fn clamp_length(v : Vec2, limit : Double) -> Vec2 {
  if v.length_squared() > limit * limit {
    unit(v).scale(limit)
  } else {
    v
  }
}

///|
fn segment_distance_sq(p : Vec2, a : Vec2, b : Vec2) -> Double {
  let ab = b - a
  let t = ((p - a).dot(ab) / ab.length_squared()).max(0.0).min(1.0)
  (p - (a + ab.scale(t))).length_squared()
}
