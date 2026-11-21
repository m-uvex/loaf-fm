#include "m3shapes/shapes.h"

#include <cmath>
#include <unordered_map>

namespace m3shapes {

namespace {

RoundedPolygon rotatePolygon(const RoundedPolygon &poly, float degrees)
{
    const float rad = degrees * detail::kFloatPi / 180.0f;
    const float cosA = std::cos(rad);
    const float sinA = std::sin(rad);
    const float cx = poly.centerX();
    const float cy = poly.centerY();
    return poly.transformed([=](float x, float y) {
        const float dx = x - cx;
        const float dy = y - cy;
        return QPointF(cx + dx * cosA - dy * sinA, cy + dx * sinA + dy * cosA);
    });
}

RoundedPolygon scalePolygon(const RoundedPolygon &poly, float sx, float sy)
{
    const float cx = poly.centerX();
    const float cy = poly.centerY();
    return poly.transformed([=](float x, float y) {
        return QPointF(cx + (x - cx) * sx, cy + (y - cy) * sy);
    });
}

struct PointNRound
{
    float x;
    float y;
    CornerRounding r;
};

RoundedPolygon customPolygon(const std::vector<PointNRound> &pts, int reps = 1, bool mirroring = false)
{
    std::vector<float> coords;
    std::vector<CornerRounding> roundings;

    if (reps <= 1) {
        coords.reserve(pts.size() * 2);
        roundings.reserve(pts.size());
        for (const auto &p : pts) {
            coords.push_back(p.x);
            coords.push_back(p.y);
            roundings.push_back(p.r);
        }
    } else {
        const float cx = 0.5f;
        const float cy = 0.5f;
        const float angleStep = detail::kTwoPi / static_cast<float>(reps);
        for (int rep = 0; rep < reps; ++rep) {
            const float baseAngle = static_cast<float>(rep) * angleStep;
            const bool mirror = mirroring && (rep % 2 == 1);
            const size_t n = pts.size();
            for (size_t i = 0; i < n; ++i) {
                const size_t idx = mirror ? (n - 1 - i) : i;
                if (mirror && (i == 0 || i == n - 1))
                    continue;
                const float dx = pts[idx].x - cx;
                const float dy = pts[idx].y - cy;
                const float dist = std::hypot(dx, dy);
                float ptAngle = std::atan2(dy, dx);
                if (mirror)
                    ptAngle = angleStep - ptAngle;
                const float finalAngle = baseAngle + ptAngle;
                coords.push_back(cx + std::cos(finalAngle) * dist);
                coords.push_back(cy + std::sin(finalAngle) * dist);
                roundings.push_back(pts[idx].r);
            }
        }
    }
    return RoundedPolygon(coords, CornerRounding::Unrounded, roundings).normalized();
}

RoundedPolygon buildShape(ShapeType shape)
{
    switch (shape) {
    case ShapeType::Circle:
        return RoundedPolygon::circle(10).normalized();

    case ShapeType::Square:
        return RoundedPolygon::rectangle(1.0f, 1.0f, CornerRounding(0.3f, 0.0f)).normalized();

    case ShapeType::Slanted:
        return customPolygon({
            {0.926f, 0.970f, CornerRounding(0.189f, 0.811f)},
            {-0.021f, 0.967f, CornerRounding(0.187f, 0.057f)},
            {0.074f, 0.030f, CornerRounding(0.189f, 0.811f)},
            {1.021f, 0.033f, CornerRounding(0.187f, 0.057f)},
        });

    case ShapeType::Arch:
        return rotatePolygon(
            RoundedPolygon(
                4, 1.0f, 0.0f, 0.0f, CornerRounding::Unrounded,
                {
                    CornerRounding(1.0f, 0.0f),
                    CornerRounding(1.0f, 0.0f),
                    CornerRounding(0.2f, 0.0f),
                    CornerRounding(0.2f, 0.0f),
                }
            ),
            -135.0f
        ).normalized();

    case ShapeType::Fan:
        return customPolygon({
            {1.004f, 1.000f, CornerRounding(0.148f, 0.417f)},
            {0.000f, 1.000f, CornerRounding(0.151f, 0.0f)},
            {0.000f, -0.003f, CornerRounding(0.802f, 0.0f)},
            {0.978f, 0.020f, CornerRounding(0.148f, 0.0f)},
        });

    case ShapeType::Arrow:
        return customPolygon({
            {0.500f, 0.892f, CornerRounding(0.313f, 0.0f)},
            {-0.216f, 1.050f, CornerRounding(0.207f, 0.0f)},
            {0.499f, -0.160f, CornerRounding(0.215f, 1.0f)},
            {1.225f, 1.060f, CornerRounding(0.211f, 0.0f)},
        });

    case ShapeType::SemiCircle:
        return RoundedPolygon::rectangle(
            1.6f, 1.0f, CornerRounding::Unrounded,
            {
                CornerRounding(0.2f, 0.0f),
                CornerRounding(0.2f, 0.0f),
                CornerRounding(1.0f, 0.0f),
                CornerRounding(1.0f, 0.0f),
            }
        ).normalized();

    case ShapeType::Oval:
        return rotatePolygon(scalePolygon(RoundedPolygon::circle(8), 1.0f, 0.64f), -45.0f).normalized();

    case ShapeType::Pill:
        return rotatePolygon(RoundedPolygon::pill(1.0f, 0.8f), -45.0f).normalized();

    case ShapeType::Triangle:
        return rotatePolygon(RoundedPolygon(3, 1.0f, 0.0f, 0.0f, CornerRounding(0.2f, 0.0f)), -90.0f).normalized();

    case ShapeType::Diamond:
        return customPolygon({
            {0.500f, 1.096f, CornerRounding(0.151f, 0.524f)},
            {0.040f, 0.500f, CornerRounding(0.159f, 0.0f)},
            {0.500f, -0.096f, CornerRounding(0.151f, 0.524f)},
            {0.960f, 0.500f, CornerRounding(0.159f, 0.0f)},
        });

    case ShapeType::ClamShell:
        return customPolygon({
            {0.171f, 0.841f, CornerRounding(0.159f, 0.0f)},
            {-0.020f, 0.500f, CornerRounding(0.140f, 0.0f)},
            {0.170f, 0.159f, CornerRounding(0.159f, 0.0f)},
            {0.830f, 0.159f, CornerRounding(0.159f, 0.0f)},
            {1.020f, 0.500f, CornerRounding(0.140f, 0.0f)},
            {0.829f, 0.841f, CornerRounding(0.159f, 0.0f)},
        });

    case ShapeType::Pentagon:
        return rotatePolygon(RoundedPolygon(5, 1.0f, 0.0f, 0.0f, CornerRounding(0.3f, 0.0f)), -90.0f).normalized();

    case ShapeType::Gem:
        return customPolygon({
            {0.499f, 1.023f, CornerRounding(0.241f, 0.778f)},
            {-0.005f, 0.792f, CornerRounding(0.208f, 0.0f)},
            {0.073f, 0.258f, CornerRounding(0.228f, 0.0f)},
            {0.499f, -0.000f, CornerRounding(0.491f, 0.0f)},
            {0.927f, 0.258f, CornerRounding(0.228f, 0.0f)},
            {1.005f, 0.792f, CornerRounding(0.208f, 0.0f)},
        });

    case ShapeType::Sunny:
        return RoundedPolygon::star(8, 1.0f, 0.8f, CornerRounding(0.15f, 0.0f)).normalized();

    case ShapeType::VerySunny:
        return RoundedPolygon::star(8, 1.0f, 0.65f, CornerRounding(0.085f, 0.0f), CornerRounding(0.085f, 0.0f)).normalized();

    case ShapeType::Cookie4Sided:
        return RoundedPolygon::star(
            4, 1.0f, 0.5f,
            CornerRounding(0.32f, 0.0f),
            CornerRounding(0.25f, 0.0f),
            {}, 0.0f, 0.0f, -detail::kFloatPi / 4.0f
        ).normalized();

    case ShapeType::Cookie6Sided:
        return RoundedPolygon::star(
            6, 1.0f, 0.72f,
            CornerRounding(0.35f, 0.0f),
            CornerRounding(0.3f, 0.0f),
            {}, 0.0f, 0.0f, -detail::kFloatPi / 2.0f
        ).normalized();

    case ShapeType::Cookie7Sided:
        return RoundedPolygon::star(
            7, 1.0f, 0.75f,
            CornerRounding(0.5f, 0.0f),
            CornerRounding(0.25f, 0.0f),
            {}, 0.0f, 0.0f, -detail::kFloatPi / 2.0f
        ).normalized();

    case ShapeType::Cookie9Sided:
        return RoundedPolygon::star(
            9, 1.0f, 0.8f,
            CornerRounding(0.5f, 0.0f),
            CornerRounding(0.25f, 0.0f),
            {}, 0.0f, 0.0f, -detail::kFloatPi / 2.0f
        ).normalized();

    case ShapeType::Cookie12Sided:
        return RoundedPolygon::star(
            12, 1.0f, 0.8f,
            CornerRounding(0.5f, 0.0f),
            CornerRounding(0.25f, 0.0f),
            {}, 0.0f, 0.0f, -detail::kFloatPi / 2.0f
        ).normalized();

    case ShapeType::Ghostish:
        return customPolygon({
            {0.500f, 0.000f, CornerRounding(1.000f, 0.0f)},
            {1.000f, 0.000f, CornerRounding(1.000f, 0.0f)},
            {1.000f, 1.140f, CornerRounding(0.254f, 0.106f)},
            {0.575f, 0.906f, CornerRounding(0.253f, 0.0f)},
            {0.425f, 0.906f, CornerRounding(0.253f, 0.0f)},
            {0.000f, 1.140f, CornerRounding(0.254f, 0.106f)},
            {0.000f, 0.000f, CornerRounding(1.000f, 0.0f)},
        });

    case ShapeType::Clover4Leaf:
        return RoundedPolygon::star(
            4, 1.0f, 0.25f,
            CornerRounding(0.38f, 0.3f),
            CornerRounding::Unrounded,
            {}, 0.0f, 0.0f, detail::kFloatPi / 4.0f
        ).normalized();

    case ShapeType::Clover8Leaf:
        return RoundedPolygon::star(
            8, 1.0f, 0.62f,
            CornerRounding(0.25f, 0.2f),
            CornerRounding::Unrounded,
            {}, 0.0f, 0.0f, detail::kFloatPi / 8.0f
        ).normalized();

    case ShapeType::Burst:
        return RoundedPolygon::star(12, 1.0f, 0.72f, CornerRounding::Unrounded, CornerRounding::Unrounded).normalized();

    case ShapeType::SoftBurst:
        return RoundedPolygon::star(10, 1.0f, 0.72f, CornerRounding(0.06f, 0.0f), CornerRounding(0.06f, 0.0f)).normalized();

    case ShapeType::Boom:
        return RoundedPolygon::star(15, 1.0f, 0.46f, CornerRounding::Unrounded, CornerRounding::Unrounded).normalized();

    case ShapeType::SoftBoom:
        return RoundedPolygon::star(16, 1.0f, 0.62f, CornerRounding(0.18f, 0.3f), CornerRounding(0.08f, 0.2f)).normalized();

    case ShapeType::Flower:
        return RoundedPolygon::star(
            8, 1.0f, 0.58f,
            CornerRounding(0.32f, 0.4f),
            CornerRounding::Unrounded
        ).normalized();

    case ShapeType::Puffy:
        return RoundedPolygon::pillStar(
            1.0f, 0.74f, 8, 0.8f,
            CornerRounding(0.25f, 0.0f),
            CornerRounding(0.05f, 0.0f)
        ).normalized();

    case ShapeType::PuffyDiamond:
        return RoundedPolygon::star(
            4, 1.0f, 0.82f,
            CornerRounding(0.22f, 0.0f),
            CornerRounding(0.05f, 0.0f)
        ).normalized();

    case ShapeType::PixelCircle:
        return customPolygon({
            {0.300f, 0.000f, CornerRounding::Unrounded},
            {0.700f, 0.000f, CornerRounding::Unrounded},
            {0.700f, 0.065f, CornerRounding::Unrounded},
            {0.835f, 0.065f, CornerRounding::Unrounded},
            {0.835f, 0.165f, CornerRounding::Unrounded},
            {0.935f, 0.165f, CornerRounding::Unrounded},
            {0.935f, 0.300f, CornerRounding::Unrounded},
            {1.000f, 0.300f, CornerRounding::Unrounded},
            {1.000f, 0.700f, CornerRounding::Unrounded},
            {0.935f, 0.700f, CornerRounding::Unrounded},
            {0.935f, 0.835f, CornerRounding::Unrounded},
            {0.835f, 0.835f, CornerRounding::Unrounded},
            {0.835f, 0.935f, CornerRounding::Unrounded},
            {0.700f, 0.935f, CornerRounding::Unrounded},
            {0.700f, 1.000f, CornerRounding::Unrounded},
            {0.300f, 1.000f, CornerRounding::Unrounded},
            {0.300f, 0.935f, CornerRounding::Unrounded},
            {0.165f, 0.935f, CornerRounding::Unrounded},
            {0.165f, 0.835f, CornerRounding::Unrounded},
            {0.065f, 0.835f, CornerRounding::Unrounded},
            {0.065f, 0.700f, CornerRounding::Unrounded},
            {0.000f, 0.700f, CornerRounding::Unrounded},
            {0.000f, 0.300f, CornerRounding::Unrounded},
            {0.065f, 0.300f, CornerRounding::Unrounded},
            {0.065f, 0.165f, CornerRounding::Unrounded},
            {0.165f, 0.165f, CornerRounding::Unrounded},
            {0.165f, 0.065f, CornerRounding::Unrounded},
            {0.300f, 0.065f, CornerRounding::Unrounded},
        });

    case ShapeType::PixelTriangle:
        return customPolygon({
            {0.110f, 0.500f, CornerRounding::Unrounded},
            {0.113f, 0.000f, CornerRounding::Unrounded},
            {0.287f, 0.000f, CornerRounding::Unrounded},
            {0.287f, 0.087f, CornerRounding::Unrounded},
            {0.421f, 0.087f, CornerRounding::Unrounded},
            {0.421f, 0.170f, CornerRounding::Unrounded},
            {0.560f, 0.170f, CornerRounding::Unrounded},
            {0.560f, 0.265f, CornerRounding::Unrounded},
            {0.674f, 0.265f, CornerRounding::Unrounded},
            {0.675f, 0.344f, CornerRounding::Unrounded},
            {0.789f, 0.344f, CornerRounding::Unrounded},
            {0.789f, 0.439f, CornerRounding::Unrounded},
            {0.888f, 0.439f, CornerRounding::Unrounded},
            {0.888f, 0.561f, CornerRounding::Unrounded},
            {0.789f, 0.561f, CornerRounding::Unrounded},
            {0.789f, 0.656f, CornerRounding::Unrounded},
            {0.675f, 0.656f, CornerRounding::Unrounded},
            {0.674f, 0.735f, CornerRounding::Unrounded},
            {0.560f, 0.735f, CornerRounding::Unrounded},
            {0.560f, 0.830f, CornerRounding::Unrounded},
            {0.421f, 0.830f, CornerRounding::Unrounded},
            {0.421f, 0.913f, CornerRounding::Unrounded},
            {0.287f, 0.913f, CornerRounding::Unrounded},
            {0.287f, 1.000f, CornerRounding::Unrounded},
            {0.113f, 1.000f, CornerRounding::Unrounded},
        });

    case ShapeType::Bun:
        return customPolygon({
            {0.796f, 0.500f, CornerRounding::Unrounded},
            {0.853f, 0.518f, CornerRounding(1.0f, 0.0f)},
            {0.992f, 0.631f, CornerRounding(1.0f, 0.0f)},
            {0.968f, 1.000f, CornerRounding(1.0f, 0.0f)},
            {0.032f, 1.000f, CornerRounding(1.0f, 0.0f)},
            {0.008f, 0.631f, CornerRounding(1.0f, 0.0f)},
            {0.147f, 0.518f, CornerRounding(1.0f, 0.0f)},
            {0.204f, 0.500f, CornerRounding::Unrounded},
            {0.147f, 0.482f, CornerRounding(1.0f, 0.0f)},
            {0.008f, 0.369f, CornerRounding(1.0f, 0.0f)},
            {0.032f, 0.000f, CornerRounding(1.0f, 0.0f)},
            {0.968f, 0.000f, CornerRounding(1.0f, 0.0f)},
            {0.992f, 0.369f, CornerRounding(1.0f, 0.0f)},
            {0.853f, 0.482f, CornerRounding(1.0f, 0.0f)},
        });

    case ShapeType::Heart:
        return customPolygon({
            {0.500f, 0.268f, CornerRounding(0.016f, 0.0f)},
            {0.792f, -0.066f, CornerRounding(0.958f, 0.0f)},
            {1.064f, 0.276f, CornerRounding(1.000f, 0.0f)},
            {0.501f, 0.946f, CornerRounding(0.129f, 0.0f)},
            {-0.064f, 0.276f, CornerRounding(1.000f, 0.0f)},
            {0.208f, -0.066f, CornerRounding(0.958f, 0.0f)},
        });
    }
    return RoundedPolygon::circle(10).normalized();
}

} // namespace

const RoundedPolygon &MaterialShapes::get(ShapeType shape)
{
    static std::unordered_map<int, RoundedPolygon> cache;
    const int key = static_cast<int>(shape);
    auto it = cache.find(key);
    if (it == cache.end()) {
        it = cache.emplace(key, buildShape(shape)).first;
    }
    return it->second;
}

} // namespace m3shapes
