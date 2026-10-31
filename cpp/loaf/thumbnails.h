// Asynchronous thumbnail image provider: image://thumb/<hex path>-<mtime>[/cover]
//
// Follows the freedesktop.org Thumbnail Managing Standard so thumbnails are
// shared with Nautilus, Dolphin, etc.:
//   $XDG_CACHE_HOME/thumbnails/{normal,large,x-large}/<md5(uri)>.png
// with Thumb::URI / Thumb::MTime text chunks, plus fail markers in
// thumbnails/fail/loaf-1.0/. Images Qt can decode are scaled while reading
// (cheap for JPEG); everything else goes through the system thumbnailers in
// $XDG_DATA_DIRS/thumbnailers (videos, PDFs, fonts, ...).
#pragma once

#include <QImage>
#include <QQuickAsyncImageProvider>
#include <QRunnable>
#include <QThreadPool>

#include <atomic>
#include <memory>

namespace loaf {

// Work item run on the provider's pool. It reports back through a queued
// signal, so a response that Qt already deleted (cancelled) is never touched.
class ThumbRunnable : public QObject, public QRunnable
{
    Q_OBJECT
public:
    ThumbRunnable(const QByteArray &path, const QSize &requested, bool cover,
                  std::shared_ptr<std::atomic<bool>> cancelled);
    void run() override;

Q_SIGNALS:
    void done(const QImage &image, const QString &error);

private:
    QByteArray m_path; // raw file name bytes
    QSize m_requested;
    bool m_cover;
    std::shared_ptr<std::atomic<bool>> m_cancelled;
};

class ThumbnailProvider : public QQuickAsyncImageProvider
{
public:
    ThumbnailProvider();
    ~ThumbnailProvider() override;
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

private:
    QThreadPool m_pool;
};

} // namespace loaf
