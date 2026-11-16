#pragma once

namespace m3shapes {

struct CornerRounding
{
    float radius = 0.0f;
    float smoothing = 0.0f;

    constexpr CornerRounding(float r = 0.0f, float s = 0.0f)
        : radius(r), smoothing(s)
    {
    }

    static const CornerRounding Unrounded;
};

inline constexpr CornerRounding CornerRounding::Unrounded{0.0f, 0.0f};

} // namespace m3shapes
