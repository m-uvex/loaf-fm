#include "m3shapes/morph.h"
#include "m3shapes/float_mapping.h"

#include <algorithm>

namespace m3shapes {

Morph::Morph(const RoundedPolygon &start, const RoundedPolygon &end)
    : m_start(start), m_end(end), m_morphMatch(match(start, end))
{
}

std::vector<Cubic> Morph::asCubics(float progress) const
{
    std::vector<Cubic> result;
    result.reserve(m_morphMatch.size());

    const Cubic *firstCubic = nullptr;
    const Cubic *lastCubic = nullptr;
    Cubic storageFirst;
    Cubic storageLast;

    for (const auto &[c1, c2] : m_morphMatch) {
        Cubic cubic = Cubic::interpolate(c1, c2, progress);
        if (!cubic.zeroLength()) {
            if (lastCubic)
                result.push_back(*lastCubic);
            storageLast = cubic;
            lastCubic = &storageLast;
            if (!firstCubic) {
                storageFirst = cubic;
                firstCubic = &storageFirst;
            }
        } else if (lastCubic) {
            storageLast = Cubic(
                lastCubic->anchor0X(), lastCubic->anchor0Y(),
                lastCubic->control0X(), lastCubic->control0Y(),
                lastCubic->control1X(), lastCubic->control1Y(),
                cubic.anchor1X(), cubic.anchor1Y()
            );
        }
    }

    if (lastCubic) {
        if (firstCubic) {
            result.emplace_back(
                lastCubic->anchor0X(), lastCubic->anchor0Y(),
                lastCubic->control0X(), lastCubic->control0Y(),
                lastCubic->control1X(), lastCubic->control1Y(),
                firstCubic->anchor0X(), firstCubic->anchor0Y()
            );
        } else {
            result.push_back(*lastCubic);
        }
    }

    return result;
}

std::array<float, 4> Morph::calculateBounds(bool approximate) const
{
    const auto sBounds = m_start.calculateBounds(approximate);
    const auto eBounds = m_end.calculateBounds(approximate);
    return {
        std::min(sBounds[0], eBounds[0]),
        std::min(sBounds[1], eBounds[1]),
        std::max(sBounds[2], eBounds[2]),
        std::max(sBounds[3], eBounds[3])
    };
}

std::array<float, 4> Morph::calculateMaxBounds() const
{
    const auto sBounds = m_start.calculateMaxBounds();
    const auto eBounds = m_end.calculateMaxBounds();
    return {
        std::min(sBounds[0], eBounds[0]),
        std::min(sBounds[1], eBounds[1]),
        std::max(sBounds[2], eBounds[2]),
        std::max(sBounds[3], eBounds[3])
    };
}

std::vector<std::pair<Cubic, Cubic>> Morph::match(const RoundedPolygon &p1, const RoundedPolygon &p2)
{
    const MeasuredPolygon measuredPolygon1 = MeasuredPolygon::measurePolygon(p1);
    const MeasuredPolygon measuredPolygon2 = MeasuredPolygon::measurePolygon(p2);

    const DoubleMapper doubleMapper = featureMapper(measuredPolygon1.features(), measuredPolygon2.features());
    const float polygon2CutPoint = doubleMapper.map(0.0f);

    const MeasuredPolygon bs1 = measuredPolygon1;
    const MeasuredPolygon bs2 = measuredPolygon2.cutAndShift(polygon2CutPoint);

    std::vector<std::pair<Cubic, Cubic>> ret;
    size_t i1 = 0;
    size_t i2 = 0;

    auto getOrNull = [](const std::vector<MeasuredPolygon::MeasuredCubic> &vec, size_t idx) -> const MeasuredPolygon::MeasuredCubic * {
        return idx < vec.size() ? &vec[idx] : nullptr;
    };

    std::optional<MeasuredPolygon::MeasuredCubic> b1Opt;
    std::optional<MeasuredPolygon::MeasuredCubic> b2Opt;
    if (const auto *p = getOrNull(bs1.cubics(), i1++))
        b1Opt = *p;
    if (const auto *p = getOrNull(bs2.cubics(), i2++))
        b2Opt = *p;

    while (b1Opt.has_value() && b2Opt.has_value()) {
        const MeasuredPolygon::MeasuredCubic b1 = *b1Opt;
        const MeasuredPolygon::MeasuredCubic b2 = *b2Opt;

        const float b1a = (i1 == bs1.cubics().size()) ? 1.0f : b1.endOutlineProgress;
        const float b2a = (i2 == bs2.cubics().size())
            ? 1.0f
            : doubleMapper.mapBack(detail::positiveModulo(b2.endOutlineProgress + polygon2CutPoint, 1.0f));

        const float minb = std::min(b1a, b2a);

        MeasuredPolygon::MeasuredCubic seg1;
        if (b1a > minb + detail::kAngleEpsilon) {
            const auto [c1, c2] = b1.cutAtProgress(minb);
            seg1 = c1;
            b1Opt = c2;
        } else {
            seg1 = b1;
            if (const auto *p = getOrNull(bs1.cubics(), i1++))
                b1Opt = *p;
            else
                b1Opt.reset();
        }

        MeasuredPolygon::MeasuredCubic seg2;
        if (b2a > minb + detail::kAngleEpsilon) {
            const float cut2 = detail::positiveModulo(doubleMapper.map(minb) - polygon2CutPoint, 1.0f);
            const auto [c1, c2] = b2.cutAtProgress(cut2);
            seg2 = c1;
            b2Opt = c2;
        } else {
            seg2 = b2;
            if (const auto *p = getOrNull(bs2.cubics(), i2++))
                b2Opt = *p;
            else
                b2Opt.reset();
        }

        ret.emplace_back(seg1.cubic, seg2.cubic);
    }

    return ret;
}

} // namespace m3shapes
