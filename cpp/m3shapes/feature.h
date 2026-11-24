#pragma once

#include "m3shapes/cubic.h"
#include <vector>

namespace m3shapes {

class Feature
{
public:
    enum class Type {
        Edge,
        Corner
    };

    Feature() = default;
    Feature(Type type, std::vector<Cubic> cubics, bool convex = true)
        : m_type(type), m_cubics(std::move(cubics)), m_convex(convex)
    {
    }

    Type type() const { return m_type; }
    bool isEdge() const { return m_type == Type::Edge; }
    bool isCorner() const { return m_type == Type::Corner; }
    bool isConvexCorner() const { return m_type == Type::Corner && m_convex; }
    bool isConcaveCorner() const { return m_type == Type::Corner && !m_convex; }
    bool isIgnorableFeature() const { return m_type == Type::Edge; }
    bool convex() const { return m_convex; }

    const std::vector<Cubic> &cubics() const { return m_cubics; }

    Feature transformed(const PointTransformer &f) const
    {
        std::vector<Cubic> out;
        out.reserve(m_cubics.size());
        for (const Cubic &c : m_cubics)
            out.push_back(c.transformed(f));
        return Feature(m_type, std::move(out), m_convex);
    }

    Feature reversed() const
    {
        std::vector<Cubic> out;
        out.reserve(m_cubics.size());
        for (auto it = m_cubics.rbegin(); it != m_cubics.rend(); ++it)
            out.push_back(it->reverse());
        return Feature(m_type, std::move(out), !m_convex);
    }

    static Feature buildEdge(const Cubic &cubic)
    {
        return Feature(Type::Edge, {cubic}, true);
    }

    static Feature buildIgnorableFeature(std::vector<Cubic> cubics)
    {
        return Feature(Type::Edge, std::move(cubics), true);
    }

    static Feature buildConvexCorner(std::vector<Cubic> cubics)
    {
        return Feature(Type::Corner, std::move(cubics), true);
    }

    static Feature buildConcaveCorner(std::vector<Cubic> cubics)
    {
        return Feature(Type::Corner, std::move(cubics), false);
    }

private:
    Type m_type = Type::Edge;
    std::vector<Cubic> m_cubics;
    bool m_convex = true;
};

struct ProgressableFeature
{
    float progress = 0.0f;
    Feature feature;
};

} // namespace m3shapes
