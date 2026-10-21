pub mod bridge;
pub mod fs;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    // Allow loading QML from the source tree during development:
    //   LOAF_QML=/path/to/main.qml target/debug/loaf
    // Falls back to the compiled-in qrc resource for normal runs.
    let url = match std::env::var("LOAF_QML") {
        Ok(path) if !path.is_empty() => QUrl::from(&format!("file://{path}")),
        _ => QUrl::from("qrc:/qt/qml/app/loaf/qml/main.qml"),
    };

    if let Some(engine) = engine.as_mut() {
        engine.load(&url);
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
