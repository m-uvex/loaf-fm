#include "m3shapes/cubic.h"

#include <algorithm>

namespace m3shapes {

Cubic::Cubic(float anchor0X, float anchor0Y,
             float control0X, float control0Y,
             float control1X, float control1Y,
             float anchor1X, float anchor1Y)
    : m_points{anchor0X, anchor0Y, control0X, control0Y, control1X, control1Y, anchor1X, anchor1Y}
{
}

Cubic::Cubic(QPointF anchor0, QPointF control0, QPointF control1, QPointF anchor1)
    : m_points{static_cast<float>(anchor0.x()), static_cast<float>(anchor0.y()),
               static_cast<float>(control0.x()), static_cast<float>(control0.y()),
               static_cast<float>(control1.x()), static_cast<float>(control1.y()),
               static_cast<float>(anchor1.x()), static_cast<float>(anchor1.y())}
{
}

QPointF Cubic::pointOnCurve(float t) const
{
    const float u = 1.0f - t;
    const float u2 = u * u;
    const float u3 = u2 * u;
    const float t2 = t * t;
    const float t3 = t2 * t;

    const float x = anchor0X() * u3
                  + control0X() * (3.0f * t * u2)
                  + control1X() * (3.0f * t2 * u)
                  + anchor1X() * t3;
    const float y = anchor0Y() * u3
                  + control0Y() * (3.0f * t * u2)
                  + control1Y() * (3.0f * t2 * u)
                  + anchor1Y() * t3;
    return QPointF(x, y);
}

bool Cubic::zeroLength() const
{
    return std::abs(anchor0X() - anchor1X()) < detail::kDistanceEpsilon
        && std::abs(anchor0Y() - anchor1Y()) < detail::kDistanceEpsilon;
}

std::pair<Cubic, Cubic> Cubic::split(float t) const
{
    const float u = 1.0f - t;
    const QPointF p = pointOnCurve(t);
    const float px = static_cast<float>(p.x());
    const float py = static_cast<float>(p.y());

    Cubic first(
        anchor0X(), anchor0Y(),
        anchor0X() * u + control0X() * t,
        anchor0Y() * u + control0Y() * t,
        anchor0X() * (u * u) + control0X() * (2.0f * u * t) + control1X() * (t * t),
        anchor0Y() * (u * u) + control0Y() * (2.0f * u * t) + control1Y() * (t * t),
        px, py
    );

    Cubic second(
        px, py,
        control0X() * (u * u) + control1X() * (2.0f * u * t) + anchor1X() * (t * t),
        control0Y() * (u * u) + control1Y() * (2.0f * u * t) + anchor1Y() * (t * t),
        control1X() * u + anchor1X() * t,
        control1Y() * u + anchor1Y() * t,
        anchor1X(), anchor1Y()
    );

    return {first, second};
}

Cubic Cubic::reverse() const
{
    return Cubic(anchor1X(), anchor1Y(),
                 control1X(), control1Y(),
                 control0X(), control0Y(),
                 anchor0X(), anchor0Y());
}

Cubic Cubic::transformed(const PointTransformer &f) const
{
    const QPointF p0 = f(anchor0X(), anchor0Y());
    const QPointF p1 = f(control0X(), control0Y());
    const QPointF p2 = f(control1X(), control1Y());
    const QPointF p3 = f(anchor1X(), anchor1Y());
    return Cubic(p0, p1, p2, p3);
}

void Cubic::calculateBounds(std::array<float, 4> &bounds, bool approximate) const
{
    if (zeroLength()) {
        bounds = {anchor0X(), anchor0Y(), anchor0X(), anchor0Y()};
        return;
    }

    float minX = std::min(anchor0X(), anchor1X());
    float minY = std::min(anchor0Y(), anchor1Y());
    float maxX = std::max(anchor0X(), anchor1X());
    float maxY = std::max(anchor0Y(), anchor1Y());

    if (approximate) {
        bounds = {
            std::min({minX, control0X(), control1X()}),
            std::min({minY, control0Y(), control1Y()}),
            std::max({maxX, control0X(), control1X()}),
            std::max({maxY, control0Y(), control1Y()})
        };
        return;
    }

    auto checkAxis = [&](float a0, float c0, float c1, float a1, float &lo, float &hi, bool isX) {
        const float qa = -a0 + 3.0f * c0 - 3.0f * c1 + a1;
        const float qb = 2.0f * a0 - 4.0f * c0 + 2.0f * c1;
        const float qc = -a0 + c0;

        auto eval = [&](float t) {
            if (t <= 0.0f || t >= 1.0f)
                return;
            const QPointF pt = pointOnCurve(t);
            const float v = static_cast<float>(isX ? pt.x() : pt.y());
            lo = std::min(lo, v);
            hi = std::max(hi, v);
        };

        if (std::abs(qa) < detail::kDistanceEpsilon) {
            if (std::abs(qb) >= detail::kDistanceEpsilon) {
                eval(-qc / qb);
            }
            return;
        }

        const float discriminant = qb * qb - 4.0f * qa * qc;
        if (discriminant < 0.0f)
            return;
        const float sqrtDisc = std::sqrt(discriminant);
        eval((-qb + sqrtDisc) / (2.0f * qa));
        eval((-qb - sqrtDisc) / (2.0f * qa));
    };

    checkAxis(anchor0X(), control0X(), control1X(), anchor1X(), minX, maxX, true);
    checkAxis(anchor0Y(), control0Y(), control1Y(), anchor1Y(), minY, maxY, false);

    bounds = {minX, minY, maxX, maxY};
}

Cubic Cubic::operator+(const Cubic &other) const
{
    Cubic result;
    for (size_t i = 0; i < 8; ++i)
        result.m_points[i] = m_points[i] + other.m_points[i];
    return result;
}

Cubic Cubic::operator*(float scalar) const
{
    Cubic result;
    for (size_t i = 0; i < 8; ++i)
        result.m_points[i] = m_points[i] * scalar;
    return result;
}

Cubic Cubic::operator/(float scalar) const
{
    return (*this) * (1.0f / scalar);
}

bool Cubic::operator==(const Cubic &other) const
{
    for (size_t i = 0; i < 8; ++i) {
        if (std::abs(m_points[i] - other.m_points[i]) > detail::kDistanceEpsilon)
            return false;
    }
    return true;
}

Cubic Cubic::straightLine(float x0, float y0, float x1, float y1)
{
    return Cubic(
        x0, y0,
        detail::interpolateFloat(x0, x1, 1.0f / 3.0f),
        detail::interpolateFloat(y0, y1, 1.0f / 3.0f),
        detail::interpolateFloat(x0, x1, 2.0f / 3.0f),
        detail::interpolateFloat(y0, y1, 2.0f / 3.0f),
        x1, y1
    );
}

Cubic Cubic::circularArc(float centerX, float centerY,
                         float x0, float y0,
                         float x1, float y1)
{
    const QPointF p0d = detail::directionVector(x0 - centerX, y0 - centerY);
    const QPointF p1d = detail::directionVector(x1 - centerX, y1 - centerY);
    const QPointF rotatedP0(-p0d.y(), p0d.x());
    const QPointF rotatedP1(-p1d.y(), p1d.x());
    const float radius = detail::distance(x0 - centerX, y0 - centerY);
    const float diff = static_cast<float>(p0d.x() * (x1 - centerX) + p0d.y() * (y1 - centerY));
    const float cosAngle = std::clamp(diff / std::max(radius, detail::kDistanceEpsilon), -1.0f, 1.0f);
    const float angle = std::acos(cosAngle);
    const float k = (4.0f / 3.0f) * std::tan(angle / 4.0f) * radius;
    const float sign = (p0d.x() * (y1 - centerY) - p0d.y() * (x1 - centerX)) >= 0.0f ? 1.0f : -1.0f;

    return Cubic(
        x0, y0,
        x0 + static_cast<float>(rotatedP0.x()) * k * sign,
        y0 + static_cast<float>(rotatedP0.y()) * k * sign,
        x1 - static_cast<float>(rotatedP1.x()) * k * sign,
        y1 - static_cast<float>(rotatedP1.y()) * k * sign,
        x1, y1
    );
}

Cubic Cubic::empty(float x0, float y0)
{
    return Cubic(x0, y0, x0, y0, x0, y0, x0, y0);
}

Cubic Cubic::interpolate(const Cubic &start, const Cubic &end, float progress)
{
    Cubic result;
    for (size_t i = 0; i < 8; ++i)
        result.m_points[i] = detail::interpolateFloat(start.m_points[i], end.m_points[i], progress);
    return result;
}

} // namespace m3shapes
