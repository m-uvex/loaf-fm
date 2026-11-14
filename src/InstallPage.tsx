import { useEffect, useState } from "react";
import { ArrowUpRight, Download, RefreshCw, TriangleAlert } from "lucide-react";
import { Brand, CommandCard, FooterIslands, repo } from "./components";
import { Markdown } from "./markdown";

const API = "https://api.github.com/repos/m-uvex/loaf-fm/releases?per_page=6";

type Asset = { name: string; browser_download_url: string; size: number };
type Release = {
  tag_name: string;
  name: string;
  prerelease: boolean;
  draft: boolean;
  published_at: string;
  body: string;
  html_url: string;
  assets: Asset[];
};

const WANTED = [
  { label: "AppImage", match: (n: string) => n.endsWith(".AppImage") },
  { label: ".deb", match: (n: string) => n.endsWith(".deb") },
  { label: ".rpm", match: (n: string) => n.endsWith(".rpm") },
  { label: "pacman", match: (n: string) => n.endsWith(".pkg.tar.zst") },
  { label: "tarball", match: (n: string) => n.endsWith(".tar.gz") },
];

function fmtSize(bytes: number) {
  if (!bytes) return "";
  return bytes >= 1024 * 1024
    ? `${(bytes / 1024 / 1024).toFixed(1)} MB`
    : `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

function fmtDate(iso: string) {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? ""
    : d.toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });
}

function ChannelCard({ release, kind }: { release: Release; kind: "stable" | "nightly" }) {
  const assets = WANTED.map((w) => ({ label: w.label, asset: release.assets.find((a) => w.match(a.name)) })).filter(
    (x): x is { label: string; asset: Asset } => Boolean(x.asset),
  );
  return (
    <section className={`channel-card channel-card--${kind}`} aria-labelledby={`channel-${kind}`}>
      <header className="channel-head">
        <span className={`channel-pill channel-pill--${kind}`}>{kind === "stable" ? "Stable" : "Nightly"}</span>
        <h2 id={`channel-${kind}`}>{release.tag_name}</h2>
        <p className="channel-date">
          {fmtDate(release.published_at)}
          {" · "}
          <a href={release.html_url} target="_blank" rel="noreferrer">
            Release notes <ArrowUpRight size={13} aria-hidden="true" />
          </a>
        </p>
        {kind === "nightly" && (
          <p className="nightly-note">Every merge to main, built and published automatically. The freshest fixes and the freshest bugs.</p>
        )}
      </header>
      <div className="asset-grid">
        {assets.map(({ label, asset }) => (
          <a key={label} className="asset-button" href={asset.browser_download_url} target="_blank" rel="noreferrer">
            <Download size={15} aria-hidden="true" />
            <span>{label}</span>
            <small>{fmtSize(asset.size)}</small>
          </a>
        ))}
      </div>
      {kind === "nightly" && (
        <div className="nightly-commands">
          <div className="mini-command">
            <span className="prompt-symbol" aria-hidden="true">$</span>
            <code>curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash -s -- --nightly</code>
          </div>
          <div className="mini-command">
            <span className="prompt-symbol" aria-hidden="true">$</span>
            <code>nix run github:m-uvex/loaf-fm/nightly</code>
          </div>
        </div>
      )}
      <details className="changelog">
        <summary>Changelog</summary>
        <div className="changelog-body">
          <Markdown source={release.body || "No notes for this release yet."} />
        </div>
      </details>
    </section>
  );
}

export default function Install() {
  const [releases, setReleases] = useState<Release[] | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    fetch(API)
      .then((r) => {
        if (!r.ok) throw new Error(String(r.status));
        return r.json();
      })
      .then((data: Release[]) => setReleases(Array.isArray(data) ? data : []))
      .catch(() => setFailed(true));
  }, []);

  const stable = releases?.find((r) => !r.prerelease && !r.draft) ?? null;
  const nightly = releases?.find((r) => !r.draft && r.prerelease) ?? null;
  const older = (releases ?? []).filter((r) => !r.prerelease && !r.draft && r.tag_name !== stable?.tag_name).slice(0, 3);

  return (
    <main id="top" className="site-shell install-page">
      <a className="skip-link" href="#install-content">Skip to content</a>

      <div className="hero-wrap install-hero">
        <nav className="hero-nav" aria-label="Site">
          <Brand />
          <div className="hero-nav-links">
            <a href="/">Home</a>
            <a href="#channels">Channels</a>
            <a href="#alternatives">Other ways in</a>
          </div>
          <a className="nav-cta" href={repo} target="_blank" rel="noreferrer">
            Visit the repo <ArrowUpRight size={16} aria-hidden="true" />
          </a>
        </nav>

        <section id="install-content" className="install-head" aria-labelledby="install-title">
          <p className="section-eyebrow">Installation</p>
          <h1 id="install-title">Get Loaf running.<br /><span>Pick a channel, run one line.</span></h1>
          <p className="install-lead">The installer asks a single question: Try it now, or Install it for good. Everything below is pulled live from the releases feed when you open this page.</p>
        </section>

        <div className="install-terminal section-pad">
          <CommandCard showOptionsLink={false} />
        </div>
      </div>

      <div id="channels" className="channel-grid section-pad">
        {releases === null && !failed && (
          <>
            <div className="channel-card is-loading"><RefreshCw className="spin" size={22} aria-hidden="true" /><p>Reading the release feed…</p></div>
            <div className="channel-card is-loading"><RefreshCw className="spin" size={22} aria-hidden="true" /><p>Checking the nightly build…</p></div>
          </>
        )}
        {failed && (
          <div className="api-error" role="alert">
            <TriangleAlert size={26} aria-hidden="true" />
            <div>
              <p>Couldn't reach the GitHub releases API from here (offline, or rate-limited). The releases page has everything this page would have shown.</p>
              <a className="button button-primary" href={`${repo}/releases`} target="_blank" rel="noreferrer">Open releases <ArrowUpRight size={16} aria-hidden="true" /></a>
            </div>
          </div>
        )}
        {stable && <ChannelCard release={stable} kind="stable" />}
        {nightly && <ChannelCard release={nightly} kind="nightly" />}
      </div>

      {older.length > 0 && (
        <section className="older-section section-pad" aria-labelledby="older-title">
          <h2 id="older-title">Older releases</h2>
          <ul className="older-list">
            {older.map((r) => (
              <li key={r.tag_name}>
                <a href={r.html_url} target="_blank" rel="noreferrer">
                  <strong>{r.tag_name}</strong>
                  <span>{fmtDate(r.published_at)}</span>
                  <ArrowUpRight size={15} aria-hidden="true" />
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section id="alternatives" className="alt-section section-pad" aria-labelledby="alt-title">
        <h2 id="alt-title">Other ways in</h2>
        <div className="alt-grid">
          <div className="alt-card">
            <h3>AUR (Arch)</h3>
            <p>Community-maintained binary package.</p>
            <div className="mini-command">
              <span className="prompt-symbol" aria-hidden="true">$</span>
              <code>yay -S loaf-fm-bin</code>
            </div>
          </div>
          <div className="alt-card">
            <h3>Nix / NixOS</h3>
            <p>Run it directly, or set it up declaratively with your flake.</p>
            <div className="mini-command">
              <span className="prompt-symbol" aria-hidden="true">$</span>
              <code>nix run github:m-uvex/loaf-fm</code>
            </div>
            <pre className="alt-pre"><code>{`inputs.loaf.url = "github:m-uvex/loaf-fm";
# configuration.nix
nixpkgs.overlays = [ inputs.loaf.overlays.default ];
environment.systemPackages = [ pkgs.loaf ];`}</code></pre>
          </div>
          <div className="alt-card">
            <h3>Source</h3>
            <p>Rust 1.75+, Qt6 and CMake. The full recipe lives in the repo.</p>
            <a className="text-link" href={`${repo}#building-from-source`} target="_blank" rel="noreferrer">Build it yourself <ArrowUpRight size={14} aria-hidden="true" /></a>
          </div>
        </div>
      </section>

      <FooterIslands />
    </main>
  );
}
