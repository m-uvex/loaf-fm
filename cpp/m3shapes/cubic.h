#pragma once

#include <QPointF>
#include <QRectF>
#include <array>
#include <cmath>
#include <functional>
#include <utility>

namespace m3shapes {

using PointTransformer = std::function<QPointF(float, float)>;

class Cubic
{
public:
    Cubic() = default;
    Cubic(float anchor0X, float anchor0Y,
          float control0X, float control0Y,
          float control1X, float control1Y,
          float anchor1X, float anchor1Y);
    Cubic(QPointF anchor0, QPointF control0, QPointF control1, QPointF anchor1);

    float anchor0X() const { return m_points[0]; }
    float anchor0Y() const { return m_points[1]; }
    float control0X() const { return m_points[2]; }
    float control0Y() const { return m_points[3]; }
    float control1X() const { return m_points[4]; }
    float control1Y() const { return m_points[5]; }
    float anchor1X() const { return m_points[6]; }
    float anchor1Y() const { return m_points[7]; }

    const std::array<float, 8> &points() const { return m_points; }

    QPointF pointOnCurve(float t) const;
    bool zeroLength() const;

    std::pair<Cubic, Cubic> split(float t) const;
    Cubic reverse() const;
    Cubic transformed(const PointTransformer &f) const;

    void calculateBounds(std::array<float, 4> &bounds, bool approximate = false) const;

    Cubic operator+(const Cubic &other) const;
    Cubic operator*(float scalar) const;
    Cubic operator/(float scalar) const;
    bool operator==(const Cubic &other) const;

    static Cubic straightLine(float x0, float y0, float x1, float y1);
    static Cubic circularArc(float centerX, float centerY,
                             float x0, float y0,
                             float x1, float y1);
    static Cubic empty(float x0, float y0);
    static Cubic interpolate(const Cubic &start, const Cubic &end, float progress);

private:
    std::array<float, 8> m_points{0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f};
};

namespace detail {

constexpr float kDistanceEpsilon = 1e-4f;
constexpr float kAngleEpsilon = 1e-6f;
constexpr float kRelaxedDistanceEpsilon = 5e-3f;
constexpr float kFloatPi = 3.14159265358979323846f;
constexpr float kTwoPi = 2.0f * kFloatPi;

inline float interpolateFloat(float start, float stop, float fraction)
{
    return (1.0f - fraction) * start + fraction * stop;
}

inline QPointF interpolatePoint(QPointF start, QPointF stop, float fraction)
{
    return QPointF(interpolateFloat(static_cast<float>(start.x()), static_cast<float>(stop.x()), fraction),
                   interpolateFloat(static_cast<float>(start.y()), static_cast<float>(stop.y()), fraction));
}

inline float distance(float dx, float dy)
{
    return std::hypot(dx, dy);
}

inline float distanceSquared(float dx, float dy)
{
    return dx * dx + dy * dy;
}

inline QPointF directionVector(float dx, float dy)
{
    const float d = distance(dx, dy);
    if (d <= kDistanceEpsilon)
        return QPointF(0.0, 0.0);
    return QPointF(dx / d, dy / d);
}

inline QPointF directionVector(float angleRadians)
{
    return QPointF(std::cos(angleRadians), std::sin(angleRadians));
}

inline QPointF radialToCartesian(float radius, float angleRadians, QPointF center = QPointF(0.0, 0.0))
{
    return QPointF(std::cos(angleRadians) * radius + static_cast<float>(center.x()),
                   std::sin(angleRadians) * radius + static_cast<float>(center.y()));
}

inline float positiveModulo(float num, float mod)
{
    const float r = std::fmod(num, mod);
    return r < 0.0f ? r + mod : r;
}

inline bool convex(QPointF previous, QPointF current, QPointF next)
{
    const float dx1 = static_cast<float>(current.x() - previous.x());
    const float dy1 = static_cast<float>(current.y() - previous.y());
    const float dx2 = static_cast<float>(next.x() - current.x());
    const float dy2 = static_cast<float>(next.y() - current.y());
    return (dx1 * dy2 - dy1 * dx2) >= 0.0f;
}

} // namespace detail

} // namespace m3shapes
