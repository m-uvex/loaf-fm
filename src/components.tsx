import { useEffect, useState } from "react";
import {
  ArrowUp,
  Copy,
  Check,
  ArrowUpRight,
  ArrowRight,
  Github,
  GitPullRequest,
  Monitor,
  Sun,
  Moon,
  Menu,
  X,
} from "lucide-react";
import type { ThemeMode } from "./theme";
import { applyTheme, getMode } from "./theme";

export const repo = "https://github.com/m-uvex/loaf-fm";
export const discord = "https://discord.gg/VCZf2AqCAG";
export const releasesUrl = `${repo}/releases`;
export const installCommand =
  "curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash";

export function Brand() {
  return (
    <a className="brand" href="/" aria-label="Loaf home">
      <img className="brand-mark" src="/loaf-badge.png" alt="" width={34} height={34} />
      <span>Loaf</span>
    </a>
  );
}

const navLinks = [
  { href: "/#features", label: "The good bits" },
  { href: "/install.html", label: "Installation" },
  { href: "/gallery.html", label: "Gallery" },
  { href: "/#get-involved", label: "Get involved" },
];

export function TopNav() {
  const [menuOpen, setMenuOpen] = useState(false);
  const closeMenu = () => setMenuOpen(false);

  return (
    <nav className="hero-nav" aria-label="Site">
      <Brand />
      <button
        className="menu-toggle"
        type="button"
        aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"}
        aria-expanded={menuOpen}
        aria-controls="site-navigation"
        onClick={() => setMenuOpen((open) => !open)}
      >
        {menuOpen ? <X size={21} aria-hidden="true" /> : <Menu size={21} aria-hidden="true" />}
      </button>
      <div id="site-navigation" className={`primary-nav${menuOpen ? " is-open" : ""}`}>
        {navLinks.map(({ href, label }) => (
          <a key={href} href={href} onClick={closeMenu}>{label}</a>
        ))}
        <a className="nav-cta" href={repo} target="_blank" rel="noreferrer" onClick={closeMenu}>
          Visit the repo <ArrowUpRight size={16} aria-hidden="true" />
        </a>
      </div>
    </nav>
  );
}

function DiscordGlyph() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" fillRule="evenodd" aria-hidden="true">
      <path d="M12 3.6C7.6 3.6 4 6.5 4 10.3c0 2.3 1.4 4.4 3.4 5.6l-.7 3.1 2.9-1.5c.8.2 1.6.3 2.4.3 4.4 0 8-2.9 8-6.7S16.4 3.6 12 3.6ZM8.9 12.3a1.55 1.55 0 1 1 0-3.1 1.55 1.55 0 0 1 0 3.1Zm6.2 0a1.55 1.55 0 1 1 0-3.1 1.55 1.55 0 0 1 0 3.1Z" />
    </svg>
  );
}

const themeIcons = { auto: Monitor, light: Sun, dark: Moon } as const;
const themeLabels = { auto: "Auto", light: "Light", dark: "Dark" } as const;

export function FooterIslands() {
  const [mode, setMode] = useState<ThemeMode>(() => getMode());

  useEffect(() => {
    const sync = () => setMode(getMode());
    window.addEventListener("loaf-theme-change", sync);
    return () => window.removeEventListener("loaf-theme-change", sync);
  }, []);

  const cycle = () => {
    const next = mode === "auto" ? "light" : mode === "light" ? "dark" : "auto";
    applyTheme(next);
  };

  const ThemeIcon = themeIcons[mode];

  return (
    <footer className="footer-islands">
      <div className="island island-bar">
        <a className="brand foot-brand" href="/" aria-label="Loaf home">
          <img className="brand-mark" src="/loaf-badge.png" alt="" width={28} height={28} />
          <span className="foot-tagline">Toasted to perfection</span>
        </a>
        <nav className="icon-row" aria-label="Footer">
          <a className="icon-pill" href={repo} target="_blank" rel="noreferrer" aria-label="Loaf on GitHub">
            <Github size={16} aria-hidden="true" />
            <span>GitHub</span>
          </a>
          <a className="icon-pill" href={discord} target="_blank" rel="noreferrer" aria-label="Loaf on Discord">
            <DiscordGlyph />
            <span>Discord</span>
          </a>
          <a
            className="icon-pill"
            href={`${repo}/blob/main/CONTRIBUTING.md`}
            target="_blank"
            rel="noreferrer"
            aria-label="Contribute to Loaf"
          >
            <GitPullRequest size={16} aria-hidden="true" />
            <span>Contribute</span>
          </a>
          <span className="icon-sep" aria-hidden="true" />
          <button
            className="icon-pill"
            type="button"
            onClick={cycle}
            aria-label={`Theme: ${themeLabels[mode]} (auto follows your system). Click to change.`}
            title={`Theme: ${themeLabels[mode]} — click to change`}
          >
            <ThemeIcon size={16} aria-hidden="true" />
            <span>{themeLabels[mode]}</span>
          </button>
          <a className="icon-pill" href="#top" aria-label="Back to top">
            <ArrowUp size={16} aria-hidden="true" />
            <span>Top</span>
          </a>
        </nav>
      </div>
    </footer>
  );
}

export function CommandCard({ showOptionsLink = true }: { showOptionsLink?: boolean }) {
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

  return (
    <div className="installer-card">
      <div className="command-line">
        <span className="prompt-symbol" aria-hidden="true">$</span>
        <textarea
          id="install-command"
          aria-label="Loaf installer command for Linux"
          readOnly
          rows={3}
          value={`${installCommand}\n# Paste into a terminal, then choose Try or Install.`}
          onFocus={(event) => event.currentTarget.select()}
          spellCheck={false}
        />
        <button
          className={`command-copy${copied ? " is-copied" : ""}`}
          type="button"
          onClick={copyCommand}
          aria-label={copied ? "Installer command copied" : "Copy installer command"}
        >
          {copied ? <Check size={16} aria-hidden="true" /> : <Copy size={15} aria-hidden="true" />}
        </button>
      </div>
      {showOptionsLink && (
        <div className="installer-actions">
          <a className="button button-dark btn-sml" href={releasesUrl} target="_blank" rel="noreferrer">
            GitHub releases <ArrowUpRight size={15} aria-hidden="true" />
          </a>
          <a className="button button-soft btn-sml" href="/install.html">
            Installation <ArrowRight size={15} aria-hidden="true" />
          </a>
        </div>
      )}
      <span className="sr-only" aria-live="polite">
        {copied ? "Copied to clipboard." : copyError ? "Select the command to copy it." : ""}
      </span>
    </div>
  );
}

export function MiniCommand({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      /* clipboard unavailable */
    }
  };
  return (
    <div className="mini-command">
      <span className="prompt-symbol" aria-hidden="true">$</span>
      <code>{code}</code>
      <button
        className={`term-copy${copied ? " is-copied" : ""}`}
        type="button"
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy command"}
      >
        {copied ? <Check size={14} aria-hidden="true" /> : <Copy size={13} aria-hidden="true" />}
      </button>
    </div>
  );
}

export function Snippet({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      /* clipboard unavailable */
    }
  };
  return (
    <div className="alt-pre-wrap">
      <pre className="alt-pre"><code>{code}</code></pre>
      <button
        className={`term-copy pre-copy${copied ? " is-copied" : ""}`}
        type="button"
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy snippet"}
      >
        {copied ? <Check size={14} aria-hidden="true" /> : <Copy size={13} aria-hidden="true" />}
      </button>
    </div>
  );
}
