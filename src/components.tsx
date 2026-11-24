import { useEffect, useRef, useState } from "react";
import {
  Copy,
  Check,
  ArrowUpRight,
  ArrowRight,
  Menu,
  X,
} from "lucide-react";

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
        <a className="nav-cta" href="/install.html" onClick={closeMenu}>
          Install <ArrowRight size={16} aria-hidden="true" />
        </a>
      </div>
    </nav>
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
