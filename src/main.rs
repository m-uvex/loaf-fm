pub mod apps;
pub mod archive;
pub mod core;
pub mod drives;
pub mod fsops;
pub mod icons;
pub mod info;
pub mod listing;
pub mod mtp;
pub mod mtp_ops;
pub mod native;
pub mod pane;
pub mod portal;
pub mod portal_bridge;
pub mod search;
pub mod share;
pub mod smb;
pub mod state;
pub mod theme;
pub mod trash;
pub mod util;
pub mod watcher;
pub mod xdg;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

const HELP: &str = "Loaf - a Material 3 file manager

Usage: loaf [OPTIONS] [PATH...]

Opens each PATH (a folder, a file to show in its folder, or a file:// URI or Loaf MTP address)
in a tab. Without --new-window the paths are handed to a running Loaf.

Options:
  -p, --path <DIR>   Start in DIR
  -m, --mini         Start in the compact (mini) layout
      --new-window   Always open a separate window
      --class <NAME> Use NAME as the window class (Wayland app id / WM_CLASS)
      --portal       Serve the xdg-desktop-portal file chooser (D-Bus
                     activation): no main window until one is requested
  -v, --verbose      Print diagnostic messages
      --version      Print the version and exit
  -h, --help         Print this help and exit
";

/// Window class (Wayland app id / WM_CLASS) used when `--class` is not given.
const DEFAULT_CLASS: &str = "loaf";

struct Args {
    paths: Vec<String>,
    mini: bool,
    new_window: bool,
    portal: bool,
    class: String,
}

fn parse_args() -> Result<Args, String> {
    let mut out = Args {
        paths: Vec::new(),
        mini: false,
        new_window: false,
        portal: false,
        class: DEFAULT_CLASS.to_string(),
    };
    let mut it = std::env::args().skip(1);
    while let Some(a) = it.next() {
        match a.as_str() {
            "-h" | "--help" => {
                print!("{}", HELP);
                std::process::exit(0);
            }
            "--version" => {
                println!("loaf {}", env!("CARGO_PKG_VERSION"));
                std::process::exit(0);
            }
            "-v" | "--verbose" => std::env::set_var("LOAF_VERBOSE", "1"),
            "-m" | "--mini" => out.mini = true,
            "--new-window" => out.new_window = true,
            "--portal" => out.portal = true,
            "--class" => {
                let name = it.next().ok_or("--class needs a name")?;
                if name.is_empty() {
                    return Err("--class needs a name".to_string());
                }
                out.class = name;
            }
            "-p" | "--path" => out.paths.push(it.next().ok_or("--path needs a folder")?),
            "--" => out.paths.extend(it.by_ref()),
            s if s.starts_with('-') && s.len() > 1 => {
                return Err(format!("unknown option '{}' (see --help)", s))
            }
            s => out.paths.push(s.to_string()),
        }
    }
    // Relative paths are relative to where loaf was started.
    let cwd = std::env::current_dir().unwrap_or_else(|_| util::home());
    out.paths = out
        .paths
        .into_iter()
        .map(|p| {
            if p.starts_with("file://") || p.starts_with("mtp://") || p.starts_with('/') {
                p
            } else {
                cwd.join(p).to_string_lossy().to_string()
            }
        })
        .collect();
    Ok(out)
}

fn main() {
    let args = match parse_args() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("loaf: {}", e);
            std::process::exit(2);
        }
    };
    native::ffi::set_application_identity(env!("CARGO_PKG_VERSION"), &args.class);
    let mut app = QGuiApplication::new();
    let admin = std::env::var("LOAF_ADMIN").is_ok();
    // A custom window class is a distinct application identity: the running
    // instance cannot provide it, so this process runs as its own instance.
    let standalone = args.new_window || admin || args.class != DEFAULT_CLASS;
    if !standalone {
        // A portal handoff must not raise the running instance's window.
        let (forward_paths, forward_mode) = if args.portal {
            (Vec::new(), "portal")
        } else if args.paths.is_empty() {
            (Vec::new(), "window")
        } else {
            (args.paths.clone(), "tab")
        };
        if native::ffi::forward_to_running_instance(&forward_paths, forward_mode) {
            return;
        }
    }
    let mut engine = QQmlApplicationEngine::new();
    let url = match std::env::var("LOAF_QML") {
        Ok(path) if !path.is_empty() => QUrl::from(&format!("file://{path}")),
        _ => QUrl::from("qrc:/qt/qml/app/loaf/qml/main.qml"),
    };
    let mut modes = vec![if args.mini { "mini" } else { "tab" }];
    if standalone {
        modes.push("new-window");
    }
    if args.portal {
        modes.push("portal");
    }
    let mode = modes.join(",");
    if let Some(mut engine) = engine.as_mut() {
        native::ffi::setup_engine(engine.as_mut(), &args.paths, &mode);
        engine.load(&url);
    }
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
