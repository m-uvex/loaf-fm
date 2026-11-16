#include "m3shapes/float_mapping.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace m3shapes {

namespace {

constexpr int kApproximationSamples = 8;

float measureCubicLength(const Cubic &c)
{
    QPointF prev(c.anchor0X(), c.anchor0Y());
    float total = 0.0f;
    for (int i = 1; i <= kApproximationSamples; ++i) {
        const float t = static_cast<float>(i) / static_cast<float>(kApproximationSamples);
        const QPointF pt = c.pointOnCurve(t);
        total += detail::distance(static_cast<float>(pt.x() - prev.x()),
                                  static_cast<float>(pt.y() - prev.y()));
        prev = pt;
    }
    return total;
}

float progressInRange(float progress, float progressFrom, float progressTo)
{
    if (progressTo >= progressFrom) {
        return progress >= progressFrom && progress <= progressTo;
    }
    return progress >= progressFrom || progress <= progressTo;
}

float linearMap(const std::vector<float> &xValues, const std::vector<float> &yValues, float x)
{
    if (xValues.empty())
        return x;
    const size_t n = xValues.size();
    size_t segmentStartIndex = 0;
    for (size_t i = 0; i < n; ++i) {
        if (progressInRange(x, xValues[i], xValues[(i + 1) % n])) {
            segmentStartIndex = i;
            break;
        }
    }
    const size_t segmentEndIndex = (segmentStartIndex + 1) % n;
    const float segmentSizeX = detail::positiveModulo(xValues[segmentEndIndex] - xValues[segmentStartIndex], 1.0f);
    const float segmentSizeY = detail::positiveModulo(yValues[segmentEndIndex] - yValues[segmentStartIndex], 1.0f);
    const float positionInSegment = segmentSizeX < 0.001f
        ? 0.5f
        : detail::positiveModulo(x - xValues[segmentStartIndex], 1.0f) / segmentSizeX;
    return detail::positiveModulo(yValues[segmentStartIndex] + segmentSizeY * positionInSegment, 1.0f);
}

QPointF featureRepresentativePoint(const Feature &feature)
{
    if (feature.cubics().empty())
        return QPointF(0.0, 0.0);
    const float x = (feature.cubics().front().anchor0X() + feature.cubics().back().anchor1X()) / 2.0f;
    const float y = (feature.cubics().front().anchor0Y() + feature.cubics().back().anchor1Y()) / 2.0f;
    return QPointF(x, y);
}

float featureDistSquared(const Feature &f1, const Feature &f2)
{
    if (f1.isCorner() && f2.isCorner() && f1.convex() != f2.convex()) {
        return std::numeric_limits<float>::max();
    }
    const QPointF p1 = featureRepresentativePoint(f1);
    const QPointF p2 = featureRepresentativePoint(f2);
    return detail::distanceSquared(static_cast<float>(p1.x() - p2.x()),
                                   static_cast<float>(p1.y() - p2.y()));
}

float progressDistance(float p1, float p2)
{
    const float d = std::abs(p1 - p2);
    return std::min(d, 1.0f - d);
}

} // namespace

const DoubleMapper DoubleMapper::Identity{{{0.0f, 0.0f}, {0.5f, 0.5f}}};

DoubleMapper::DoubleMapper(const std::vector<std::pair<float, float>> &mappings)
{
    m_sourceValues.reserve(mappings.size());
    m_targetValues.reserve(mappings.size());
    for (const auto &[src, tgt] : mappings) {
        m_sourceValues.push_back(src);
        m_targetValues.push_back(tgt);
    }
}

float DoubleMapper::map(float x) const
{
    return linearMap(m_sourceValues, m_targetValues, x);
}

float DoubleMapper::mapBack(float x) const
{
    return linearMap(m_targetValues, m_sourceValues, x);
}

std::pair<MeasuredPolygon::MeasuredCubic, MeasuredPolygon::MeasuredCubic>
MeasuredPolygon::MeasuredCubic::cutAtProgress(float cutOutlineProgress) const
{
    const float boundedCut = std::clamp(cutOutlineProgress, startOutlineProgress, endOutlineProgress);
    const float outlineProgressSize = endOutlineProgress - startOutlineProgress;
    const float relativeProgress = outlineProgressSize > detail::kDistanceEpsilon
        ? (boundedCut - startOutlineProgress) / outlineProgressSize
        : 0.0f;

    const auto [c1, c2] = cubic.split(std::clamp(relativeProgress, 0.0f, 1.0f));
    return {
        MeasuredCubic{c1, startOutlineProgress, boundedCut, measuredSize * relativeProgress},
        MeasuredCubic{c2, boundedCut, endOutlineProgress, measuredSize * (1.0f - relativeProgress)}
    };
}

MeasuredPolygon MeasuredPolygon::measurePolygon(const RoundedPolygon &polygon)
{
    std::vector<Cubic> cubics;
    std::vector<std::pair<Feature, size_t>> featureToCubic;

    for (const Feature &feature : polygon.features()) {
        for (size_t cIdx = 0; cIdx < feature.cubics().size(); ++cIdx) {
            if (feature.isCorner() && cIdx == feature.cubics().size() / 2) {
                featureToCubic.emplace_back(feature, cubics.size());
            }
            cubics.push_back(feature.cubics()[cIdx]);
        }
    }

    std::vector<float> measures(cubics.size() + 1, 0.0f);
    float totalMeasure = 0.0f;
    for (size_t i = 0; i < cubics.size(); ++i) {
        const float len = measureCubicLength(cubics[i]);
        totalMeasure += len;
        measures[i + 1] = totalMeasure;
    }
    const float outlineLength = std::max(totalMeasure, detail::kDistanceEpsilon);

    std::vector<float> outlineProgress(measures.size());
    for (size_t i = 0; i < measures.size(); ++i) {
        outlineProgress[i] = measures[i] / outlineLength;
    }

    std::vector<ProgressableFeature> features;
    features.reserve(featureToCubic.size());
    for (const auto &[feature, ix] : featureToCubic) {
        const float p = detail::positiveModulo((outlineProgress[ix] + outlineProgress[ix + 1]) / 2.0f, 1.0f);
        features.push_back(ProgressableFeature{p, feature});
    }

    std::vector<MeasuredCubic> measuredCubics;
    float startOutlineProgress = 0.0f;
    for (size_t i = 0; i < cubics.size(); ++i) {
        if ((outlineProgress[i + 1] - outlineProgress[i]) > detail::kDistanceEpsilon) {
            measuredCubics.push_back(MeasuredCubic{
                cubics[i],
                startOutlineProgress,
                outlineProgress[i + 1],
                measures[i + 1] - measures[i]
            });
            startOutlineProgress = outlineProgress[i + 1];
        }
    }
    if (!measuredCubics.empty()) {
        measuredCubics.back().endOutlineProgress = 1.0f;
    } else if (!cubics.empty()) {
        measuredCubics.push_back(MeasuredCubic{cubics.front(), 0.0f, 1.0f, 1.0f});
    }

    return MeasuredPolygon(std::move(features), std::move(measuredCubics));
}

MeasuredPolygon MeasuredPolygon::cutAndShift(float cuttingPoint) const
{
    if (cuttingPoint < detail::kDistanceEpsilon || m_cubics.empty())
        return *this;

    size_t targetIndex = 0;
    for (size_t i = 0; i < m_cubics.size(); ++i) {
        if (cuttingPoint >= m_cubics[i].startOutlineProgress && cuttingPoint <= m_cubics[i].endOutlineProgress) {
            targetIndex = i;
            break;
        }
    }

    const auto [b1, b2] = m_cubics[targetIndex].cutAtProgress(cuttingPoint);

    std::vector<Cubic> retCubics;
    retCubics.reserve(m_cubics.size() + 1);
    retCubics.push_back(b2.cubic);
    for (size_t i = 1; i < m_cubics.size(); ++i) {
        retCubics.push_back(m_cubics[(i + targetIndex) % m_cubics.size()].cubic);
    }
    retCubics.push_back(b1.cubic);

    std::vector<float> retOutlineProgress(m_cubics.size() + 2, 0.0f);
    for (size_t i = 0; i < m_cubics.size() + 2; ++i) {
        if (i == 0) {
            retOutlineProgress[i] = 0.0f;
        } else if (i < m_cubics.size() + 1) {
            const size_t cubicIndex = (targetIndex + i - 1) % m_cubics.size();
            retOutlineProgress[i] = detail::positiveModulo(m_cubics[cubicIndex].endOutlineProgress - cuttingPoint, 1.0f);
        } else {
            retOutlineProgress[i] = 1.0f;
        }
    }

    std::vector<ProgressableFeature> shiftedFeatures;
    shiftedFeatures.reserve(m_features.size());
    for (const ProgressableFeature &pf : m_features) {
        shiftedFeatures.push_back(ProgressableFeature{
            detail::positiveModulo(pf.progress - cuttingPoint, 1.0f),
            pf.feature
        });
    }

    std::vector<MeasuredCubic> newMeasured;
    float startOutlineProgress = 0.0f;
    for (size_t i = 0; i < retCubics.size(); ++i) {
        if ((retOutlineProgress[i + 1] - retOutlineProgress[i]) > detail::kDistanceEpsilon) {
            newMeasured.push_back(MeasuredCubic{
                retCubics[i],
                startOutlineProgress,
                retOutlineProgress[i + 1],
                retOutlineProgress[i + 1] - startOutlineProgress
            });
            startOutlineProgress = retOutlineProgress[i + 1];
        }
    }
    if (!newMeasured.empty())
        newMeasured.back().endOutlineProgress = 1.0f;

    return MeasuredPolygon(std::move(shiftedFeatures), std::move(newMeasured));
}

DoubleMapper featureMapper(const std::vector<ProgressableFeature> &features1,
                           const std::vector<ProgressableFeature> &features2)
{
    std::vector<ProgressableFeature> f1;
    for (const auto &pf : features1) {
        if (pf.feature.isCorner())
            f1.push_back(pf);
    }
    std::vector<ProgressableFeature> f2;
    for (const auto &pf : features2) {
        if (pf.feature.isCorner())
            f2.push_back(pf);
    }

    if (f1.empty() || f2.empty())
        return DoubleMapper::Identity;

    struct DistanceVertex
    {
        float distance;
        size_t i1;
        size_t i2;
    };

    std::vector<DistanceVertex> candidates;
    for (size_t i = 0; i < f1.size(); ++i) {
        for (size_t j = 0; j < f2.size(); ++j) {
            const float d = featureDistSquared(f1[i].feature, f2[j].feature);
            if (d < std::numeric_limits<float>::max()) {
                candidates.push_back(DistanceVertex{d, i, j});
            }
        }
    }
    std::sort(candidates.begin(), candidates.end(), [](const DistanceVertex &a, const DistanceVertex &b) {
        return a.distance < b.distance;
    });

    if (candidates.empty())
        return DoubleMapper::Identity;

    if (candidates.size() == 1) {
        const float p1 = f1[candidates[0].i1].progress;
        const float p2 = f2[candidates[0].i2].progress;
        return DoubleMapper({{p1, p2}, {detail::positiveModulo(p1 + 0.5f, 1.0f), detail::positiveModulo(p2 + 0.5f, 1.0f)}});
    }

    std::vector<std::pair<float, float>> mapping;
    auto canInsert = [&](float p1, float p2) -> bool {
        if (mapping.empty())
            return true;
        for (const auto &[m1, m2] : mapping) {
            if (progressDistance(p1, m1) < detail::kDistanceEpsilon
                || progressDistance(p2, m2) < detail::kDistanceEpsilon) {
                return false;
            }
        }
        if (mapping.size() == 1)
            return true;

        const size_t n = mapping.size();
        size_t beforeIdx = 0;
        for (size_t i = 0; i < n; ++i) {
            if (progressInRange(p1, mapping[i].first, mapping[(i + 1) % n].first)) {
                beforeIdx = i;
                break;
            }
        }
        const size_t afterIdx = (beforeIdx + 1) % n;
        return progressInRange(p2, mapping[beforeIdx].second, mapping[afterIdx].second);
    };

    for (const DistanceVertex &cand : candidates) {
        const float p1 = f1[cand.i1].progress;
        const float p2 = f2[cand.i2].progress;
        if (canInsert(p1, p2)) {
            mapping.emplace_back(p1, p2);
            std::sort(mapping.begin(), mapping.end(), [](const auto &a, const auto &b) {
                return a.first < b.first;
            });
        }
    }

    if (mapping.size() == 1) {
        const auto [p1, p2] = mapping[0];
        return DoubleMapper({{p1, p2}, {detail::positiveModulo(p1 + 0.5f, 1.0f), detail::positiveModulo(p2 + 0.5f, 1.0f)}});
    }
    return DoubleMapper(mapping);
}

} // namespace m3shapes
