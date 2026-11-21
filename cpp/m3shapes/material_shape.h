#pragma once

#include "m3shapes/morph.h"
#include "m3shapes/shapes.h"

#include <QColor>
#include <QEasingCurve>
#include <QQuickItem>
#include <QVariantAnimation>

namespace m3shapes {

class MaterialShape : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(Shape shape READ shape WRITE setShape NOTIFY shapeChanged)
    Q_PROPERTY(Shape fromShape READ fromShape WRITE setFromShape NOTIFY fromShapeChanged)
    Q_PROPERTY(Shape toShape READ toShape WRITE setToShape NOTIFY toShapeChanged)
    Q_PROPERTY(qreal morphProgress READ morphProgress WRITE setMorphProgress NOTIFY morphProgressChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal implicitSize READ implicitSize WRITE setImplicitSize NOTIFY implicitSizeChanged)
    Q_PROPERTY(QColor strokeColor READ strokeColor WRITE setStrokeColor NOTIFY strokeColorChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY strokeWidthChanged)
    Q_PROPERTY(int animationDuration READ animationDuration WRITE setAnimationDuration NOTIFY animationDurationChanged)
    Q_PROPERTY(QEasingCurve animationEasing READ animationEasing WRITE setAnimationEasing NOTIFY animationEasingChanged)

public:
    enum class Shape {
        Circle = 0,
        Square,
        Slanted,
        Arch,
        Fan,
        Arrow,
        SemiCircle,
        Oval,
        Pill,
        Triangle,
        Diamond,
        ClamShell,
        Pentagon,
        Gem,
        Sunny,
        VerySunny,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Ghostish,
        Clover4Leaf,
        Clover8Leaf,
        Burst,
        SoftBurst,
        Boom,
        SoftBoom,
        Flower,
        Puffy,
        PuffyDiamond,
        PixelCircle,
        PixelTriangle,
        Bun,
        Heart
    };
    Q_ENUM(Shape)

    explicit MaterialShape(QQuickItem *parent = nullptr);

    Shape shape() const { return m_shape; }
    void setShape(Shape shape);

    Shape fromShape() const { return m_fromShape; }
    void setFromShape(Shape shape);

    Shape toShape() const { return m_toShape; }
    void setToShape(Shape shape);

    qreal morphProgress() const { return m_morphProgress; }
    void setMorphProgress(qreal progress);

    QColor color() const { return m_color; }
    void setColor(const QColor &color);

    qreal implicitSize() const { return m_implicitSize; }
    void setImplicitSize(qreal size);

    QColor strokeColor() const { return m_strokeColor; }
    void setStrokeColor(const QColor &color);

    qreal strokeWidth() const { return m_strokeWidth; }
    void setStrokeWidth(qreal width);

    int animationDuration() const { return m_animationDuration; }
    void setAnimationDuration(int duration);

    QEasingCurve animationEasing() const { return m_animationEasing; }
    void setAnimationEasing(const QEasingCurve &easing);

Q_SIGNALS:
    void shapeChanged();
    void fromShapeChanged();
    void toShapeChanged();
    void morphProgressChanged();
    void colorChanged();
    void implicitSizeChanged();
    void strokeColorChanged();
    void strokeWidthChanged();
    void animationDurationChanged();
    void animationEasingChanged();

protected:
    void componentComplete() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *data) override;

private:
    void rebuildMorph();

    Shape m_shape = Shape::Circle;
    Shape m_fromShape = Shape::Circle;
    Shape m_toShape = Shape::Circle;
    qreal m_morphProgress = 1.0;
    QColor m_color = Qt::black;
    qreal m_implicitSize = 48.0;
    QColor m_strokeColor = Qt::transparent;
    qreal m_strokeWidth = 0.0;
    int m_animationDuration = 350;
    QEasingCurve m_animationEasing{QEasingCurve::OutCubic};

    Morph m_morph;
    bool m_morphDirty = true;
    QVariantAnimation m_anim;
};

} // namespace m3shapes
