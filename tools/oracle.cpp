// MoonCrowd test harness, Apache-2.0. Links unmodified pinned RVO2 for fixtures.
#include "RVO.h"
#include <iomanip>
#include <iostream>
#include <vector>
int main() {
  int cases;
  std::cin >> cases;
  std::cout << std::setprecision(12);
  for (int c = 0; c < cases; ++c) {
    int n, obstacles, steps;
    float dt;
    std::cin >> n >> obstacles >> steps >> dt;
    RVO::RVOSimulator sim;
    sim.setTimeStep(dt);
    for (int o = 0; o < obstacles; ++o) {
      int count;
      std::cin >> count;
      std::vector<RVO::Vector2> vertices;
      for (int j = 0; j < count; ++j) {
        float x, y;
        std::cin >> x >> y;
        vertices.push_back(RVO::Vector2(x, y));
      }
      sim.addObstacle(vertices);
    }
    sim.processObstacles();
    for (int i = 0; i < n; ++i) {
      float x, y, vx, vy, px, py, radius, speed, range, horizon, oh;
      int cap;
      std::cin >> x >> y >> vx >> vy >> px >> py >> radius >> speed >> range >> cap >> horizon >> oh;
      sim.addAgent(RVO::Vector2(x,y), range, cap, horizon, oh, radius, speed, RVO::Vector2(vx,vy));
      sim.setAgentPrefVelocity(i, RVO::Vector2(px,py));
    }
    for (int s = 0; s < steps; ++s) {
      sim.doStep();
      for (int i = 0; i < n; ++i) {
        const auto p = sim.getAgentPosition(i);
        const auto v = sim.getAgentVelocity(i);
        std::cout << c << ' ' << s << ' ' << i << ' ' << p.x() << ' ' << p.y() << ' ' << v.x() << ' ' << v.y() << '\n';
      }
    }
  }
  return !std::cin;
}
