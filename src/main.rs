pub mod apps;
pub mod archive;
// cxx-qt 0.10 generates a trampolining extern "C" wrapper for save_network_profile
// with 10 parameters; rustc/clippy applies too_many_arguments to the module level
// because item-level allow does not reach into macro-generated Qt bridge glue.
#[allow(clippy::too_many_arguments)]
pub mod core;
pub mod drives;
pub mod fsops;
pub mod icons;
pub mod info;
pub mod kdeconnect;
pub mod listing;
pub mod message;
pub mod metadata;
pub mod mtp;
pub mod mtp_ops;
pub mod native;
pub mod network;
pub mod pane;
pub mod portal;
pub mod portal_bridge;
pub mod rclone;
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
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};

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

pub(crate) fn env_language() -> Option<String> {
    std::env::var("LOAF_LANG")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

pub(crate) fn resolve_language(env_value: Option<&str>, stored_value: Option<&str>) -> String {
    let clean = |v: Option<&str>| {
        v.map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    };
    clean(env_value)
        .or_else(|| clean(stored_value))
        .unwrap_or_default()
}

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

/// Display environment variables inspected before Qt initializes its platform plugin.
#[derive(Debug, Default)]
struct DisplayEnv {
    wayland_display: Option<String>,
    display: Option<String>,
    qt_qpa_platform: Option<String>,
    xdg_runtime_dir: Option<PathBuf>,
}

/// Environment overrides produced when a configured display socket is unreachable.
#[derive(Debug, Default, PartialEq, Eq)]
struct DisplayEnvPatch {
    wayland_display: Option<String>,
    display: Option<String>,
    qt_qpa_platform: Option<String>,
}

fn qpa_tokens(qpa: &str) -> impl Iterator<Item = &str> {
    qpa.split([';', ','])
        .map(str::trim)
        .filter(|s| !s.is_empty())
}

fn is_headless_qpa_platform(qpa: &str) -> bool {
    const HEADLESS: &[&str] = &[
        "offscreen",
        "minimal",
        "minimalegl",
        "vnc",
        "linuxfb",
        "eglfs",
        "vkkhrdisplay",
    ];
    qpa_tokens(qpa).any(|token| HEADLESS.iter().any(|h| token.eq_ignore_ascii_case(h)))
}

fn is_unix_socket_alive(path: &Path) -> bool {
    UnixStream::connect(path).is_ok()
}

fn wayland_socket_path(runtime_dir: &Path, display: &str) -> PathBuf {
    if display.starts_with('/') {
        PathBuf::from(display)
    } else {
        runtime_dir.join(display)
    }
}

fn find_live_wayland_socket(runtime_dir: &Path) -> Option<String> {
    let entries = std::fs::read_dir(runtime_dir).ok()?;
    let mut candidates: Vec<(u64, String)> = entries
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().into_string().ok()?;
            let rest = name.strip_prefix("wayland-")?;
            if rest.is_empty() || name.ends_with(".lock") {
                return None;
            }
            // Sort numeric sockets (wayland-0, wayland-1, ..., wayland-10) numerically first.
            let order = rest.parse::<u64>().unwrap_or(u64::MAX);
            Some((order, name))
        })
        .collect();
    candidates.sort();
    candidates
        .into_iter()
        .map(|(_, name)| name)
        .find(|name| is_unix_socket_alive(&runtime_dir.join(name)))
}

fn local_x11_display_number(display: &str) -> Option<u32> {
    let rest = display.strip_prefix(':')?;
    let num_str = rest.split('.').next()?;
    num_str.parse::<u32>().ok()
}

fn find_live_x11_display(x11_dir: &Path) -> Option<String> {
    let entries = std::fs::read_dir(x11_dir).ok()?;
    let mut candidates: Vec<(u32, PathBuf)> = entries
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().into_string().ok()?;
            let num = name.strip_prefix('X')?.parse::<u32>().ok()?;
            Some((num, entry.path()))
        })
        .collect();
    candidates.sort_by_key(|(num, _)| *num);
    candidates
        .into_iter()
        .find(|(_, path)| is_unix_socket_alive(path))
        .map(|(num, _)| format!(":{num}"))
}

/// Probes Wayland and X11 sockets so D-Bus/systemd-activated instances recover when
/// `WAYLAND_DISPLAY` or `DISPLAY` points to a stale socket or was omitted.
fn resolve_display_env(env: &DisplayEnv, x11_dir: &Path) -> DisplayEnvPatch {
    let mut patch = DisplayEnvPatch::default();
    let qpa = env.qt_qpa_platform.as_deref().unwrap_or("");
    if is_headless_qpa_platform(qpa) {
        return patch;
    }

    let has_qpa = !qpa.trim().is_empty();
    let wants_wayland = !has_qpa || qpa_tokens(qpa).any(|t| t.eq_ignore_ascii_case("wayland"));
    let wants_xcb = !has_qpa || qpa_tokens(qpa).any(|t| t.eq_ignore_ascii_case("xcb"));

    let mut wayland_alive = false;
    if wants_wayland {
        if let Some(runtime_dir) = env.xdg_runtime_dir.as_deref() {
            let configured = env.wayland_display.as_deref().unwrap_or("");
            let default_candidate = if configured.is_empty() {
                "wayland-0"
            } else {
                configured
            };
            if is_unix_socket_alive(&wayland_socket_path(runtime_dir, default_candidate)) {
                wayland_alive = true;
            } else if let Some(live) = find_live_wayland_socket(runtime_dir) {
                patch.wayland_display = Some(live);
                wayland_alive = true;
            }
        }
    }

    let mut x11_alive = false;
    let current_display = env.display.as_deref().unwrap_or("");
    if let Some(num) = local_x11_display_number(current_display) {
        if is_unix_socket_alive(&x11_dir.join(format!("X{num}"))) {
            x11_alive = true;
        } else if let Some(live) = find_live_x11_display(x11_dir) {
            patch.display = Some(live);
            x11_alive = true;
        }
    } else if current_display.is_empty() && !wayland_alive {
        if let Some(live) = find_live_x11_display(x11_dir) {
            patch.display = Some(live);
            x11_alive = true;
        }
    }

    // If QT_QPA_PLATFORM forced Wayland without xcb and no Wayland socket is reachable,
    // fall back to xcb when X11 is available instead of letting QGuiApplication abort.
    if !wayland_alive && x11_alive && has_qpa && !wants_xcb {
        patch.qt_qpa_platform = Some("xcb".to_string());
    }

    patch
}

/// Ensures `WAYLAND_DISPLAY`, `DISPLAY`, and `QT_QPA_PLATFORM` point to reachable
/// display sockets before `QGuiApplication::new()` initializes Qt's platform plugin.
fn sanitize_display_env() {
    let env = DisplayEnv {
        wayland_display: std::env::var("WAYLAND_DISPLAY").ok(),
        display: std::env::var("DISPLAY").ok(),
        qt_qpa_platform: std::env::var("QT_QPA_PLATFORM").ok(),
        xdg_runtime_dir: std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from),
    };
    let patch = resolve_display_env(&env, Path::new("/tmp/.X11-unix"));
    let verbose = std::env::var_os("LOAF_VERBOSE").is_some();
    if let Some(wayland) = patch.wayland_display {
        if verbose {
            eprintln!("loaf: recovered WAYLAND_DISPLAY={wayland}");
        }
        // SAFETY: sanitize_display_env runs on the main thread before Qt or worker threads spawn.
        #[allow(unused_unsafe)]
        unsafe {
            std::env::set_var("WAYLAND_DISPLAY", wayland);
        }
    }
    if let Some(display) = patch.display {
        if verbose {
            eprintln!("loaf: recovered DISPLAY={display}");
        }
        // SAFETY: sanitize_display_env runs on the main thread before Qt or worker threads spawn.
        #[allow(unused_unsafe)]
        unsafe {
            std::env::set_var("DISPLAY", display);
        }
    }
    if let Some(qpa) = patch.qt_qpa_platform {
        if verbose {
            eprintln!("loaf: fallback QT_QPA_PLATFORM={qpa}");
        }
        // SAFETY: sanitize_display_env runs on the main thread before Qt or worker threads spawn.
        #[allow(unused_unsafe)]
        unsafe {
            std::env::set_var("QT_QPA_PLATFORM", qpa);
        }
    }
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
    let env_lang = env_language();
    let language = resolve_language(env_lang.as_deref(), state::get("language").as_deref());
    native::set_application_language(&language);
    sanitize_display_env();
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

#[cfg(test)]
mod tests {
    use super::{resolve_display_env, resolve_language, DisplayEnv, DisplayEnvPatch};
    use std::os::unix::net::UnixListener;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    struct TempSocketDir(PathBuf);

    impl TempSocketDir {
        fn new(label: &str) -> Self {
            static COUNTER: AtomicU64 = AtomicU64::new(0);
            let id = COUNTER.fetch_add(1, Ordering::Relaxed);
            let path = std::env::temp_dir().join(format!(
                "loaf-display-test-{}-{}-{}",
                std::process::id(),
                id,
                label
            ));
            let _ = std::fs::remove_dir_all(&path);
            std::fs::create_dir_all(&path).unwrap();
            Self(path)
        }
    }

    impl Drop for TempSocketDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn environment_wins_over_stored_setting() {
        assert_eq!(resolve_language(Some("id"), Some("de")), "id");
    }

    #[test]
    fn stored_setting_used_without_environment() {
        assert_eq!(resolve_language(None, Some("id_ID")), "id_ID");
        assert_eq!(resolve_language(Some(""), Some("de")), "de");
    }

    #[test]
    fn empty_means_system_default() {
        assert_eq!(resolve_language(None, None), "");
        assert_eq!(resolve_language(Some("  "), Some("   ")), "");
    }

    #[test]
    fn recovers_from_stale_wayland_and_display_sockets() {
        let runtime = TempSocketDir::new("runtime");
        let x11 = TempSocketDir::new("x11");
        let _live_wl = UnixListener::bind(runtime.0.join("wayland-1")).unwrap();
        let stale_wl = UnixListener::bind(runtime.0.join("wayland-2")).unwrap();
        drop(stale_wl); // Leaves socket file behind, producing ECONNREFUSED.
        std::fs::write(runtime.0.join("wayland-1.lock"), "").unwrap();
        std::fs::write(runtime.0.join("wayland-0.lock"), "").unwrap();

        let _live_x0 = UnixListener::bind(x11.0.join("X0")).unwrap();
        let stale_x1 = UnixListener::bind(x11.0.join("X1")).unwrap();
        drop(stale_x1);

        let patch = resolve_display_env(
            &DisplayEnv {
                wayland_display: Some("wayland-2".into()),
                display: Some(":1".into()),
                qt_qpa_platform: Some("wayland".into()),
                xdg_runtime_dir: Some(runtime.0.clone()),
            },
            &x11.0,
        );
        assert_eq!(
            patch,
            DisplayEnvPatch {
                wayland_display: Some("wayland-1".into()),
                display: Some(":0".into()),
                qt_qpa_platform: None,
            }
        );
    }

    #[test]
    fn preserves_configured_live_wayland_socket() {
        let runtime = TempSocketDir::new("live");
        let x11 = TempSocketDir::new("live-x11");
        let _wl1 = UnixListener::bind(runtime.0.join("wayland-1")).unwrap();
        let _wl2 = UnixListener::bind(runtime.0.join("wayland-2")).unwrap();

        let patch = resolve_display_env(
            &DisplayEnv {
                wayland_display: Some("wayland-2".into()),
                display: None,
                qt_qpa_platform: Some("wayland".into()),
                xdg_runtime_dir: Some(runtime.0.clone()),
            },
            &x11.0,
        );
        assert_eq!(patch, DisplayEnvPatch::default());
    }

    #[test]
    fn discovers_wayland_socket_when_unset() {
        let runtime = TempSocketDir::new("unset");
        let x11 = TempSocketDir::new("unset-x11");
        let _wl1 = UnixListener::bind(runtime.0.join("wayland-1")).unwrap();

        let patch = resolve_display_env(
            &DisplayEnv {
                wayland_display: None,
                display: None,
                qt_qpa_platform: None,
                xdg_runtime_dir: Some(runtime.0.clone()),
            },
            &x11.0,
        );
        assert_eq!(
            patch,
            DisplayEnvPatch {
                wayland_display: Some("wayland-1".into()),
                display: None,
                qt_qpa_platform: None,
            }
        );
    }

    #[test]
    fn falls_back_to_xcb_when_only_x11_is_live() {
        let runtime = TempSocketDir::new("no-wl");
        let x11 = TempSocketDir::new("only-x11");
        let stale_wl = UnixListener::bind(runtime.0.join("wayland-2")).unwrap();
        drop(stale_wl);
        let _live_x0 = UnixListener::bind(x11.0.join("X0")).unwrap();

        let patch = resolve_display_env(
            &DisplayEnv {
                wayland_display: Some("wayland-2".into()),
                display: Some(":1".into()),
                qt_qpa_platform: Some("wayland".into()),
                xdg_runtime_dir: Some(runtime.0.clone()),
            },
            &x11.0,
        );
        assert_eq!(
            patch,
            DisplayEnvPatch {
                wayland_display: None,
                display: Some(":0".into()),
                qt_qpa_platform: Some("xcb".into()),
            }
        );
    }

    #[test]
    fn ignores_headless_qpa_platforms() {
        let runtime = TempSocketDir::new("headless");
        let x11 = TempSocketDir::new("headless-x11");
        let _live_wl = UnixListener::bind(runtime.0.join("wayland-1")).unwrap();

        let patch = resolve_display_env(
            &DisplayEnv {
                wayland_display: Some("wayland-9".into()),
                display: Some(":9".into()),
                qt_qpa_platform: Some("offscreen".into()),
                xdg_runtime_dir: Some(runtime.0.clone()),
            },
            &x11.0,
        );
        assert_eq!(patch, DisplayEnvPatch::default());
    }
}
