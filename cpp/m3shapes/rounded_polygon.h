#pragma once

#include "m3shapes/corner_rounding.h"
#include "m3shapes/cubic.h"
#include "m3shapes/feature.h"
#include <array>
#include <vector>

namespace m3shapes {

class RoundedPolygon
{
public:
    RoundedPolygon() = default;
    RoundedPolygon(std::vector<Feature> features, QPointF center);

    RoundedPolygon(const std::vector<float> &vertices,
                   CornerRounding rounding = CornerRounding::Unrounded,
                   const std::vector<CornerRounding> &perVertexRounding = {},
                   float centerX = std::numeric_limits<float>::min(),
                   float centerY = std::numeric_limits<float>::min());

    RoundedPolygon(int numVertices,
                   float radius = 1.0f,
                   float centerX = 0.0f,
                   float centerY = 0.0f,
                   CornerRounding rounding = CornerRounding::Unrounded,
                   const std::vector<CornerRounding> &perVertexRounding = {});

    const std::vector<Feature> &features() const { return m_features; }
    const std::vector<Cubic> &cubics() const { return m_cubics; }
    float centerX() const { return static_cast<float>(m_center.x()); }
    float centerY() const { return static_cast<float>(m_center.y()); }
    QPointF center() const { return m_center; }

    RoundedPolygon transformed(const PointTransformer &f) const;
    RoundedPolygon normalized() const;

    std::array<float, 4> calculateBounds(bool approximate = true) const;
    std::array<float, 4> calculateMaxBounds() const;

    static RoundedPolygon circle(int numVertices = 8,
                                 float radius = 1.0f,
                                 float centerX = 0.0f,
                                 float centerY = 0.0f);

    static RoundedPolygon rectangle(float width = 2.0f,
                                    float height = 2.0f,
                                    CornerRounding rounding = CornerRounding::Unrounded,
                                    const std::vector<CornerRounding> &perVertexRounding = {},
                                    float centerX = 0.0f,
                                    float centerY = 0.0f);

    static RoundedPolygon star(int numVerticesPerRadius,
                               float radius = 1.0f,
                               float innerRadius = 0.5f,
                               CornerRounding rounding = CornerRounding::Unrounded,
                               CornerRounding innerRounding = CornerRounding(-1.0f, 0.0f),
                               const std::vector<CornerRounding> &perVertexRounding = {},
                               float centerX = 0.0f,
                               float centerY = 0.0f,
                               float startAngle = 0.0f);

    static RoundedPolygon pill(float width = 2.0f,
                               float height = 1.0f,
                               float smoothing = 0.0f,
                               float centerX = 0.0f,
                               float centerY = 0.0f);

    static RoundedPolygon pillStar(float width = 2.0f,
                                   float height = 1.0f,
                                   int numVerticesPerRadius = 8,
                                   float innerRadiusRatio = 0.5f,
                                   CornerRounding rounding = CornerRounding::Unrounded,
                                   CornerRounding innerRounding = CornerRounding(-1.0f, 0.0f),
                                   const std::vector<CornerRounding> &perVertexRounding = {},
                                   float vertexSpacing = 0.5f,
                                   float startLocation = 0.0f,
                                   float centerX = 0.0f,
                                   float centerY = 0.0f);

private:
    void initCubics();

    std::vector<Feature> m_features;
    std::vector<Cubic> m_cubics;
    QPointF m_center{0.0, 0.0};
};

} // namespace m3shapes
