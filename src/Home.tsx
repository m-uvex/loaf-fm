import { useState } from "react";
import {
  Archive,
  ArrowDown,
  ArrowRight,
  ArrowUpRight,
  Check,
  Command,
  Copy,
  Palette,
  RotateCcw,
  HardDrive,
  LockKeyhole,
  Menu,
  Search,
  Sparkles,
  X,
} from "lucide-react";

const repo = "https://github.com/m-uvex/loaf-fm";
const installCommand = "curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash";

const features = [
  {
    icon: Palette,
    title: "Color with a little character.",
    body: "Pick from eight thoughtfully tuned palettes, or let Loaf build a dynamic palette from your wallpaper.",
    className: "feature-card--lilac",
    wide: true,
  },
  {
    icon: Search,
    title: "Get there in a blink.",
    body: "Filter a folder as you type, search into subfolders, and move between places with tabs or a roomy split view.",
    className: "feature-card--blue",
    wide: false,
  },
  {
    icon: RotateCcw,
    title: "Undo feels like a superpower.",
    body: "Rewind multiple moves, renames, creations, and deletions. Trash and overwrites are handled with care.",
    className: "feature-card--peach",
    wide: false,
  },
  {
    icon: HardDrive,
    title: "Know what your drives are up to.",
    body: "See storage pools and free space, then mount, unmount, or rename a drive from one calm dashboard.",
    className: "feature-card--butter",
    wide: true,
  },
  {
    icon: LockKeyhole,
    title: "Share via link",
    body: "Share files or folders privately with a link. Loaf streams directly from your device through a Cloudflare tunnel—no storage middleman, compression, paywalls, or file-size limits. Coming in v0.2.",
    className: "feature-card--share",
    wide: false,
  },
  {
    icon: Archive,
    title: "Archives, without the detour.",
    body: "Compress and extract in the background, including encrypted ZIPs. Check progress, cancel a job, and get back to your day.",
    className: "feature-card--mint",
    wide: false,
  },
];

function BreadMark() {
  return <span className="bread-mark" aria-hidden="true">🍞</span>;
}

export default function Home() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [copyError, setCopyError] = useState(false);

  const copyCommand = async () => {
    try {
      await navigator.clipboard.writeText(installCommand);
      setCopied(true);
      setCopyError(false);
      window.setTimeout(() => setCopied(false), 2400);
    } catch {
      const field = document.getElementById("install-command") as HTMLTextAreaElement | null;
      if (field) {
        field.focus();
        field.select();
        const copiedToClipboard = document.execCommand("copy");
        setCopied(copiedToClipboard);
        setCopyError(!copiedToClipboard);
        window.setTimeout(() => setCopied(false), 2400);
      }
    }
  };

  const closeMenu = () => setMenuOpen(false);

  return (
    <main className="site-shell">
      <a className="skip-link" href="#main-content">Skip to content</a>

      <header className="topbar">
        <div className="topbar-inner">
          <a className="brand" href="#top" aria-label="Loaf home" onClick={closeMenu}>
            <BreadMark />
            <span>Loaf</span>
          </a>
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
          <nav id="primary-navigation" className={`primary-nav${menuOpen ? " is-open" : ""}`} aria-label="Main navigation">
            <a href="#features" onClick={closeMenu}>The good bits</a>
            <a href="#install" onClick={closeMenu}>Installation</a>
            <a className="nav-cta" href={repo} target="_blank" rel="noreferrer" onClick={closeMenu}>
              Visit the repo <ArrowUpRight size={16} aria-hidden="true" />
            </a>
          </nav>
        </div>
      </header>

      <div id="top" className="hero-wrap">
        <section id="main-content" className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <h1 id="hero-title">A softer place<br />for <span>all your files.</span></h1>
            <p className="hero-description">Meet Loaf: A fast, good looking and feature-stuffed file manager with no compromises</p>
            <div className="hero-actions">
              <a className="button button-primary" href="#install">Find your way in <ArrowRight size={18} aria-hidden="true" /></a>
              <a className="button button-quiet" href={repo} target="_blank" rel="noreferrer">Take a peek at the code <ArrowUpRight size={16} aria-hidden="true" /></a>
            </div>
          </div>

          <div className="hero-art" aria-label="Preview of the Loaf desktop application">
            <div className="screenshot-frame">
              <img
                className="product-shot"
                src="/loaf-preview.webp"
                alt="Loaf's Home folder in a wide grid view, with the Linux sidebar and selected folders and files."
                fetchPriority="high"
                width="1920"
                height="1080"
              />
            </div>
          </div>
        </section>
      </div>

      <section id="features" className="features-section section-pad" aria-labelledby="features-title">
        <div className="section-heading">
          <div>
            <h2 id="features-title">File keeping,<br /><span>with feeling.</span></h2>
          </div>
          <p>Thoughtful touches for the everyday stuff: making a folder, finding that one file, and keeping your drives in order.</p>
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

      <section className="alpha-section section-pad" aria-labelledby="alpha-title">
        <div className="alpha-note">
          <div className="alpha-symbol" aria-hidden="true"><Sparkles size={24} /></div>
          <div className="alpha-copy"><h2 id="alpha-title">A work in progress.<br /><span>And a welcome one.</span></h2><p>Loaf is at a very early alpha stage, so you may run into a few missing pieces. Contributions, ideas, and kind bug reports are welcome.</p></div>
          <a className="button button-outline" href={`${repo}/issues`} target="_blank" rel="noreferrer">Say hello on GitHub <ArrowUpRight size={16} aria-hidden="true" /></a>
        </div>
      </section>

      <section id="install" className="install-section section-pad" aria-labelledby="install-title">
        <div className="install-panel">
          <div className="install-copy">
            <h2 id="install-title">Try it first.<br /><span>Install when ready.</span></h2>
            <p>One command opens Loaf's interactive installer. Choose Try to run it temporarily, or Install to set up the latest stable release.</p>
            <p className="nix-note">Other distributions use a universal tarball. NixOS users can follow the manual Nix guide.</p>
          </div>
          <div className="installer-card">
            <div className="installer-card-header">
              <span className="installer-card-title"><span className="installer-card-icon"><Command size={18} aria-hidden="true" /></span> Interactive installer</span>
              <span className="terminal-dots" aria-hidden="true"><i /><i /><i /></span>
            </div>
            <div className="command-line">
              <span className="prompt-symbol" aria-hidden="true">$</span>
              <textarea id="install-command" aria-label="Loaf installer command for Linux" readOnly rows={2} value={installCommand} onFocus={(event) => event.currentTarget.select()} spellCheck={false} />
            </div>
            <div className="installer-actions">
              <button className={`copy-button${copied ? " is-copied" : ""}`} type="button" onClick={copyCommand} aria-label={copied ? "Installer command copied" : "Copy installer command"}>
                {copied ? <Check size={17} aria-hidden="true" /> : <Copy size={16} aria-hidden="true" />}{copied ? "Copied" : "Copy command"}
              </button>
              <a className="install-docs" href={`${repo}#installation`} target="_blank" rel="noreferrer">All install options <ArrowUpRight size={15} aria-hidden="true" /></a>
            </div>
            <p className="copy-status" aria-live="polite">{copied ? "Ready when you are." : copyError ? "Select the command above to copy it." : "Paste into a terminal, then choose Try or Install."}</p>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-inner">
          <a className="brand footer-brand" href="#top"><BreadMark /><span>Loaf</span></a>
          <p>Toasted to perfection</p>
          <div className="footer-links">
            <a href={repo} target="_blank" rel="noreferrer">GitHub <ArrowUpRight size={14} aria-hidden="true" /></a>
            <a href={`${repo}/blob/main/LICENSE`} target="_blank" rel="noreferrer">MIT License</a>
            <a href={`${repo}/blob/main/CONTRIBUTING.md`} target="_blank" rel="noreferrer">Contribute</a>
          </div>
          <a className="back-top" href="#top" aria-label="Back to top"><ArrowDown size={16} className="back-top-arrow" /></a>
        </div>
      </footer>
    </main>
  );
}
