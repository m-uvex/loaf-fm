#pragma once

#include "m3shapes/cubic.h"
#include "m3shapes/feature.h"
#include "m3shapes/rounded_polygon.h"
#include <utility>
#include <vector>

namespace m3shapes {

class DoubleMapper
{
public:
    explicit DoubleMapper(const std::vector<std::pair<float, float>> &mappings);

    float map(float x) const;
    float mapBack(float x) const;

    static const DoubleMapper Identity;

private:
    std::vector<float> m_sourceValues;
    std::vector<float> m_targetValues;
};

class MeasuredPolygon
{
public:
    struct MeasuredCubic
    {
        Cubic cubic;
        float startOutlineProgress = 0.0f;
        float endOutlineProgress = 0.0f;
        float measuredSize = 0.0f;

        std::pair<MeasuredCubic, MeasuredCubic> cutAtProgress(float cutOutlineProgress) const;
    };

    const std::vector<ProgressableFeature> &features() const { return m_features; }
    const std::vector<MeasuredCubic> &cubics() const { return m_cubics; }

    MeasuredPolygon cutAndShift(float cuttingPoint) const;

    static MeasuredPolygon measurePolygon(const RoundedPolygon &polygon);

private:
    MeasuredPolygon(std::vector<ProgressableFeature> features, std::vector<MeasuredCubic> cubics)
        : m_features(std::move(features)), m_cubics(std::move(cubics))
    {
    }

    std::vector<ProgressableFeature> m_features;
    std::vector<MeasuredCubic> m_cubics;
};

DoubleMapper featureMapper(const std::vector<ProgressableFeature> &features1,
                           const std::vector<ProgressableFeature> &features2);

} // namespace m3shapes
