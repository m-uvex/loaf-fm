import { useEffect, useState } from "react";
import { ArrowUpRight, Download, RefreshCw, TriangleAlert } from "lucide-react";
import { CommandCard, FooterIslands, MiniCommand, Snippet, TopNav, repo } from "./components";
import { Markdown } from "./markdown";

const API = "https://api.github.com/repos/m-uvex/loaf-fm/releases?per_page=6";

type Asset = { name: string; browser_download_url: string; size: number };
type Release = {
  tag_name: string;
  name: string;
  target_commitish: string;
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
  const isNightly = kind === "nightly";
  const title = isNightly ? release.target_commitish.slice(0, 7) : release.tag_name;
  const assets = WANTED.map((w) => ({ label: w.label, asset: release.assets.find((a) => w.match(a.name)) })).filter(
    (x): x is { label: string; asset: Asset } => Boolean(x.asset),
  );
  return (
    <section className={`channel-card channel-card--${kind}`} aria-labelledby={`channel-${kind}`}>
      <header className="channel-head">
        <span className={`channel-pill channel-pill--${kind}`}>{isNightly ? "Nightly" : "Stable"}</span>
        <time className="channel-date" dateTime={release.published_at}>{fmtDate(release.published_at)}</time>
        <h2 id={`channel-${kind}`}>
          <a href={release.html_url} target="_blank" rel="noreferrer" title="Open this release on GitHub">{title}</a>
        </h2>
        {isNightly && (
          <p className="nightly-note">Rebuilt from <code>main</code> on every merge. Fresh fixes, fresh bugs.</p>
        )}
      </header>
      <ul className="asset-list">
        {assets.map(({ label, asset }) => (
          <li key={label}>
            <a className="asset-row" href={asset.browser_download_url} target="_blank" rel="noreferrer">
              <span className="asset-ic" aria-hidden="true"><Download size={14} /></span>
              <span className="asset-name">{label}</span>
              <span className="asset-size">{fmtSize(asset.size)}</span>
            </a>
          </li>
        ))}
      </ul>
      {isNightly && (
        <div className="nightly-commands">
          <MiniCommand code="curl -sSL https://raw.githubusercontent.com/m-uvex/loaf-fm/main/install.sh | bash -s -- --nightly" />
          <MiniCommand code="nix run github:m-uvex/loaf-fm/nightly" />
        </div>
      )}
      <details className="changelog">
        <summary>Changelog</summary>
        <div className="changelog-wrap">
          <div className="changelog-body">
            <Markdown source={release.body || "No notes for this release yet."} />
          </div>
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
        <TopNav />

        <section id="install-content" className="install-head" aria-labelledby="install-title">
          <div className="install-hero-grid">
            <div className="install-hero-copy">
              <h1 id="install-title">Get Loaf running.</h1>
              <p className="install-lead">One command, then choose Try or Install. Below is the latest stable release and the current nightly, fetched from GitHub every time this page opens.</p>
            </div>
            <CommandCard showOptionsLink={false} />
          </div>
        </section>
      </div>

      <div id="channels" className="channel-grid section-pad" aria-label="Release channels">
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
            <MiniCommand code="yay -S loaf-fm-bin" />
          </div>
          <div className="alt-card">
            <h3>Nix / NixOS</h3>
            <p>Run it directly, or wire it into your flake.</p>
            <MiniCommand code="nix run github:m-uvex/loaf-fm" />
            <Snippet code={`inputs.loaf.url = "github:m-uvex/loaf-fm";\n# configuration.nix\nnixpkgs.overlays = [ inputs.loaf.overlays.default ];\nenvironment.systemPackages = [ pkgs.loaf ];`} />
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
