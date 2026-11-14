import { useRef, useState } from "react";
import {
  Archive,
  AppWindow,
  ArrowRight,
  ArrowUpRight,
  Eye,
  HardDrive,
  Menu,
  Palette,
  Radio,
  Sparkles,
  Users,
  X,
} from "lucide-react";
import { Brand, CommandCard, FooterIslands, repo, discord } from "./components";

const features = [
  {
    icon: AppWindow,
    title: "A portal for the whole desktop.",
    body: "Run loaf --portal once and Loaf takes over every system open and save dialog, including in Flatpaks. No extra dialogs, no excuses.",
    className: "feature-card--lilac",
    wide: true,
  },
  {
    icon: Eye,
    title: "Press space, see everything.",
    body: "Images, audio, video, PDFs, fonts: preview any file in place without launching anything else.",
    className: "feature-card--blue",
    wide: false,
  },
  {
    icon: Radio,
    title: "Beam files over the air.",
    body: "Generate a link and push files to any phone or laptop on your network. Nothing uploads to the cloud, no size limits, no account.",
    className: "feature-card--peach",
    wide: false,
  },
  {
    icon: Archive,
    title: "Archives open like folders.",
    body: "Browse, extract and create .zip, .tar.* and .7z right in the tree. Background jobs, progress, cancel, encrypted ZIPs.",
    className: "feature-card--butter",
    wide: true,
  },
  {
    icon: HardDrive,
    title: "This PC, all on one shelf.",
    body: "Disks, partitions and network shares with usage bars, mount and eject buttons, frequent folders and a name you can change.",
    className: "feature-card--mint",
    wide: false,
  },
  {
    icon: Palette,
    title: "Themes that match your wallpaper.",
    body: "Eight tuned palettes or a live accent pulled from your wallpaper, plus sliders for window and panel opacity. Low-power mode quiets it all on battery.",
    className: "feature-card--share",
    wide: true,
  },
];

export default function Home() {
  const [menuOpen, setMenuOpen] = useState(false);
  const artRef = useRef<HTMLDivElement | null>(null);

  const tilt = (e: React.MouseEvent) => {
    const el = artRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const px = (e.clientX - r.left) / r.width - 0.5;
    const py = (e.clientY - r.top) / r.height - 0.5;
    el.style.setProperty("--ry", `${px * 8}deg`);
    el.style.setProperty("--rx", `${-py * 6}deg`);
  };
  const resetTilt = () => {
    const el = artRef.current;
    if (!el) return;
    el.style.setProperty("--rx", "0deg");
    el.style.setProperty("--ry", "0deg");
  };

  const closeMenu = () => setMenuOpen(false);

  return (
    <main id="top" className="site-shell">
      <a className="skip-link" href="#main-content">Skip to content</a>

      <div className="hero-wrap">
        <nav className="hero-nav" aria-label="Site">
          <Brand />
          <button
            className="menu-toggle"
            type="button"
            aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"}
            aria-expanded={menuOpen}
            aria-controls="primary-navigation"
            onClick={() => setMenuOpen((open) => !open)}
          >
            {menuOpen ? <X size={21} /> : <Menu size={21} />}
          </button>
          <div id="primary-navigation" className={`primary-nav${menuOpen ? " is-open" : ""}`}>
            <a href="#features" onClick={closeMenu}>The good bits</a>
            <a href="/install.html" onClick={closeMenu}>Installation</a>
            <a href="#get-involved" onClick={closeMenu}>Get involved</a>
            <a className="nav-cta" href={repo} target="_blank" rel="noreferrer" onClick={closeMenu}>
              Visit the repo <ArrowUpRight size={16} aria-hidden="true" />
            </a>
          </div>
        </nav>

        <section id="main-content" className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <h1 id="hero-title">Your file manager,<br /><span>reimagined.</span></h1>
            <p className="hero-description">A fast, feature-stuffed file manager for Linux. Rust under the hood, Qt6 up top, Material 3 Expressive everywhere.</p>
            <div className="hero-actions">
              <a className="button button-primary" href="/install.html">Get Loaf <ArrowRight size={18} aria-hidden="true" /></a>
              <a className="button button-quiet" href={repo} target="_blank" rel="noreferrer">Browse the code <ArrowUpRight size={16} aria-hidden="true" /></a>
            </div>
          </div>

          <div className="hero-art" onMouseMove={tilt} onMouseLeave={resetTilt}>
            <div className="shot-tilt" ref={artRef}>
              <div className="shot-float">
                <span className="shot-chip"><Sparkles size={14} aria-hidden="true" /> Now transparent!</span>
                <img
                  className="product-shot"
                  src="/loaf-thispc.png"
                  alt="Loaf's This PC tab: drive pool usage, mount buttons for HDD and ISOs, the root partition at 84 percent, and frequently used folders."
                  fetchPriority="high"
                  width="1600"
                  height="900"
                  draggable={false}
                />
              </div>
            </div>
          </div>
        </section>
      </div>

      <section id="features" className="features-section section-pad" aria-labelledby="features-title">
        <div className="section-heading">
          <div>
            <p className="section-eyebrow">Features</p>
            <h2 id="features-title">The good bits</h2>
          </div>
        </div>

        <div className="feature-grid">
          {features.map(({ icon: Icon, title, body, className, wide }) => (
            <article key={title} className={`feature-card ${className}${wide ? " feature-card--wide" : ""}`}>
              <div className="feature-copy">
                <div className="feature-title-row">
                  <span className="feature-icon"><Icon size={24} strokeWidth={1.8} aria-hidden="true" /></span>
                  <h3>{title}</h3>
                </div>
                <p>{body}</p>
              </div>
              <Icon className="feature-ambient" size={176} strokeWidth={1.1} aria-hidden="true" />
            </article>
          ))}
        </div>
      </section>

      <section id="get-involved" className="alpha-section section-pad" aria-labelledby="involved-title">
        <div className="alpha-note">
          <div className="alpha-symbol" aria-hidden="true"><Users size={24} /></div>
          <div className="alpha-copy">
            <h2 id="involved-title">Get involved.</h2>
            <p>Loaf is young and moving fast. File an issue, send a pull request, or just hang out: the Discord server is where the builds happen, the releases get announced, and the best ideas win.</p>
          </div>
          <div className="involved-actions">
            <a className="button button-outline" href={`${repo}/blob/main/CONTRIBUTING.md`} target="_blank" rel="noreferrer">Contribute <ArrowUpRight size={16} aria-hidden="true" /></a>
            <a className="button button-primary" href={discord} target="_blank" rel="noreferrer">Join the Discord <ArrowUpRight size={16} aria-hidden="true" /></a>
          </div>
        </div>
      </section>

      <section id="install" className="install-section section-pad" aria-labelledby="install-title">
        <div className="install-panel">
          <div className="install-copy">
            <h2 id="install-title">Install it.<br /><span>Pick Try or Install.</span></h2>
            <p>One command opens Loaf's interactive installer. Choose Try to run it temporarily, or Install to set up the latest stable release.</p>
            <p className="nix-note">Other distributions use a universal tarball. NixOS users can follow the manual Nix guide.</p>
          </div>
          <CommandCard />
        </div>
      </section>

      <FooterIslands />
    </main>
  );
}
