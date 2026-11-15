#include <QCoreApplication>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QQuickItem>
#include <QMimeData>
#include <QDropEvent>
#include <QUrl>
#include <QQmlEngine>
#include <QObject>

class DropEventInjector : public QObject {
    Q_OBJECT
public:
    explicit DropEventInjector(QObject *parent = nullptr) : QObject(parent) {}

    // Injects native Qt drag/drop events into the window containing target item
    Q_INVOKABLE int deliverDrop(QQuickItem *item, const QStringList &urls, qreal x, qreal y, int supportedActions = 3, int proposedAction = 1) {
        if (!item) return -1;
        QQuickWindow *win = item->window();
        if (!win) return -2;

        QPointF itemPos(x, y);
        QPointF scenePos = item->mapToScene(itemPos);
        QPoint scenePosInt = scenePos.toPoint();

        QMimeData mimeData;
        QList<QUrl> qurls;
        for (const QString &u : urls) {
            qurls.append(QUrl(u));
        }
        mimeData.setUrls(qurls);

        QDragEnterEvent enterEvent(scenePosInt, static_cast<Qt::DropActions>(supportedActions), &mimeData, Qt::LeftButton, Qt::NoModifier);
        enterEvent.setDropAction(static_cast<Qt::DropAction>(proposedAction));
        QCoreApplication::sendEvent(win, &enterEvent);

        QDragMoveEvent moveEvent(scenePosInt, static_cast<Qt::DropActions>(supportedActions), &mimeData, Qt::LeftButton, Qt::NoModifier);
        moveEvent.setDropAction(static_cast<Qt::DropAction>(proposedAction));
        QCoreApplication::sendEvent(win, &moveEvent);

        QDropEvent dropEvent(scenePos, static_cast<Qt::DropActions>(supportedActions), &mimeData, Qt::LeftButton, Qt::NoModifier);
        dropEvent.setDropAction(static_cast<Qt::DropAction>(proposedAction));

        QCoreApplication::sendEvent(win, &dropEvent);
        return dropEvent.isAccepted() ? static_cast<int>(dropEvent.dropAction()) : 0;
    }
};

static void initTestFixture() {
    qmlRegisterSingletonType<DropEventInjector>("loaf.test", 1, 0, "DropEventInjector", [](QQmlEngine *, QJSEngine *) -> QObject* {
        return new DropEventInjector();
    });
}

Q_COREAPP_STARTUP_FUNCTION(initTestFixture)

#include "drop_event_injector.moc"
