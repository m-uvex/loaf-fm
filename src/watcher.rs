//! inotify based change notifications.
//!
//! * [`DirWatcher`] watches the folder being shown and reports (debounced)
//!   that it changed, so the view can refresh without polling and changes
//!   made by other programs appear.
//! * [`DeviceWatcher`] reports drives being plugged in / removed and
//!   mounts changing, for the "This PC" page.
//!
//! Callbacks run on the watcher's own thread.

use std::ffi::CString;
use std::os::unix::ffi::OsStrExt;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

const DIR_MASK: u32 = libc::IN_CREATE
    | libc::IN_DELETE
    | libc::IN_MOVED_FROM
    | libc::IN_MOVED_TO
    | libc::IN_CLOSE_WRITE
    // No IN_MODIFY: it fires for every write while a file grows (downloads),
    // rescanning the folder nonstop. Trade-off: a file still being written
    // shows its new size once it is closed.
    | libc::IN_ATTRIB
    | libc::IN_DELETE_SELF
    | libc::IN_MOVE_SELF;

/// Reads all pending events; true when one of them is a real change for
/// watch descriptor `wd` (stale descriptors and IN_IGNORED are skipped).
fn drain_events(fd: i32, wd: i32) -> bool {
    let mut relevant = false;
    let mut buf = [0u8; 8192];
    let header = std::mem::size_of::<libc::inotify_event>();
    loop {
        let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
        if n <= 0 {
            break;
        }
        let n = n as usize;
        let mut off = 0;
        while off + header <= n {
            let ev: libc::inotify_event = unsafe { std::ptr::read_unaligned(buf[off..].as_ptr() as *const libc::inotify_event) };
            if ev.wd == wd && ev.mask & libc::IN_IGNORED == 0 {
                relevant = true;
            }
            off += header + ev.len as usize;
        }
    }
    relevant
}

fn drain(fd: i32) {
    let mut buf = [0u8; 8192];
    loop {
        let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
        if n <= 0 {
            break;
        }
    }
}

/// eventfd used to wake a watcher thread blocked in poll() so it can stop.
fn new_waker() -> i32 {
    unsafe { libc::eventfd(0, libc::EFD_NONBLOCK | libc::EFD_CLOEXEC) }
}

fn wake(efd: i32) {
    let one: u64 = 1;
    unsafe {
        libc::write(efd, &one as *const u64 as *const libc::c_void, 8);
    }
}

/// poll() timeout: sleep until an event arrives, but tick while a change is pending.
fn timeout_ms(pending: bool) -> i32 {
    if pending { 50 } else { -1 }
}

pub struct DirWatcher {
    fd: i32,
    efd: i32,
    wd: Arc<AtomicI32>,
    stop: Arc<AtomicBool>,
    /// Minimum gap between two notifications (ms); raised for huge folders.
    pub min_interval_ms: Arc<AtomicU64>,
    thread: Option<JoinHandle<()>>,
}

impl DirWatcher {
    /// Starts the watcher thread. `on_change` is called (from that thread)
    /// at most once per quiet period after something changed.
    pub fn new(on_change: impl Fn() + Send + 'static) -> Option<Self> {
        let fd = unsafe { libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC) };
        if fd < 0 {
            return None;
        }
        let efd = new_waker();
        if efd < 0 {
            unsafe { libc::close(fd) };
            return None;
        }
        let stop = Arc::new(AtomicBool::new(false));
        let wd = Arc::new(AtomicI32::new(-1));
        let min_interval = Arc::new(AtomicU64::new(250));
        let (stop_t, min_t, wd_t) = (stop.clone(), min_interval.clone(), wd.clone());
        let thread = std::thread::Builder::new()
            .name("loaf-dirwatch".into())
            .spawn(move || {
                let mut first_dirty: Option<Instant> = None;
                let mut last_event = Instant::now();
                let mut last_fire = Instant::now() - Duration::from_secs(10);
                while !stop_t.load(Ordering::Relaxed) {
                    let mut fds = [
                        libc::pollfd { fd, events: libc::POLLIN, revents: 0 },
                        libc::pollfd { fd: efd, events: libc::POLLIN, revents: 0 },
                    ];
                    let ready = unsafe { libc::poll(fds.as_mut_ptr(), 2, timeout_ms(first_dirty.is_some())) };
                    if ready > 0 && fds[0].revents & libc::POLLIN != 0 && drain_events(fd, wd_t.load(Ordering::SeqCst)) {
                        last_event = Instant::now();
                        first_dirty.get_or_insert(last_event);
                    }
                    if let Some(first) = first_dirty {
                        let min = Duration::from_millis(min_t.load(Ordering::Relaxed));
                        let quiet = last_event.elapsed() >= Duration::from_millis(120);
                        // Keep refreshing during a long copy, but not too often.
                        let overdue = first.elapsed() >= Duration::from_millis(800);
                        if (quiet || overdue) && last_fire.elapsed() >= min {
                            first_dirty = None;
                            last_fire = Instant::now();
                            on_change();
                        }
                    }
                }
            })
            .ok()?;
        Some(DirWatcher { fd, efd, wd, stop, min_interval_ms: min_interval, thread: Some(thread) })
    }

    /// Switches the watch to `dir` (only one folder is watched at a time).
    pub fn watch(&self, dir: &Path) {
        let old = self.wd.swap(-1, Ordering::SeqCst);
        if old >= 0 {
            unsafe {
                libc::inotify_rm_watch(self.fd, old);
            }
        }
        let Ok(c) = CString::new(dir.as_os_str().as_bytes()) else { return };
        let wd = unsafe { libc::inotify_add_watch(self.fd, c.as_ptr(), DIR_MASK) };
        self.wd.store(wd, Ordering::SeqCst);
    }

    pub fn unwatch(&self) {
        let old = self.wd.swap(-1, Ordering::SeqCst);
        if old >= 0 {
            unsafe {
                libc::inotify_rm_watch(self.fd, old);
            }
        }
    }
}

impl Drop for DirWatcher {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        wake(self.efd);
        if let Some(t) = self.thread.take() {
            let _ = t.join();
        }
        unsafe {
            libc::close(self.fd);
            libc::close(self.efd);
        }
    }
}

/// Watches `/dev/disk/by-uuid` (drives appearing/disappearing) and
/// `/proc/self/mountinfo` (mounts changing).
pub struct DeviceWatcher {
    efd: i32,
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}

impl DeviceWatcher {
    pub fn new(on_change: impl Fn() + Send + 'static) -> Option<Self> {
        let ino = unsafe { libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC) };
        if ino < 0 {
            return None;
        }
        for dir in ["/dev/disk/by-uuid", "/dev/disk/by-id", "/dev"] {
            if let Ok(c) = CString::new(dir) {
                let wd = unsafe {
                    libc::inotify_add_watch(ino, c.as_ptr(), libc::IN_CREATE | libc::IN_DELETE | libc::IN_ONLYDIR)
                };
                if wd >= 0 {
                    break;
                }
            }
        }
        let mounts = CString::new("/proc/self/mountinfo").ok()?;
        let mfd = unsafe { libc::open(mounts.as_ptr(), libc::O_RDONLY | libc::O_CLOEXEC) };
        let efd = new_waker();
        if efd < 0 {
            unsafe {
                libc::close(ino);
                if mfd >= 0 {
                    libc::close(mfd);
                }
            }
            return None;
        }
        let stop = Arc::new(AtomicBool::new(false));
        let stop_t = stop.clone();
        let thread = std::thread::Builder::new()
            .name("loaf-devwatch".into())
            .spawn(move || {
                let mut dirty: Option<Instant> = None;
                while !stop_t.load(Ordering::Relaxed) {
                    // A negative fd is ignored by poll(), so a missing mountinfo is fine.
                    let mut fds = [
                        libc::pollfd { fd: ino, events: libc::POLLIN, revents: 0 },
                        libc::pollfd { fd: mfd, events: libc::POLLPRI, revents: 0 },
                        libc::pollfd { fd: efd, events: libc::POLLIN, revents: 0 },
                    ];
                    let n = if mfd >= 0 { 2 } else { 1 };
                    let ready = unsafe { libc::poll(fds.as_mut_ptr(), 3, timeout_ms(dirty.is_some())) };
                    if ready > 0 {
                        if fds[0].revents & libc::POLLIN != 0 {
                            drain(ino);
                            dirty.get_or_insert(Instant::now());
                        }
                        if n == 2 && fds[1].revents & (libc::POLLPRI | libc::POLLERR) != 0 {
                            // The kernel flags a mount table change; re-arm by seeking.
                            unsafe {
                                libc::lseek(mfd, 0, libc::SEEK_SET);
                            }
                            let mut buf = [0u8; 4096];
                            while unsafe { libc::read(mfd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) } > 0 {}
                            dirty.get_or_insert(Instant::now());
                        }
                    }
                    // udev creates several nodes per drive: wait a moment.
                    if dirty.map(|d| d.elapsed() >= Duration::from_millis(400)).unwrap_or(false) {
                        dirty = None;
                        on_change();
                    }
                }
                unsafe {
                    libc::close(ino);
                    if mfd >= 0 {
                        libc::close(mfd);
                    }
                }
            })
            .ok()?;
        Some(DeviceWatcher { efd, stop, thread: Some(thread) })
    }
}

impl Drop for DeviceWatcher {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        wake(self.efd);
        if let Some(t) = self.thread.take() {
            let _ = t.join();
        }
        unsafe {
            libc::close(self.efd);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;

    #[test]
    fn notices_changes_and_debounces() {
        let d = std::env::temp_dir().join(format!("loaf-watch-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        let hits = Arc::new(AtomicUsize::new(0));
        let h = hits.clone();
        let w = DirWatcher::new(move || {
            h.fetch_add(1, Ordering::SeqCst);
        })
        .unwrap();
        w.watch(&d);
        for i in 0..50 {
            std::fs::write(d.join(format!("f{}", i)), b"x").unwrap();
        }
        std::thread::sleep(Duration::from_millis(600));
        let n = hits.load(Ordering::SeqCst);
        assert!(n >= 1 && n <= 2, "50 writes coalesce into one or two refreshes, got {}", n);

        // After switching folders, changes in the old one are ignored.
        let other = d.join("sub");
        std::fs::create_dir_all(&other).unwrap();
        std::thread::sleep(Duration::from_millis(400));
        w.watch(&other);
        let before = hits.load(Ordering::SeqCst);
        std::fs::write(d.join("ignored"), b"x").unwrap();
        std::thread::sleep(Duration::from_millis(400));
        assert_eq!(hits.load(Ordering::SeqCst), before);
        std::fs::write(other.join("seen"), b"x").unwrap();
        std::thread::sleep(Duration::from_millis(500));
        assert!(hits.load(Ordering::SeqCst) > before);
        drop(w);
        std::fs::remove_dir_all(&d).unwrap();
    }
}
