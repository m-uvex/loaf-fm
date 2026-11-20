import { useEffect, useRef, useState } from "react";
import {
  Archive,
  AppWindow,
  ArrowRight,
  ArrowUpRight,
  Eye,
  HardDrive,
  Images,
  Palette,
  Radio,
  Sparkles,
  Users,
} from "lucide-react";
import { CommandCard, FooterIslands, TopNav, repo, discord } from "./components";

// Real Material 3 Expressive shape library subset (decorative/icon use only).
const SHAPES = ["circle", "arch", "clover4", "flower", "sunny", "cookie6"] as const;
type Shape = (typeof SHAPES)[number];

const features = [
  {
    icon: AppWindow,
    title: "A portal for the whole desktop.",
    body: "Run loaf --portal once and every open or save dialog in the system, including inside Flatpaks, comes from Loaf. One file manager, everywhere.",
    className: "feature-card--lilac",
    wide: true,
  },
  {
    icon: Eye,
    title: "Press space, see everything.",
    body: "Images, audio, video, PDFs, fonts — hit Space and preview the file where it is, without launching a separate app.",
    className: "feature-card--blue",
    wide: false,
  },
  {
    icon: Radio,
    title: "Share files over the air.",
    body: "Make a link and send files to any phone or laptop on your network. Nothing leaves for the cloud, no size cap, no account.",
    className: "feature-card--peach",
    wide: false,
  },
  {
    icon: Archive,
    title: "Archives open like folders.",
    body: "Browse, extract, and create .zip, .tar.*, and .7z right in the tree. Background jobs with progress and cancel, including encrypted ZIPs.",
    className: "feature-card--butter",
    wide: true,
  },
  {
    icon: HardDrive,
    title: "This PC, all on one shelf.",
    body: "Disks, partitions, and network shares with usage bars, mount and eject controls, frequent folders, and a machine name you can rename.",
    className: "feature-card--mint",
    wide: false,
  },
  {
    icon: Palette,
    title: "Themes that follow your wallpaper.",
    body: "Eight tuned palettes or a live accent pulled from your wallpaper, with sliders for window and panel opacity and a low-power mode for battery.",
    className: "feature-card--share",
    wide: true,
  },
];

function useTheme(): "light" | "dark" {
  const [theme, setTheme] = useState<"light" | "dark">(() =>
    typeof document !== "undefined" && document.documentElement.dataset.theme === "dark"
      ? "dark"
      : "light",
  );
  useEffect(() => {
    const read = () =>
      (document.documentElement.dataset.theme === "dark" ? "dark" : "light") as
        | "light"
        | "dark";
    setTheme(read());
    const on = () => setTheme(read());
    window.addEventListener("loaf-theme-change", on);
    const mo = new MutationObserver(on);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    return () => {
      window.removeEventListener("loaf-theme-change", on);
      mo.disconnect();
    };
  }, []);
  return theme;
}

function FeatureCard({
  icon: Icon,
  title,
  body,
  className,
  wide,
}: {
  icon: typeof AppWindow;
  title: string;
  body: string;
  className: string;
  wide: boolean;
}) {
  const [shape, setShape] = useState<Shape>("circle");
  const reroll = () => {
    setShape((prev) => {
      let next = prev;
      while (next === prev) next = SHAPES[Math.floor(Math.random() * SHAPES.length)];
      return next;
    });
  };

  return (
    <article
      className={`feature-card ${className}${wide ? " feature-card--wide" : ""}`}
      data-shape={shape}
      onMouseEnter={reroll}
    >
      <div className="feature-copy">
        <div className="feature-title-row">
          <span className="feature-icon">
            <Icon size={24} strokeWidth={1.8} aria-hidden="true" />
          </span>
          <h3>{title}</h3>
        </div>
        <p>{body}</p>
      </div>
      <Icon className="feature-ambient" size={176} strokeWidth={1.1} aria-hidden="true" />
    </article>
  );
}

export default function Home() {
  const artRef = useRef<HTMLDivElement | null>(null);
  const theme = useTheme();

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

  const heroSrc = theme === "dark" ? "/loaf-thispc-dark.png" : "/loaf-thispc-light.png";

  return (
    <main id="top" className="site-shell">
      <a className="skip-link" href="#main-content">Skip to content</a>

      <div className="hero-wrap">
        <TopNav />

        <section id="main-content" className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <h1 id="hero-title">
              Your file manager,<br />
              <span>reimagined.</span>
            </h1>
            <p className="hero-description">
              A fast, feature-stuffed file manager for Linux. Rust under the hood, Qt6 up
              top, Material 3 Expressive throughout.
            </p>
            <div className="hero-actions">
              <a className="button button-primary" href="/install.html">
                Get Loaf <ArrowRight size={18} aria-hidden="true" />
              </a>
              <a className="button button-quiet" href={repo} target="_blank" rel="noreferrer">
                Browse the code <ArrowUpRight size={16} aria-hidden="true" />
              </a>
            </div>
          </div>

          <div className="hero-art" onMouseMove={tilt} onMouseLeave={resetTilt}>
            <div className="shot-tilt" ref={artRef}>
              <div className="shot-float">
                <span className="shot-chip">
                  <Sparkles size={14} aria-hidden="true" /> Now transparent!
                </span>
                <img
                  className="product-shot"
                  src={heroSrc}
                  alt="Loaf's This PC view showing drives, usage, mount controls, and frequent folders."
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
          <h2 id="features-title">The good bits</h2>
        </div>

        <div className="feature-grid">
          {features.map((f) => (
            <FeatureCard key={f.title} {...f} />
          ))}
        </div>

        <a className="showcase-card" href="/gallery.html">
          <span className="showcase-card-icon" aria-hidden="true">
            <Images size={24} strokeWidth={1.8} />
          </span>
          <span className="showcase-card-copy">
            <span className="showcase-card-title">See it in action</span>
            <span className="showcase-card-body">
              A full tour of Loaf — eight screens, in light and dark, straight from a real
              build.
            </span>
          </span>
          <span className="showcase-card-arrow" aria-hidden="true">
            <ArrowRight size={18} />
          </span>
        </a>
      </section>

      <section id="get-involved" className="alpha-section section-pad" aria-labelledby="involved-title">
        <div className="alpha-note">
          <div className="alpha-symbol" aria-hidden="true">
            <Users size={24} />
          </div>
          <div className="alpha-copy">
            <h2 id="involved-title">Get involved.</h2>
            <p>
              Loaf is young and moving fast. File an issue, send a pull request, or just
              hang out — the Discord is where builds happen, releases land, and ideas get
              tried.
            </p>
          </div>
          <div className="involved-actions">
            <a
              className="button button-outline"
              href={`${repo}/blob/main/CONTRIBUTING.md`}
              target="_blank"
              rel="noreferrer"
            >
              Contribute <ArrowUpRight size={16} aria-hidden="true" />
            </a>
            <a className="button button-primary" href={discord} target="_blank" rel="noreferrer">
              Join the Discord <ArrowUpRight size={16} aria-hidden="true" />
            </a>
          </div>
        </div>
      </section>

      <section id="install" className="install-section section-pad" aria-labelledby="install-title">
        <div className="install-panel">
          <div className="install-copy">
            <h2 id="install-title">
              Install it.<br />
              <span>Pick Try or Install.</span>
            </h2>
            <p>
              One command opens Loaf's interactive installer. Choose Try to run it
              temporarily, or Install to set up the latest stable release.
            </p>
            <p className="nix-note">
              Other distributions use a universal tarball. NixOS users can follow the manual
              Nix guide.
            </p>
          </div>
          <CommandCard />
        </div>
      </section>

      <FooterIslands />
    </main>
  );
}
