#include "m3shapes/material_shape.h"

#include <QQuickWindow>
#include <QSGGeometry>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <algorithm>
#include <cmath>
#include <vector>

namespace m3shapes {

namespace {

struct Vec2
{
    float x = 0.0f;
    float y = 0.0f;
};

struct Rgba8
{
    uchar r = 0;
    uchar g = 0;
    uchar b = 0;
    uchar a = 0;
};

Rgba8 premultiply(const QColor &c)
{
    const float a = std::clamp(static_cast<float>(c.alphaF()), 0.0f, 1.0f);
    const float r = std::clamp(static_cast<float>(c.redF()), 0.0f, 1.0f) * a;
    const float g = std::clamp(static_cast<float>(c.greenF()), 0.0f, 1.0f) * a;
    const float b = std::clamp(static_cast<float>(c.blueF()), 0.0f, 1.0f) * a;
    return Rgba8{
        static_cast<uchar>(std::lround(r * 255.0f)),
        static_cast<uchar>(std::lround(g * 255.0f)),
        static_cast<uchar>(std::lround(b * 255.0f)),
        static_cast<uchar>(std::lround(a * 255.0f))
    };
}

std::vector<Vec2> sampleCubics(const std::vector<Cubic> &cubics, float w, float h)
{
    std::vector<Vec2> pts;
    if (cubics.empty())
        return pts;

    constexpr int kSamplesPerCubic = 8;
    pts.reserve(cubics.size() * kSamplesPerCubic);

    auto appendPoint = [&](float nx, float ny) {
        const float px = nx * w;
        const float py = ny * h;
        if (!pts.empty()) {
            const float dx = px - pts.back().x;
            const float dy = py - pts.back().y;
            if (dx * dx + dy * dy < 0.04f)
                return;
        }
        pts.push_back(Vec2{px, py});
    };

    for (const Cubic &c : cubics) {
        if (c.zeroLength())
            continue;
        for (int s = 0; s < kSamplesPerCubic; ++s) {
            const float t = static_cast<float>(s) / static_cast<float>(kSamplesPerCubic);
            const QPointF p = c.pointOnCurve(t);
            appendPoint(static_cast<float>(p.x()), static_cast<float>(p.y()));
        }
    }

    if (pts.size() > 2) {
        const float dx = pts.front().x - pts.back().x;
        const float dy = pts.front().y - pts.back().y;
        if (dx * dx + dy * dy < 0.04f)
            pts.pop_back();
    }
    return pts;
}

float signedPolygonArea(const std::vector<Vec2> &pts)
{
    const size_t n = pts.size();
    if (n < 3)
        return 0.0f;
    double sum = 0.0;
    for (size_t i = 0; i < n; ++i) {
        const Vec2 &p0 = pts[i];
        const Vec2 &p1 = pts[(i + 1) % n];
        sum += static_cast<double>(p0.x) * static_cast<double>(p1.y)
             - static_cast<double>(p1.x) * static_cast<double>(p0.y);
    }
    return static_cast<float>(0.5 * sum);
}

std::vector<Vec2> computeOutwardMiterNormals(const std::vector<Vec2> &pts, float windingSign)
{
    const size_t n = pts.size();
    std::vector<Vec2> edgeNormals(n);
    for (size_t i = 0; i < n; ++i) {
        const Vec2 &p0 = pts[i];
        const Vec2 &p1 = pts[(i + 1) % n];
        const float dx = p1.x - p0.x;
        const float dy = p1.y - p0.y;
        const float len = std::hypot(dx, dy);
        if (len > 1e-4f) {
            // For positive (CW in screen Y-down / CCW in Y-up) area:
            // outward normal is (dy / len, -dx / len) * windingSign
            edgeNormals[i] = Vec2{(dy / len) * windingSign, (-dx / len) * windingSign};
        } else {
            edgeNormals[i] = Vec2{0.0f, 0.0f};
        }
    }

    std::vector<Vec2> vertexNormals(n);
    for (size_t i = 0; i < n; ++i) {
        const Vec2 &n0 = edgeNormals[(i + n - 1) % n];
        const Vec2 &n1 = edgeNormals[i];
        float mx = n0.x + n1.x;
        float my = n0.y + n1.y;
        const float mlen = std::hypot(mx, my);
        if (mlen > 1e-4f) {
            mx /= mlen;
            my /= mlen;
            const float dot = mx * n1.x + my * n1.y;
            const float miterScale = std::clamp(dot > 0.25f ? (1.0f / dot) : 1.0f, 0.5f, 1.75f);
            vertexNormals[i] = Vec2{mx * miterScale, my * miterScale};
        } else {
            vertexNormals[i] = n1;
        }
    }
    return vertexNormals;
}

bool pointInTriangle(Vec2 p, Vec2 a, Vec2 b, Vec2 c)
{
    const float c1 = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    const float c2 = (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x);
    const float c3 = (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x);
    const bool hasNeg = (c1 < -1e-4f) || (c2 < -1e-4f) || (c3 < -1e-4f);
    const bool hasPos = (c1 > 1e-4f) || (c2 > 1e-4f) || (c3 > 1e-4f);
    return !(hasNeg && hasPos);
}

std::vector<uint32_t> triangulatePolygon(const std::vector<Vec2> &pts, float windingSign)
{
    const size_t n = pts.size();
    std::vector<uint32_t> indices;
    if (n < 3)
        return indices;
    indices.reserve((n - 2) * 3);

    std::vector<uint32_t> V(n);
    for (size_t i = 0; i < n; ++i)
        V[i] = static_cast<uint32_t>(i);

    size_t count = n;
    size_t guard = 2 * count;
    for (size_t v = count - 1; count > 2;) {
        if (guard-- == 0) {
            // Fallback to fan from vertex 0 if a degenerate self-touching morph frame occurs
            for (size_t i = 1; i + 1 < count; ++i) {
                indices.push_back(V[0]);
                indices.push_back(V[i]);
                indices.push_back(V[i + 1]);
            }
            break;
        }

        const size_t u = (v >= count) ? 0 : v;
        v = (u + 1) % count;
        const size_t w = (v + 1) % count;

        const Vec2 &A = pts[V[u]];
        const Vec2 &B = pts[V[v]];
        const Vec2 &C = pts[V[w]];

        const float cross = ((B.x - A.x) * (C.y - A.y) - (B.y - A.y) * (C.x - A.x)) * windingSign;
        if (cross < 1e-4f)
            continue;

        bool ear = true;
        for (size_t p = 0; p < count; ++p) {
            if (p == u || p == v || p == w)
                continue;
            if (pointInTriangle(pts[V[p]], A, B, C)) {
                ear = false;
                break;
            }
        }

        if (ear) {
            indices.push_back(V[u]);
            indices.push_back(V[v]);
            indices.push_back(V[w]);
            V.erase(V.begin() + static_cast<std::ptrdiff_t>(v));
            --count;
            guard = 2 * count;
        }
    }

    return indices;
}

} // namespace

MaterialShape::MaterialShape(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    setImplicitWidth(m_implicitSize);
    setImplicitHeight(m_implicitSize);

    m_anim.setStartValue(0.0);
    m_anim.setEndValue(1.0);
    m_anim.setDuration(m_animationDuration);
    m_anim.setEasingCurve(m_animationEasing);
    connect(&m_anim, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_morphProgress = value.toReal();
        Q_EMIT morphProgressChanged();
        update();
    });
}

void MaterialShape::setShape(Shape newShape)
{
    if (m_shape == newShape)
        return;

    const Shape prevTarget = m_shape;
    m_shape = newShape;
    Q_EMIT shapeChanged();

    if (!isComponentComplete() || m_animationDuration <= 0) {
        m_anim.stop();
        if (m_fromShape != newShape) {
            m_fromShape = newShape;
            Q_EMIT fromShapeChanged();
        }
        if (m_toShape != newShape) {
            m_toShape = newShape;
            Q_EMIT toShapeChanged();
        }
        if (!qFuzzyCompare(m_morphProgress, 1.0)) {
            m_morphProgress = 1.0;
            Q_EMIT morphProgressChanged();
        }
        m_morphDirty = true;
        update();
        return;
    }

    // Smoothly reverse if interrupted mid-morph back toward m_fromShape
    if (m_anim.state() == QAbstractAnimation::Running && newShape == m_fromShape && m_toShape == prevTarget) {
        m_anim.stop();
        std::swap(m_fromShape, m_toShape);
        Q_EMIT fromShapeChanged();
        Q_EMIT toShapeChanged();
        m_morphDirty = true;
        const qreal startProg = std::clamp(1.0 - m_morphProgress, 0.0, 1.0);
        m_morphProgress = startProg;
        m_anim.setStartValue(startProg);
        m_anim.setEndValue(1.0);
        m_anim.setDuration(std::max(1, static_cast<int>(std::lround(m_animationDuration * (1.0 - startProg)))));
        m_anim.setEasingCurve(m_animationEasing);
        m_anim.start();
        return;
    }

    m_anim.stop();
    m_fromShape = prevTarget;
    m_toShape = newShape;
    m_morphDirty = true;
    Q_EMIT fromShapeChanged();
    Q_EMIT toShapeChanged();

    m_morphProgress = 0.0;
    Q_EMIT morphProgressChanged();
    m_anim.setStartValue(0.0);
    m_anim.setEndValue(1.0);
    m_anim.setDuration(m_animationDuration);
    m_anim.setEasingCurve(m_animationEasing);
    m_anim.start();
}

void MaterialShape::setFromShape(Shape shape)
{
    if (m_fromShape == shape)
        return;
    m_fromShape = shape;
    m_morphDirty = true;
    Q_EMIT fromShapeChanged();
    update();
}

void MaterialShape::setToShape(Shape shape)
{
    if (m_toShape == shape)
        return;
    m_toShape = shape;
    m_morphDirty = true;
    Q_EMIT toShapeChanged();
    update();
}

void MaterialShape::setMorphProgress(qreal progress)
{
    const qreal clamped = std::clamp(progress, qreal(0.0), qreal(1.0));
    if (qFuzzyCompare(m_morphProgress, clamped))
        return;
    m_anim.stop();
    m_morphProgress = clamped;
    Q_EMIT morphProgressChanged();
    update();
}

void MaterialShape::setColor(const QColor &color)
{
    if (m_color == color)
        return;
    m_color = color;
    Q_EMIT colorChanged();
    update();
}

void MaterialShape::setImplicitSize(qreal size)
{
    if (qFuzzyCompare(m_implicitSize, size))
        return;
    m_implicitSize = size;
    setImplicitWidth(size);
    setImplicitHeight(size);
    Q_EMIT implicitSizeChanged();
}

void MaterialShape::setStrokeColor(const QColor &color)
{
    if (m_strokeColor == color)
        return;
    m_strokeColor = color;
    Q_EMIT strokeColorChanged();
    update();
}

void MaterialShape::setStrokeWidth(qreal width)
{
    if (qFuzzyCompare(m_strokeWidth, width))
        return;
    m_strokeWidth = width;
    Q_EMIT strokeWidthChanged();
    update();
}

void MaterialShape::setAnimationDuration(int duration)
{
    if (m_animationDuration == duration)
        return;
    m_animationDuration = duration;
    Q_EMIT animationDurationChanged();
}

void MaterialShape::setAnimationEasing(const QEasingCurve &easing)
{
    if (m_animationEasing == easing)
        return;
    m_animationEasing = easing;
    Q_EMIT animationEasingChanged();
}

void MaterialShape::componentComplete()
{
    QQuickItem::componentComplete();
    update();
}

void MaterialShape::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        update();
}

void MaterialShape::rebuildMorph()
{
    if (!m_morphDirty)
        return;
    const RoundedPolygon &startPoly = MaterialShapes::get(static_cast<ShapeType>(m_fromShape));
    const RoundedPolygon &endPoly = MaterialShapes::get(static_cast<ShapeType>(m_toShape));
    m_morph = Morph(startPoly, endPoly);
    m_morphDirty = false;
}

QSGNode *MaterialShape::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    const float w = static_cast<float>(width());
    const float h = static_cast<float>(height());
    if (w <= 0.0f || h <= 0.0f || (m_color.alpha() == 0 && (m_strokeWidth <= 0.0 || m_strokeColor.alpha() == 0))) {
        delete oldNode;
        return nullptr;
    }

    std::vector<Cubic> activeCubics;
    if (m_fromShape == m_toShape || m_morphProgress >= 0.999) {
        activeCubics = MaterialShapes::get(static_cast<ShapeType>(m_toShape)).cubics();
    } else if (m_morphProgress <= 0.001) {
        activeCubics = MaterialShapes::get(static_cast<ShapeType>(m_fromShape)).cubics();
    } else {
        rebuildMorph();
        activeCubics = m_morph.asCubics(static_cast<float>(m_morphProgress));
    }

    const std::vector<Vec2> basePts = sampleCubics(activeCubics, w, h);
    const size_t n = basePts.size();
    if (n < 3) {
        delete oldNode;
        return nullptr;
    }

    const float area = signedPolygonArea(basePts);
    const float windingSign = (area >= 0.0f) ? 1.0f : -1.0f;
    const std::vector<Vec2> normals = computeOutwardMiterNormals(basePts, windingSign);

    const float dpr = window() ? static_cast<float>(window()->effectiveDevicePixelRatio()) : 1.0f;
    const float aa = 1.0f / std::max(1.0f, dpr);
    const bool hasStroke = m_strokeWidth > 0.0 && m_strokeColor.alpha() > 0;
    const float strokeW = hasStroke ? static_cast<float>(m_strokeWidth) : 0.0f;

    std::vector<Vec2> innerPts(n);
    std::vector<Vec2> outerPts(n);
    for (size_t i = 0; i < n; ++i) {
        innerPts[i] = Vec2{
            basePts[i].x - normals[i].x * (0.5f * aa + strokeW),
            basePts[i].y - normals[i].y * (0.5f * aa + strokeW)
        };
        outerPts[i] = Vec2{
            basePts[i].x + normals[i].x * (0.5f * aa),
            basePts[i].y + normals[i].y * (0.5f * aa)
        };
    }

    const std::vector<uint32_t> fillIndices = triangulatePolygon(innerPts, windingSign);
    const Rgba8 fillCol = premultiply(m_color);
    const Rgba8 transparentCol{0, 0, 0, 0};

    const size_t skirtTriCount = hasStroke ? (n * 6) : (n * 2);
    const size_t totalVertices = fillIndices.size() + skirtTriCount * 3;

    auto *node = static_cast<QSGGeometryNode *>(oldNode);
    if (!node) {
        node = new QSGGeometryNode();
        auto *geom = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(),
                                     static_cast<int>(totalVertices));
        geom->setDrawingMode(QSGGeometry::DrawTriangles);
        node->setGeometry(geom);
        node->setFlag(QSGNode::OwnsGeometry);

        auto *mat = new QSGVertexColorMaterial();
        node->setMaterial(mat);
        node->setFlag(QSGNode::OwnsMaterial);
    } else {
        node->geometry()->allocate(static_cast<int>(totalVertices));
    }

    QSGGeometry::ColoredPoint2D *vtx = node->geometry()->vertexDataAsColoredPoint2D();
    size_t idx = 0;

    for (uint32_t vi : fillIndices) {
        vtx[idx++].set(innerPts[vi].x, innerPts[vi].y, fillCol.r, fillCol.g, fillCol.b, fillCol.a);
    }

    auto emitQuadStrip = [&](const std::vector<Vec2> &ringA, Rgba8 colA,
                             const std::vector<Vec2> &ringB, Rgba8 colB) {
        for (size_t i = 0; i < n; ++i) {
            const size_t next = (i + 1) % n;
            vtx[idx++].set(ringA[i].x, ringA[i].y, colA.r, colA.g, colA.b, colA.a);
            vtx[idx++].set(ringB[i].x, ringB[i].y, colB.r, colB.g, colB.b, colB.a);
            vtx[idx++].set(ringB[next].x, ringB[next].y, colB.r, colB.g, colB.b, colB.a);

            vtx[idx++].set(ringA[i].x, ringA[i].y, colA.r, colA.g, colA.b, colA.a);
            vtx[idx++].set(ringB[next].x, ringB[next].y, colB.r, colB.g, colB.b, colB.a);
            vtx[idx++].set(ringA[next].x, ringA[next].y, colA.r, colA.g, colA.b, colA.a);
        }
    };

    if (!hasStroke) {
        emitQuadStrip(innerPts, fillCol, outerPts, transparentCol);
    } else {
        const Rgba8 strokeCol = premultiply(m_strokeColor);
        std::vector<Vec2> strokeInnerPts(n);
        std::vector<Vec2> strokeOuterPts(n);
        for (size_t i = 0; i < n; ++i) {
            strokeInnerPts[i] = Vec2{
                basePts[i].x - normals[i].x * (strokeW - 0.5f * aa),
                basePts[i].y - normals[i].y * (strokeW - 0.5f * aa)
            };
            strokeOuterPts[i] = Vec2{
                basePts[i].x - normals[i].x * (0.5f * aa),
                basePts[i].y - normals[i].y * (0.5f * aa)
            };
        }
        emitQuadStrip(innerPts, fillCol, strokeInnerPts, strokeCol);
        emitQuadStrip(strokeInnerPts, strokeCol, strokeOuterPts, strokeCol);
        emitQuadStrip(strokeOuterPts, strokeCol, outerPts, transparentCol);
    }

    node->markDirty(QSGNode::DirtyGeometry);
    return node;
}

} // namespace m3shapes
