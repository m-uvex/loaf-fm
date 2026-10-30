use crate::archive;
use crate::util;
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct ShareItem {
    pub id: String,
    pub name: String,
    pub original_path: String,
    pub file_path: String,
    pub is_archive: bool,
    pub size_bytes: u64,
    pub created_at: u64,
    pub expires_at: u64, // 0 if no expiration
    pub port: u16,
    pub url: String,
    pub status: String, // "starting", "ready", "error", "expired"
    pub error_message: Option<String>,
    pub bytes_sent: u64,
    pub download_count: u32,
    #[serde(skip)]
    pub temp_file_to_delete: Option<PathBuf>,
}

pub struct ShareManager {
    shares: Mutex<HashMap<String, ShareItem>>,
    handles: Mutex<HashMap<String, ActiveShareHandle>>,
    cloudflared_installing: AtomicBool,
}

struct ActiveShareHandle {
    stop_flag: Arc<AtomicBool>,
    bytes_sent: Arc<AtomicU64>,
    child_process: Option<Child>,
    temp_file: Option<PathBuf>,
}

static MANAGER: OnceLock<ShareManager> = OnceLock::new();

pub fn get_manager() -> &'static ShareManager {
    MANAGER.get_or_init(|| ShareManager {
        shares: Mutex::new(HashMap::new()),
        handles: Mutex::new(HashMap::new()),
        cloudflared_installing: AtomicBool::new(false),
    })
}

/// Find cloudflared binary, checking system PATH, then ~/.local/share/loaf/bin/cloudflared
pub fn find_cloudflared() -> Option<PathBuf> {
    if let Some(p) = util::which("cloudflared") {
        return Some(p);
    }
    let local = util::data_home().join("loaf/bin/cloudflared");
    if local.is_file() {
        return Some(local);
    }
    None
}

pub fn is_cloudflared_installed() -> bool {
    find_cloudflared().is_some()
}

/// Downloads and installs cloudflared asynchronously if not already installed.
pub fn ensure_cloudflared_installed(on_complete: Box<dyn FnOnce(bool, String) + Send + 'static>) {
    if is_cloudflared_installed() {
        on_complete(true, String::new());
        return;
    }

    let mgr = get_manager();
    if mgr.cloudflared_installing.swap(true, Ordering::SeqCst) {
        on_complete(false, "Installation already in progress".into());
        return;
    }

    thread::spawn(move || {
        let res = install_cloudflared_sync();
        get_manager().cloudflared_installing.store(false, Ordering::SeqCst);
        match res {
            Ok(path) => on_complete(true, path.to_string_lossy().to_string()),
            Err(e) => on_complete(false, e),
        }
    });
}

fn install_cloudflared_sync() -> Result<PathBuf, String> {
    let dest_dir = util::data_home().join("loaf/bin");
    std::fs::create_dir_all(&dest_dir).map_err(|e| format!("Failed to create bin dir: {}", e))?;
    let dest_bin = dest_dir.join("cloudflared");
    let tmp_bin = dest_dir.join("cloudflared.tmp");

    let arch = match std::env::consts::ARCH {
        "x86_64" => "amd64",
        "aarch64" => "arm64",
        "arm" => "arm",
        other => return Err(format!("Unsupported architecture: {}", other)),
    };

    let url = format!(
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-{}",
        arch
    );

    // Try using curl, python3, or wget
    let downloaded = if let Some(curl) = util::which("curl") {
        let status = Command::new(curl)
            .args(["-fsSL", "-o", tmp_bin.to_str().unwrap(), &url])
            .status();
        matches!(status, Ok(s) if s.success())
    } else if let Some(wget) = util::which("wget") {
        let status = Command::new(wget)
            .args(["-q", "-O", tmp_bin.to_str().unwrap(), &url])
            .status();
        matches!(status, Ok(s) if s.success())
    } else if let Some(py) = util::which("python3") {
        let py_script = format!(
            "import urllib.request\nreq = urllib.request.Request('{}', headers={{'User-Agent': 'loaf/0.2'}})\nwith urllib.request.urlopen(req) as r, open('{}', 'wb') as f:\n    f.write(r.read())",
            url, tmp_bin.to_str().unwrap()
        );
        let status = Command::new(py).args(["-c", &py_script]).status();
        matches!(status, Ok(s) if s.success())
    } else {
        return Err("Neither curl, wget, nor python3 was found to download cloudflared".into());
    };

    if !downloaded || !tmp_bin.exists() {
        let _ = std::fs::remove_file(&tmp_bin);
        return Err("Download failed".into());
    }

    // Set executable permission (0o755)
    if let Ok(meta) = std::fs::metadata(&tmp_bin) {
        let mut perms = meta.permissions();
        perms.set_mode(0o755);
        let _ = std::fs::set_permissions(&tmp_bin, perms);
    }

    std::fs::rename(&tmp_bin, &dest_bin).map_err(|e| format!("Failed to move binary: {}", e))?;
    Ok(dest_bin)
}

impl ShareManager {
    pub fn list_shares_json(&self) -> String {
        let mut shares: Vec<ShareItem> = {
            let guard = self.shares.lock().unwrap();
            guard.values().cloned().collect()
        };

        // Update real-time stats
        {
            let handles = self.handles.lock().unwrap();
            for s in &mut shares {
                if let Some(h) = handles.get(&s.id) {
                    s.bytes_sent = h.bytes_sent.load(Ordering::Relaxed);
                }
            }
        }

        // Sort newest first
        shares.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        serde_json::to_string(&shares).unwrap_or_else(|_| "[]".into())
    }

    pub fn stop_share(&self, share_id: &str) -> bool {
        let mut h_guard = self.handles.lock().unwrap();
        if let Some(mut handle) = h_guard.remove(share_id) {
            handle.stop_flag.store(true, Ordering::SeqCst);
            if let Some(mut child) = handle.child_process.take() {
                let _ = child.kill();
            }
            if let Some(tmp) = handle.temp_file.take() {
                let _ = std::fs::remove_file(tmp);
            }
        }

        let mut s_guard = self.shares.lock().unwrap();
        if let Some(s) = s_guard.get_mut(share_id) {
            s.status = "expired".into();
            return true;
        }
        false
    }

    pub fn remove_share(&self, share_id: &str) -> bool {
        self.stop_share(share_id);
        let mut s_guard = self.shares.lock().unwrap();
        s_guard.remove(share_id).is_some()
    }
}

pub struct CreateShareParams {
    pub paths: Vec<PathBuf>,
    pub compress_folders: bool,
    pub compress_files: bool,
    pub format: String,
    pub password: String,
    pub expiration_hours: u32, // 0 for none
    pub throttle_kbps: u32,    // 0 for unlimited
}

/// Spawns the sharing pipeline in background thread.
/// Calls on_url(Result<(share_id, url), error>) when ready or on error.
pub fn start_share_pipeline<F>(params: CreateShareParams, on_url: F)
where
    F: FnOnce(Result<(String, String), String>) + Send + 'static,
{
    thread::spawn(move || {
        let res = run_share_pipeline(params);
        match res {
            Ok((id, url)) => on_url(Ok((id, url))),
            Err(e) => on_url(Err(e)),
        }
    });
}

fn run_share_pipeline(params: CreateShareParams) -> Result<(String, String), String> {
    if params.paths.is_empty() {
        return Err("No files selected".into());
    }

    let cloudflared_bin = find_cloudflared().ok_or("cloudflared is not installed".to_string())?;

    // Determine target file to serve
    let single = params.paths.len() == 1;
    let single_path = &params.paths[0];
    let is_dir = single_path.is_dir();

    let needs_archive = needs_archive(single, is_dir, &params);

    let (file_to_serve, serve_name, temp_file) = if needs_archive {
        let base = if single {
            if is_dir {
                single_path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string()
            } else {
                single_path
                    .file_stem()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string()
            }
        } else {
            "Shared_Files".to_string()
        };

        let ext = match params.format.as_str() {
            "7z" => "7z",
            "tar.gz" => "tar.gz",
            _ => "zip",
        };

        let temp_dir = private_share_dir().map_err(|e| format!("Could not prepare the share: {}", e))?;
        let archive_target = temp_dir.join(format!("{}.{}", base, ext));

        // Create the archive
        archive::compress(
            &archive_target,
            &params.paths,
            &params.format,
            &params.password,
            &|| false,
        )
        .map_err(|e| format!("Compression failed: {}", e))?;

        let name = format!("{}.{}", base, ext);
        (archive_target.clone(), name, Some(archive_target))
    } else {
        let name = single_path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();
        (single_path.clone(), name, None)
    };

    let file_meta = std::fs::metadata(&file_to_serve).map_err(|e| e.to_string())?;
    let file_size = file_meta.len();

    // Start local TCP listener on random port (127.0.0.1:0)
    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|e| format!("Failed to bind local port: {}", e))?;
    let local_port = listener.local_addr().map_err(|e| e.to_string())?.port();

    let share_id = format!(
        "{:x}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis()
    );
    let token = format!("{:x}", rand_u64());

    let now_sec = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let expires_at = if params.expiration_hours > 0 {
        now_sec + (params.expiration_hours as u64) * 3600
    } else {
        0
    };

    let stop_flag = Arc::new(AtomicBool::new(false));
    let bytes_sent = Arc::new(AtomicU64::new(0));

    // Register initial share item in manager
    let item = ShareItem {
        id: share_id.clone(),
        name: serve_name.clone(),
        original_path: single_path.to_string_lossy().to_string(),
        file_path: file_to_serve.to_string_lossy().to_string(),
        is_archive: needs_archive,
        size_bytes: file_size,
        created_at: now_sec,
        expires_at,
        port: local_port,
        url: String::new(),
        status: "starting".into(),
        error_message: None,
        bytes_sent: 0,
        download_count: 0,
        temp_file_to_delete: temp_file.clone(),
    };

    {
        let mut guard = get_manager().shares.lock().unwrap();
        guard.insert(share_id.clone(), item);
    }

    // Spawn HTTP file server thread
    let srv_file = file_to_serve.clone();
    let srv_name = serve_name.clone();
    let srv_stop = stop_flag.clone();
    let srv_bytes = bytes_sent.clone();
    let srv_token = token.clone();
    let srv_throttle = params.throttle_kbps;
    let srv_share_id = share_id.clone();

    thread::spawn(move || {
        run_file_server(
            listener,
            srv_file,
            srv_name,
            srv_token,
            srv_throttle,
            srv_stop,
            srv_bytes,
            srv_share_id,
        );
    });

    // Spawn cloudflared tunnel
    let mut cloudflared_cmd = Command::new(cloudflared_bin);
    cloudflared_cmd
        .args([
            "tunnel",
            "--url",
            &format!("http://127.0.0.1:{}", local_port),
            "--no-autoupdate",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    let mut child = cloudflared_cmd
        .spawn()
        .map_err(|e| format!("Failed to spawn cloudflared: {}", e))?;

    let stderr = child
        .stderr
        .take()
        .ok_or("Failed to capture cloudflared stderr")?;

    // Read stderr until we find https://*.trycloudflare.com
    let (url_tx, url_rx) = std::sync::mpsc::channel();
    let stop_for_reader = stop_flag.clone();

    thread::spawn(move || {
        let reader = BufReader::new(stderr);
        let mut found = false;
        for line in reader.lines().flatten() {
            if !found {
                for word in line.split_whitespace() {
                    if (word.starts_with("https://") && word.contains(".trycloudflare.com"))
                        || (word.starts_with("http://") && word.contains(".trycloudflare.com"))
                    {
                        let mut clean_url = word.trim().to_string();
                        if clean_url.ends_with('|') || clean_url.ends_with(']') {
                            clean_url.pop();
                        }
                        let _ = url_tx.send(Ok(clean_url));
                        found = true;
                        break;
                    }
                }
            }
            if stop_for_reader.load(Ordering::Relaxed) {
                break;
            }
        }
        if !found {
            let _ = url_tx.send(Err("Tunnel did not produce a public URL".into()));
        }
    });

    let tunnel_base_url = match url_rx.recv_timeout(Duration::from_secs(30)) {
        Ok(Ok(u)) => u,
        Ok(Err(e)) => {
            let _ = child.kill();
            get_manager().stop_share(&share_id);
            return Err(e);
        }
        Err(_) => {
            let _ = child.kill();
            get_manager().stop_share(&share_id);
            return Err("Timed out waiting for Cloudflare Tunnel to connect".into());
        }
    };

    let direct_url = format!("{}/download/{}", tunnel_base_url, token);

    // Save active handle
    {
        let mut h_guard = get_manager().handles.lock().unwrap();
        h_guard.insert(
            share_id.clone(),
            ActiveShareHandle {
                stop_flag: stop_flag.clone(),
                bytes_sent: bytes_sent.clone(),
                child_process: Some(child),
                temp_file,
            },
        );
    }

    // Update share record with final URL and ready status
    {
        let mut s_guard = get_manager().shares.lock().unwrap();
        if let Some(s) = s_guard.get_mut(&share_id) {
            s.url = direct_url.clone();
            s.status = "ready".into();
        }
    }

    // If expiration configured, spawn background timer to auto-close
    if params.expiration_hours > 0 {
        let exp_id = share_id.clone();
        let exp_hours = params.expiration_hours;
        thread::spawn(move || {
            thread::sleep(Duration::from_secs((exp_hours as u64) * 3600));
            get_manager().stop_share(&exp_id);
        });
    }

    Ok((share_id, direct_url))
}

/// Single items are served as-is unless compression is on for that kind;
/// a password only protects an archive, so setting one always archives.
fn needs_archive(single: bool, is_dir: bool, params: &CreateShareParams) -> bool {
    let password_archive = !params.password.is_empty() && matches!(params.format.as_str(), "zip" | "7z");
    !single || password_archive || if is_dir { params.compress_folders } else { params.compress_files }
}

/// Where share archives are built: a 0700 folder in the user's cache dir —
/// on disk (the runtime dir is a small tmpfs; GB-sized shares would fail)
/// and not world-writable /tmp, where another user could pre-create it.
fn private_share_dir() -> std::io::Result<PathBuf> {
    use std::os::unix::fs::{DirBuilderExt, MetadataExt};
    let base = util::cache_home().join("loaf");
    std::fs::create_dir_all(&base)?;
    let dir = base.join(format!("share-{}", std::process::id()));
    match std::fs::DirBuilder::new().mode(0o700).create(&dir) {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
        Err(e) => return Err(e),
    }
    let m = std::fs::symlink_metadata(&dir)?;
    if !m.is_dir() || m.uid() != unsafe { libc::getuid() } || m.mode() & 0o077 != 0 {
        return Err(std::io::Error::new(std::io::ErrorKind::PermissionDenied, "unsafe share folder"));
    }
    Ok(dir)
}

/// Random 64 bits for share ids and link tokens (anyone holding the link
/// can download, so it must not be guessable from the time).
fn rand_u64() -> u64 {
    use std::io::Read;
    let mut b = [0u8; 8];
    if std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut b)).is_ok() {
        return u64::from_ne_bytes(b);
    }
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    now.as_nanos() as u64 ^ ((std::process::id() as u64) << 32)
}

fn run_file_server(
    listener: TcpListener,
    file_path: PathBuf,
    filename: String,
    token: String,
    throttle_kbps: u32,
    stop_flag: Arc<AtomicBool>,
    bytes_sent: Arc<AtomicU64>,
    share_id: String,
) {
    listener
        .set_nonblocking(true)
        .expect("Cannot set non-blocking");

    while !stop_flag.load(Ordering::Relaxed) {
        match listener.accept() {
            Ok((stream, _)) => {
                let file = file_path.clone();
                let fname = filename.clone();
                let tok = token.clone();
                let b_sent = bytes_sent.clone();
                let s_id = share_id.clone();

                thread::spawn(move || {
                    handle_http_client(stream, file, fname, tok, throttle_kbps, b_sent, s_id);
                });
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(50));
            }
            Err(_) => break,
        }
    }
}

fn handle_http_client(
    mut stream: TcpStream,
    file_path: PathBuf,
    filename: String,
    token: String,
    throttle_kbps: u32,
    bytes_sent: Arc<AtomicU64>,
    share_id: String,
) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(10)));
    let mut reader = BufReader::new(&stream);
    let mut request_line = String::new();
    if reader.read_line(&mut request_line).is_err() || request_line.is_empty() {
        return;
    }

    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 || parts[0] != "GET" && parts[0] != "HEAD" {
        let resp = "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n";
        let _ = stream.write_all(resp.as_bytes());
        return;
    }

    let is_head = parts[0] == "HEAD";
    let path = parts[1];
    let expected_path = format!("/download/{}", token);

    if path != expected_path && path != format!("{}/", expected_path) {
        let resp = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\n\r\nNot Found";
        let _ = stream.write_all(resp.as_bytes());
        return;
    }

    let Ok(mut file) = File::open(&file_path) else {
        let resp = "HTTP/1.1 500 Internal Error\r\nContent-Length: 0\r\n\r\n";
        let _ = stream.write_all(resp.as_bytes());
        return;
    };

    let total_size = file.metadata().map(|m| m.len()).unwrap_or(0);

    // Escape quotation marks in filename for Content-Disposition
    let safe_name = filename.replace('"', "\\\"");

    let headers = format!(
        "HTTP/1.1 200 OK\r\n\
        Content-Type: application/octet-stream\r\n\
        Content-Length: {}\r\n\
        Content-Disposition: attachment; filename=\"{}\"\r\n\
        Connection: close\r\n\r\n",
        total_size, safe_name
    );

    if stream.write_all(headers.as_bytes()).is_err() || is_head {
        return;
    }

    // Increment download count
    {
        let mut s_guard = get_manager().shares.lock().unwrap();
        if let Some(s) = s_guard.get_mut(&share_id) {
            s.download_count += 1;
        }
    }

    // Stream file data
    let chunk_size = 64 * 1024; // 64 KB
    let mut buf = vec![0u8; chunk_size];

    loop {
        let start = Instant::now();
        match file.read(&mut buf) {
            Ok(0) => break, // EOF
            Ok(n) => {
                if stream.write_all(&buf[..n]).is_err() {
                    break;
                }
                bytes_sent.fetch_add(n as u64, Ordering::Relaxed);

                // Throttling
                if throttle_kbps > 0 {
                    let target_duration = Duration::from_micros(
                        ((n as u64) * 8 * 1_000_000) / ((throttle_kbps as u64) * 1000 * 8),
                    );
                    let elapsed = start.elapsed();
                    if target_duration > elapsed {
                        thread::sleep(target_duration - elapsed);
                    }
                }
            }
            Err(_) => break,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn params(password: &str, format: &str) -> CreateShareParams {
        CreateShareParams {
            paths: vec![],
            compress_folders: false,
            compress_files: false,
            format: format.into(),
            password: password.into(),
            expiration_hours: 0,
            throttle_kbps: 0,
        }
    }

    #[test]
    fn a_password_always_protects_the_share() {
        assert!(!needs_archive(true, false, &params("", "zip")), "plain single file is served as-is");
        assert!(needs_archive(true, false, &params("secret", "zip")), "password must not be ignored");
        assert!(needs_archive(true, true, &params("secret", "7z")));
        assert!(needs_archive(false, false, &params("", "zip")), "several items are always archived");
    }

    #[test]
    fn share_dir_is_private_and_tokens_differ() {
        use std::os::unix::fs::PermissionsExt;
        let dir = private_share_dir().unwrap();
        assert_eq!(std::fs::metadata(&dir).unwrap().permissions().mode() & 0o777, 0o700);
        assert_ne!(rand_u64(), rand_u64());
        let _ = std::fs::remove_dir(&dir);
    }
}
