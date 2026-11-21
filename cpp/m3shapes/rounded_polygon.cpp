#include "m3shapes/rounded_polygon.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace m3shapes {

namespace {

struct RoundedCorner
{
    QPointF p0;
    QPointF p1;
    QPointF p2;
    CornerRounding rounding;
    QPointF d1;
    QPointF d2;
    float cornerRadius = 0.0f;
    float smoothing = 0.0f;
    float cosAngle = 0.0f;
    float sinAngle = 0.0f;
    float expectedRoundCut = 0.0f;
    QPointF center{0.0, 0.0};

    RoundedCorner(QPointF pt0, QPointF pt1, QPointF pt2, CornerRounding rnd)
        : p0(pt0), p1(pt1), p2(pt2), rounding(rnd)
    {
        const QPointF v01 = p0 - p1;
        const QPointF v21 = p2 - p1;
        const float d01 = detail::distance(static_cast<float>(v01.x()), static_cast<float>(v01.y()));
        const float d21 = detail::distance(static_cast<float>(v21.x()), static_cast<float>(v21.y()));
        if (d01 > 0.0f && d21 > 0.0f) {
            d1 = v01 / d01;
            d2 = v21 / d21;
            cornerRadius = rounding.radius;
            smoothing = rounding.smoothing;
            cosAngle = static_cast<float>(d1.x() * d2.x() + d1.y() * d2.y());
            sinAngle = std::sqrt(std::max(0.0f, 1.0f - cosAngle * cosAngle));
            expectedRoundCut = sinAngle > 1e-3f ? cornerRadius * (cosAngle + 1.0f) / sinAngle : 0.0f;
        }
    }

    float expectedCut() const
    {
        return (1.0f + smoothing) * expectedRoundCut;
    }

    std::vector<Cubic> getCubics(float allowedCut0, float allowedCut1)
    {
        const float allowedCut = std::min(allowedCut0, allowedCut1);
        if (expectedRoundCut < detail::kDistanceEpsilon
            || allowedCut < detail::kDistanceEpsilon
            || cornerRadius < detail::kDistanceEpsilon) {
            center = p1;
            return {Cubic::straightLine(static_cast<float>(p1.x()), static_cast<float>(p1.y()),
                                        static_cast<float>(p1.x()), static_cast<float>(p1.y()))};
        }

        const float actualRoundCut = std::min(allowedCut, expectedRoundCut);
        const float actualSmoothing0 = calculateActualSmoothingValue(allowedCut0);
        const float actualSmoothing1 = calculateActualSmoothingValue(allowedCut1);
        const float actualRadius = cornerRadius * actualRoundCut / expectedRoundCut;
        const float centerDistance = std::hypot(actualRadius, actualRoundCut);

        const QPointF halfDir = detail::directionVector(
            static_cast<float>((d1.x() + d2.x()) / 2.0),
            static_cast<float>((d1.y() + d2.y()) / 2.0));
        center = p1 + halfDir * centerDistance;

        const QPointF circleIntersection0 = p1 + d1 * actualRoundCut;
        const QPointF circleIntersection2 = p1 + d2 * actualRoundCut;

        const Cubic flanking0 = computeFlankingCurve(
            actualRoundCut, actualSmoothing0, p1, p0,
            circleIntersection0, circleIntersection2, center, actualRadius);
        const Cubic flanking2 = computeFlankingCurve(
            actualRoundCut, actualSmoothing1, p1, p2,
            circleIntersection2, circleIntersection0, center, actualRadius).reverse();

        return {
            flanking0,
            Cubic::circularArc(static_cast<float>(center.x()), static_cast<float>(center.y()),
                               flanking0.anchor1X(), flanking0.anchor1Y(),
                               flanking2.anchor0X(), flanking2.anchor0Y()),
            flanking2
        };
    }

private:
    float calculateActualSmoothingValue(float allowedCut) const
    {
        if (allowedCut > expectedCut())
            return smoothing;
        if (allowedCut > expectedRoundCut)
            return smoothing * (allowedCut - expectedRoundCut) / (expectedCut() - expectedRoundCut);
        return 0.0f;
    }

    static QPointF lineIntersection(QPointF p0, QPointF d0, QPointF p1, QPointF d1)
    {
        const QPointF rotatedD1(-d1.y(), d1.x());
        const float den = static_cast<float>(d0.x() * rotatedD1.x() + d0.y() * rotatedD1.y());
        if (std::abs(den) < detail::kAngleEpsilon)
            return p1;
        const QPointF diff = p1 - p0;
        const float num = static_cast<float>(diff.x() * rotatedD1.x() + diff.y() * rotatedD1.y());
        const float k = num / den;
        return p0 + d0 * k;
    }

    static Cubic computeFlankingCurve(
        float actualRoundCut,
        float actualSmoothingValues,
        QPointF corner,
        QPointF sideStart,
        QPointF circleSegmentIntersection,
        QPointF otherCircleSegmentIntersection,
        QPointF circleCenter,
        float actualRadius)
    {
        const QPointF sideVector = sideStart - corner;
        const QPointF sideDirection = detail::directionVector(
            static_cast<float>(sideVector.x()), static_cast<float>(sideVector.y()));
        const QPointF curveStart = corner + sideDirection * actualRoundCut * (1.0f + actualSmoothingValues);

        const QPointF p = detail::interpolatePoint(
            circleSegmentIntersection,
            (circleSegmentIntersection + otherCircleSegmentIntersection) / 2.0,
            actualSmoothingValues);
        const QPointF pDir = detail::directionVector(
            static_cast<float>(p.x() - circleCenter.x()),
            static_cast<float>(p.y() - circleCenter.y()));
        const QPointF curveEnd = circleCenter + pDir * actualRadius;

        const QPointF circleTangent(-(curveEnd - circleCenter).y(), (curveEnd - circleCenter).x());
        const QPointF anchorEnd = lineIntersection(sideStart, sideDirection, curveEnd, circleTangent);
        const QPointF anchorStart = (curveStart + anchorEnd * 2.0) / 3.0;

        return Cubic(curveStart, anchorStart, anchorEnd, curveEnd);
    }
};

QPointF calculateCenterFromVertices(const std::vector<float> &vertices)
{
    if (vertices.empty())
        return QPointF(0.0, 0.0);
    float cumulativeX = 0.0f;
    float cumulativeY = 0.0f;
    for (size_t i = 0; i + 1 < vertices.size(); i += 2) {
        cumulativeX += vertices[i];
        cumulativeY += vertices[i + 1];
    }
    const float count = static_cast<float>(vertices.size() / 2);
    return QPointF(cumulativeX / count, cumulativeY / count);
}

std::vector<float> verticesFromNumVerts(int numVertices, float radius, float centerX, float centerY)
{
    std::vector<float> result(static_cast<size_t>(numVertices) * 2);
    size_t idx = 0;
    for (int i = 0; i < numVertices; ++i) {
        const float angle = detail::kFloatPi / static_cast<float>(numVertices) * 2.0f * static_cast<float>(i);
        const QPointF vertex = detail::radialToCartesian(radius, angle, QPointF(centerX, centerY));
        result[idx++] = static_cast<float>(vertex.x());
        result[idx++] = static_cast<float>(vertex.y());
    }
    return result;
}

std::vector<float> starVerticesFromNumVerts(
    int numVerticesPerRadius, float radius, float innerRadius,
    float centerX, float centerY, float startAngle = 0.0f)
{
    std::vector<float> result(static_cast<size_t>(numVerticesPerRadius) * 4);
    size_t idx = 0;
    for (int i = 0; i < numVerticesPerRadius; ++i) {
        float angle = startAngle + detail::kFloatPi / static_cast<float>(numVerticesPerRadius) * (2 * i);
        QPointF v = detail::radialToCartesian(radius, angle, QPointF(centerX, centerY));
        result[idx++] = static_cast<float>(v.x());
        result[idx++] = static_cast<float>(v.y());

        angle = startAngle + detail::kFloatPi / static_cast<float>(numVerticesPerRadius) * (2 * i + 1);
        v = detail::radialToCartesian(innerRadius, angle, QPointF(centerX, centerY));
        result[idx++] = static_cast<float>(v.x());
        result[idx++] = static_cast<float>(v.y());
    }
    return result;
}

} // namespace

RoundedPolygon::RoundedPolygon(std::vector<Feature> features, QPointF center)
    : m_features(std::move(features)), m_center(center)
{
    initCubics();
}

RoundedPolygon::RoundedPolygon(const std::vector<float> &vertices,
                               CornerRounding rounding,
                               const std::vector<CornerRounding> &perVertexRounding,
                               float centerX,
                               float centerY)
{
    const size_t n = vertices.size() / 2;
    if (n < 3)
        return;

    if (centerX == std::numeric_limits<float>::min() || centerY == std::numeric_limits<float>::min()) {
        m_center = calculateCenterFromVertices(vertices);
    } else {
        m_center = QPointF(centerX, centerY);
    }

    std::vector<RoundedCorner> corners;
    corners.reserve(n);
    for (size_t i = 0; i < n; ++i) {
        const CornerRounding vtxRounding = (i < perVertexRounding.size()) ? perVertexRounding[i] : rounding;
        const size_t prevIndex = ((i + n - 1) % n) * 2;
        const size_t nextIndex = ((i + 1) % n) * 2;
        corners.emplace_back(
            QPointF(vertices[prevIndex], vertices[prevIndex + 1]),
            QPointF(vertices[i * 2], vertices[i * 2 + 1]),
            QPointF(vertices[nextIndex], vertices[nextIndex + 1]),
            vtxRounding
        );
    }

    std::vector<std::pair<float, float>> cutAdjusts(n);
    for (size_t i = 0; i < n; ++i) {
        const size_t nextIdx = (i + 1) % n;
        const float expectedRoundCut = corners[i].expectedRoundCut + corners[nextIdx].expectedRoundCut;
        const float expectedTotalCut = corners[i].expectedCut() + corners[nextIdx].expectedCut();
        const float vtxX = vertices[i * 2];
        const float vtxY = vertices[i * 2 + 1];
        const float nextVtxX = vertices[nextIdx * 2];
        const float nextVtxY = vertices[nextIdx * 2 + 1];
        const float sideSize = detail::distance(vtxX - nextVtxX, vtxY - nextVtxY);

        if (expectedRoundCut > sideSize && expectedRoundCut > 0.0f) {
            cutAdjusts[i] = {sideSize / expectedRoundCut, 0.0f};
        } else if (expectedTotalCut > sideSize && (expectedTotalCut - expectedRoundCut) > 0.0f) {
            cutAdjusts[i] = {1.0f, (sideSize - expectedRoundCut) / (expectedTotalCut - expectedRoundCut)};
        } else {
            cutAdjusts[i] = {1.0f, 1.0f};
        }
    }

    std::vector<std::vector<Cubic>> cornerCubics(n);
    for (size_t i = 0; i < n; ++i) {
        std::array<float, 2> allowedCuts{0.0f, 0.0f};
        for (size_t delta = 0; delta < 2; ++delta) {
            const auto [roundCutRatio, cutRatio] = cutAdjusts[(i + n - 1 + delta) % n];
            allowedCuts[delta] = corners[i].expectedRoundCut * roundCutRatio
                               + (corners[i].expectedCut() - corners[i].expectedRoundCut) * cutRatio;
        }
        cornerCubics[i] = corners[i].getCubics(allowedCuts[0], allowedCuts[1]);
    }

    m_features.reserve(n * 2);
    for (size_t i = 0; i < n; ++i) {
        const size_t prevIndex = (i + n - 1) % n;
        const size_t nextIndex = (i + 1) % n;
        const QPointF currVertex(vertices[i * 2], vertices[i * 2 + 1]);
        const QPointF prevVertex(vertices[prevIndex * 2], vertices[prevIndex * 2 + 1]);
        const QPointF nextVertex(vertices[nextIndex * 2], vertices[nextIndex * 2 + 1]);
        const bool isConvex = detail::convex(prevVertex, currVertex, nextVertex);

        m_features.push_back(Feature(Feature::Type::Corner, cornerCubics[i], isConvex));
        m_features.push_back(Feature::buildEdge(Cubic::straightLine(
            cornerCubics[i].back().anchor1X(),
            cornerCubics[i].back().anchor1Y(),
            cornerCubics[nextIndex].front().anchor0X(),
            cornerCubics[nextIndex].front().anchor0Y()
        )));
    }

    initCubics();
}

RoundedPolygon::RoundedPolygon(int numVertices,
                               float radius,
                               float centerX,
                               float centerY,
                               CornerRounding rounding,
                               const std::vector<CornerRounding> &perVertexRounding)
    : RoundedPolygon(verticesFromNumVerts(numVertices, radius, centerX, centerY),
                     rounding, perVertexRounding, centerX, centerY)
{
}

void RoundedPolygon::initCubics()
{
    m_cubics.clear();
    const Cubic *firstCubic = nullptr;
    const Cubic *lastCubic = nullptr;
    std::vector<Cubic> firstFeatureSplitStart;
    std::vector<Cubic> firstFeatureSplitEnd;

    if (!m_features.empty() && m_features[0].cubics().size() == 3) {
        const Cubic &centerCubic = m_features[0].cubics()[1];
        const auto [start, end] = centerCubic.split(0.5f);
        firstFeatureSplitStart = {m_features[0].cubics()[0], start};
        firstFeatureSplitEnd = {end, m_features[0].cubics()[2]};
    }

    const size_t featureSize = m_features.size();
    for (size_t i = 0; i <= featureSize; ++i) {
        const std::vector<Cubic> *featureCubics = nullptr;
        if (i == 0 && !firstFeatureSplitEnd.empty()) {
            featureCubics = &firstFeatureSplitEnd;
        } else if (i == featureSize) {
            if (!firstFeatureSplitStart.empty()) {
                featureCubics = &firstFeatureSplitStart;
            } else {
                break;
            }
        } else {
            featureCubics = &m_features[i].cubics();
        }

        for (const Cubic &cubic : *featureCubics) {
            if (!cubic.zeroLength()) {
                if (lastCubic)
                    m_cubics.push_back(*lastCubic);
                lastCubic = &cubic;
                if (!firstCubic)
                    firstCubic = &cubic;
            } else if (lastCubic) {
                Cubic adjusted = *lastCubic;
                adjusted = Cubic(adjusted.anchor0X(), adjusted.anchor0Y(),
                                 adjusted.control0X(), adjusted.control0Y(),
                                 adjusted.control1X(), adjusted.control1Y(),
                                 cubic.anchor1X(), cubic.anchor1Y());
                m_cubics.push_back(adjusted);
                lastCubic = nullptr;
            }
        }
    }

    if (lastCubic) {
        if (firstCubic) {
            m_cubics.emplace_back(
                lastCubic->anchor0X(), lastCubic->anchor0Y(),
                lastCubic->control0X(), lastCubic->control0Y(),
                lastCubic->control1X(), lastCubic->control1Y(),
                firstCubic->anchor0X(), firstCubic->anchor0Y()
            );
        } else {
            m_cubics.push_back(*lastCubic);
        }
    } else if (m_cubics.empty()) {
        m_cubics.push_back(Cubic::empty(centerX(), centerY()));
    }
}

RoundedPolygon RoundedPolygon::transformed(const PointTransformer &f) const
{
    const QPointF newCenter = f(centerX(), centerY());
    std::vector<Feature> newFeatures;
    newFeatures.reserve(m_features.size());
    for (const Feature &feat : m_features)
        newFeatures.push_back(feat.transformed(f));
    return RoundedPolygon(std::move(newFeatures), newCenter);
}

RoundedPolygon RoundedPolygon::normalized() const
{
    const std::array<float, 4> bounds = calculateBounds(false);
    const float width = bounds[2] - bounds[0];
    const float height = bounds[3] - bounds[1];
    const float side = std::max({width, height, detail::kDistanceEpsilon});
    const float offsetX = (side - width) / 2.0f - bounds[0];
    const float offsetY = (side - height) / 2.0f - bounds[1];
    return transformed([=](float x, float y) {
        return QPointF((x + offsetX) / side, (y + offsetY) / side);
    });
}

std::array<float, 4> RoundedPolygon::calculateBounds(bool approximate) const
{
    if (m_cubics.empty())
        return {0.f, 0.f, 0.f, 0.f};

    float minX = std::numeric_limits<float>::max();
    float minY = std::numeric_limits<float>::max();
    float maxX = std::numeric_limits<float>::lowest();
    float maxY = std::numeric_limits<float>::lowest();
    std::array<float, 4> cBounds{};

    for (const Cubic &cubic : m_cubics) {
        cubic.calculateBounds(cBounds, approximate);
        minX = std::min(minX, cBounds[0]);
        minY = std::min(minY, cBounds[1]);
        maxX = std::max(maxX, cBounds[2]);
        maxY = std::max(maxY, cBounds[3]);
    }
    return {minX, minY, maxX, maxY};
}

std::array<float, 4> RoundedPolygon::calculateMaxBounds() const
{
    float maxDistSq = 0.0f;
    for (const Cubic &cubic : m_cubics) {
        const float anchorDist = detail::distanceSquared(cubic.anchor0X() - centerX(),
                                                         cubic.anchor0Y() - centerY());
        const QPointF mid = cubic.pointOnCurve(0.5f);
        const float midDist = detail::distanceSquared(static_cast<float>(mid.x()) - centerX(),
                                                      static_cast<float>(mid.y()) - centerY());
        maxDistSq = std::max({maxDistSq, anchorDist, midDist});
    }
    const float d = std::sqrt(maxDistSq);
    return {centerX() - d, centerY() - d, centerX() + d, centerY() + d};
}

RoundedPolygon RoundedPolygon::circle(int numVertices, float radius, float centerX, float centerY)
{
    const float theta = detail::kFloatPi / static_cast<float>(numVertices);
    const float polygonRadius = radius / std::cos(theta);
    return RoundedPolygon(numVertices, polygonRadius, centerX, centerY, CornerRounding(radius, 0.0f));
}

RoundedPolygon RoundedPolygon::rectangle(float width, float height,
                                         CornerRounding rounding,
                                         const std::vector<CornerRounding> &perVertexRounding,
                                         float centerX, float centerY)
{
    const float left = centerX - width / 2.0f;
    const float top = centerY - height / 2.0f;
    const float right = centerX + width / 2.0f;
    const float bottom = centerY + height / 2.0f;
    return RoundedPolygon(
        {right, bottom, left, bottom, left, top, right, top},
        rounding, perVertexRounding, centerX, centerY
    );
}

RoundedPolygon RoundedPolygon::star(int numVerticesPerRadius,
                                    float radius,
                                    float innerRadius,
                                    CornerRounding rounding,
                                    CornerRounding innerRounding,
                                    const std::vector<CornerRounding> &perVertexRounding,
                                    float centerX,
                                    float centerY,
                                    float startAngle)
{
    std::vector<CornerRounding> pvRounding = perVertexRounding;
    if (pvRounding.empty() && innerRounding.radius >= 0.0f) {
        pvRounding.reserve(static_cast<size_t>(numVerticesPerRadius) * 2);
        for (int i = 0; i < numVerticesPerRadius; ++i) {
            pvRounding.push_back(rounding);
            pvRounding.push_back(innerRounding);
        }
    }
    return RoundedPolygon(
        starVerticesFromNumVerts(numVerticesPerRadius, radius, innerRadius, centerX, centerY, startAngle),
        rounding, pvRounding, centerX, centerY
    );
}

RoundedPolygon RoundedPolygon::pill(float width, float height, float smoothing, float centerX, float centerY)
{
    const float halfWidth = width / 2.0f;
    const float halfHeight = height / 2.0f;
    return RoundedPolygon(
        {
            halfWidth + centerX, halfHeight + centerY,
            -halfWidth + centerX, halfHeight + centerY,
            -halfWidth + centerX, -halfHeight + centerY,
            halfWidth + centerX, -halfHeight + centerY
        },
        CornerRounding(std::min(halfWidth, halfHeight), smoothing),
        {}, centerX, centerY
    );
}

RoundedPolygon RoundedPolygon::pillStar(float width,
                                        float height,
                                        int numVerticesPerRadius,
                                        float innerRadiusRatio,
                                        CornerRounding rounding,
                                        CornerRounding innerRounding,
                                        const std::vector<CornerRounding> &perVertexRounding,
                                        float vertexSpacing,
                                        float startLocation,
                                        float centerX,
                                        float centerY)
{
    std::vector<CornerRounding> pvRounding = perVertexRounding;
    if (pvRounding.empty() && innerRounding.radius >= 0.0f) {
        pvRounding.reserve(static_cast<size_t>(numVerticesPerRadius) * 2);
        for (int i = 0; i < numVerticesPerRadius; ++i) {
            pvRounding.push_back(rounding);
            pvRounding.push_back(innerRounding);
        }
    }

    const float endCapRadius = std::min(width, height);
    const float vSegLen = std::max(0.0f, height - width);
    const float hSegLen = std::max(0.0f, width - height);
    const float vSegHalf = vSegLen / 2.0f;
    const float hSegHalf = hSegLen / 2.0f;
    const float circlePerimeter = detail::kTwoPi * endCapRadius * detail::interpolateFloat(innerRadiusRatio, 1.0f, vertexSpacing);
    const float perimeter = 2.0f * hSegLen + 2.0f * vSegLen + circlePerimeter;

    std::array<float, 11> sections{};
    sections[0] = 0.0f;
    sections[1] = vSegHalf;
    sections[2] = sections[1] + circlePerimeter / 4.0f;
    sections[3] = sections[2] + hSegLen;
    sections[4] = sections[3] + circlePerimeter / 4.0f;
    sections[5] = sections[4] + vSegLen;
    sections[6] = sections[5] + circlePerimeter / 4.0f;
    sections[7] = sections[6] + hSegLen;
    sections[8] = sections[7] + circlePerimeter / 4.0f;
    sections[9] = sections[8] + vSegHalf;
    sections[10] = perimeter;

    const float tPerVertex = perimeter / static_cast<float>(2 * numVerticesPerRadius);
    bool inner = false;
    size_t currSecIndex = 0;
    float secStart = 0.0f;
    float secEnd = sections[1];
    float t = startLocation * perimeter;

    const std::array<QPointF, 4> rect{
        QPointF(hSegHalf, vSegHalf),
        QPointF(-hSegHalf, vSegHalf),
        QPointF(-hSegHalf, -vSegHalf),
        QPointF(hSegHalf, -vSegHalf)
    };

    std::vector<float> result(static_cast<size_t>(numVerticesPerRadius) * 4);
    size_t arrayIndex = 0;

    for (int i = 0; i < 2 * numVerticesPerRadius; ++i) {
        const float boundedT = std::fmod(t, perimeter);
        if (boundedT < secStart)
            currSecIndex = 0;
        while (boundedT >= sections[(currSecIndex + 1) % sections.size()]) {
            currSecIndex = (currSecIndex + 1) % sections.size();
            secStart = sections[currSecIndex];
            secEnd = sections[(currSecIndex + 1) % sections.size()];
        }

        const float tInSection = boundedT - secStart;
        const float tProportion = (secEnd - secStart) > 0.0f ? (tInSection / (secEnd - secStart)) : 0.0f;
        const float currRadius = inner ? (endCapRadius * innerRadiusRatio) : endCapRadius;

        QPointF vertex;
        switch (currSecIndex) {
        case 0:
            vertex = QPointF(currRadius, tProportion * vSegHalf);
            break;
        case 1:
            vertex = detail::radialToCartesian(currRadius, tProportion * detail::kFloatPi / 2.0f) + rect[0];
            break;
        case 2:
            vertex = QPointF(hSegHalf - tProportion * hSegLen, currRadius);
            break;
        case 3:
            vertex = detail::radialToCartesian(currRadius, detail::kFloatPi / 2.0f + (tProportion * detail::kFloatPi / 2.0f)) + rect[1];
            break;
        case 4:
            vertex = QPointF(-currRadius, vSegHalf - tProportion * vSegLen);
            break;
        case 5:
            vertex = detail::radialToCartesian(currRadius, detail::kFloatPi + (tProportion * detail::kFloatPi / 2.0f)) + rect[2];
            break;
        case 6:
            vertex = QPointF(-hSegHalf + tProportion * hSegLen, -currRadius);
            break;
        case 7:
            vertex = detail::radialToCartesian(currRadius, detail::kFloatPi * 1.5f + (tProportion * detail::kFloatPi / 2.0f)) + rect[3];
            break;
        default:
            vertex = QPointF(currRadius, -vSegHalf + tProportion * vSegHalf);
            break;
        }
        result[arrayIndex++] = static_cast<float>(vertex.x()) + centerX;
        result[arrayIndex++] = static_cast<float>(vertex.y()) + centerY;
        t += tPerVertex;
        inner = !inner;
    }

    return RoundedPolygon(result, rounding, pvRounding, centerX, centerY);
}

} // namespace m3shapes
