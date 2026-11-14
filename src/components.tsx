import { useState } from "react";
import { ArrowUp, ArrowUpRight, Check, Copy } from "lucide-react";

export const repo = "https://github.com/m-uvex/loaf-fm";
export const discord = "https://discord.gg/VCZf2AqCAG";
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

export function FooterIslands() {
  return (
    <footer className="footer-islands">
      <div className="island island-brand">
        <Brand />
        <span className="island-meta">Rust &amp; Qt6 · MIT</span>
      </div>
      <nav className="island island-links" aria-label="Footer">
        <a href={repo} target="_blank" rel="noreferrer">GitHub</a>
        <a href={`${repo}/blob/main/CONTRIBUTING.md`} target="_blank" rel="noreferrer">Contribute</a>
        <a href={discord} target="_blank" rel="noreferrer">Discord</a>
        <a href={`${repo}/blob/main/LICENSE`} target="_blank" rel="noreferrer">License</a>
        <a className="island-top" href="#top" aria-label="Back to top"><ArrowUp size={16} aria-hidden="true" /></a>
      </nav>
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
        <textarea id="install-command" aria-label="Loaf installer command for Linux" readOnly rows={2} value={installCommand} onFocus={(event) => event.currentTarget.select()} spellCheck={false} />
      </div>
      <div className="installer-actions">
        <button className={`copy-button${copied ? " is-copied" : ""}`} type="button" onClick={copyCommand} aria-label={copied ? "Installer command copied" : "Copy installer command"}>
          {copied ? <Check size={17} aria-hidden="true" /> : <Copy size={16} aria-hidden="true" />}
          {copied ? "Copied" : "Copy command"}
        </button>
        {showOptionsLink && (
          <a className="install-docs" href="/install.html">All install options <ArrowUpRight size={15} aria-hidden="true" /></a>
        )}
      </div>
      <p className="copy-status" aria-live="polite">
        {copied
          ? "# Copied. Paste it into a terminal, then choose Try or Install."
          : copyError
            ? "# Select the command above to copy it."
            : "# Paste into a terminal, then choose Try or Install."}
      </p>
    </div>
  );
}
