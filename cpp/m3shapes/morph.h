#pragma once

#include "m3shapes/cubic.h"
#include "m3shapes/rounded_polygon.h"
#include <utility>
#include <vector>

namespace m3shapes {

class Morph
{
public:
    Morph() = default;
    Morph(const RoundedPolygon &start, const RoundedPolygon &end);

    const std::vector<std::pair<Cubic, Cubic>> &morphMatch() const { return m_morphMatch; }

    std::vector<Cubic> asCubics(float progress) const;
    std::array<float, 4> calculateBounds(bool approximate = true) const;
    std::array<float, 4> calculateMaxBounds() const;

private:
    static std::vector<std::pair<Cubic, Cubic>> match(const RoundedPolygon &p1, const RoundedPolygon &p2);

    RoundedPolygon m_start;
    RoundedPolygon m_end;
    std::vector<std::pair<Cubic, Cubic>> m_morphMatch;
};

} // namespace m3shapes
