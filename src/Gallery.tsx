import { useEffect, useRef, useState } from "react";
import { ArrowRight } from "lucide-react";
import { TopNav, FooterIslands } from "./components";

type Stop = {
  id: string;
  title: string;
  body: string;
};

const THEME_PANELS = ["lavender", "nord", "amber"] as const;

const stops: Stop[] = [
  {
    id: "thispc",
    title: "This PC",
    body: "Every drive, partition, and connected share in one place, with live usage, mount controls, frequent folders, and the machine name you can edit on the spot.",
  },
  {
    id: "themes",
    title: "Themes",
    body: "Pick from tuned palettes or pull an accent straight from your wallpaper. Same layout, different mood — the colors shift, everything else stays put.",
  },
  {
    id: "quicklook",
    title: "Quick Look",
    body: "Tap Space on a file and see it right there. Images, video, PDFs, fonts — no detour into another app just to check what something is.",
  },
  {
    id: "share",
    title: "Share via Link",
    body: "Hand a file or folder to anyone, anywhere, on any device, over any OS and any network. Loaf makes a link you can share directly — no cloud account, no lock-in.",
  },
  {
    id: "network",
    title: "Network drives",
    body: "Keep remote locations alongside local storage. Saved network drives stay easy to reach, so jumping between your machine and elsewhere feels like one file system.",
  },
  {
    id: "archives",
    title: "Archives",
    body: "Open zip, tar, and 7z files as if they were folders. Browse inside, pull things out, or pack a selection without leaving the view you're in.",
  },
  {
    id: "filepicker",
    title: "File picker",
    body: "When another app asks for a file, Loaf can answer. The same layout, the same navigation, and the same sense of place — even inside an open or save dialog.",
  },
  {
    id: "views",
    title: "Multiple views",
    body: "Split the window and work two places at once. One pane can group Downloads by date while the other stays a plain list of Home — different views, same window.",
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

function ThemesTriptych({ theme }: { theme: "light" | "dark" }) {
  const [active, setActive] = useState<number | null>(null);
  // Equal thirds by default; hovered panel expands, others shrink.
  const splits =
    active === null
      ? [0, 100 / 3, 200 / 3, 100]
      : active === 0
        ? [0, 50, 75, 100]
        : active === 1
          ? [0, 25, 75, 100]
          : [0, 25, 50, 100];

  return (
    <div
      className="themes-triptych"
      onMouseLeave={() => setActive(null)}
      onBlurCapture={(e) => {
        if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setActive(null);
      }}
    >
      {THEME_PANELS.map((palette, i) => {
        const left = splits[i];
        const right = 100 - splits[i + 1];
        return (
          <div key={palette} className="themes-layer" style={{ clipPath: `inset(0 ${right}% 0 ${left}% round 0px)` }}>
            <img
              src={`/gallery/themes-${palette}-${theme}.png`}
              alt={`Loaf This PC in ${palette} theme`}
              loading="lazy"
              width="1600"
              height="900"
              draggable={false}
            />
          </div>
        );
      })}
      <div className="themes-panels" aria-hidden="false">
        {THEME_PANELS.map((palette, i) => {
          const left = splits[i];
          const width = splits[i + 1] - splits[i];
          return (
            <button
              key={palette}
              type="button"
              className={`themes-panel${active === i ? " is-active" : ""}`}
              style={{ left: `${left}%`, width: `${width}%` }}
              onMouseEnter={() => setActive(i)}
              onFocus={() => setActive(i)}
              aria-label={`Preview ${palette} theme`}
            />
          );
        })}
      </div>
      <div className="themes-dividers" aria-hidden="true">
        <span className="themes-divider" style={{ left: `${splits[1]}%` }} />
        <span className="themes-divider" style={{ left: `${splits[2]}%` }} />
      </div>
    </div>
  );
}

function GalleryRow({ stop, index }: { stop: Stop; index: number }) {
  const theme = useTheme();
  const artRef = useRef<HTMLDivElement | null>(null);
  const [missing, setMissing] = useState(false);
  const src = `/gallery/${stop.id}-${theme}.png`;

  useEffect(() => {
    setMissing(false);
  }, [src]);

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

  if (stop.id !== "themes" && missing) return null;

  return (
    <article className={`walk-row${index % 2 ? " walk-row--flip" : ""}`}>
      <figure className="walk-figure" onMouseMove={tilt} onMouseLeave={resetTilt}>
        <div className="shot-tilt" ref={artRef}>
          <div className="shot-float">
            {stop.id === "themes" ? (
              <ThemesTriptych theme={theme} />
            ) : (
              <img
                src={src}
                alt={`Loaf showing ${stop.title}`}
                loading={index === 0 ? "eager" : "lazy"}
                width="1600"
                height="900"
                draggable={false}
                onError={() => setMissing(true)}
              />
            )}
          </div>
        </div>
      </figure>
      <div className="walk-copy">
        <h2>{stop.title}</h2>
        <p>{stop.body}</p>
      </div>
    </article>
  );
}

export default function Gallery() {
  return (
    <main id="top" className="site-shell gallery-page">
      <a className="skip-link" href="#gallery-content">Skip to content</a>

      <div className="hero-wrap gallery-hero">
        <TopNav />

        <section id="gallery-content" className="gallery-head" aria-labelledby="gallery-title">
          <div className="gallery-hero-copy">
            <h1 id="gallery-title">A tour through Loaf.</h1>
            <p className="gallery-lead">
              Eight stops around the app, captured from a real build in light and dark.
            </p>
          </div>
        </section>
      </div>

      <section className="walkthrough" aria-label="Tour of Loaf">
        {stops.map((stop, i) => (
          <GalleryRow key={stop.id} stop={stop} index={i} />
        ))}

        <div className="walk-cta">
          <p>Want to try it?</p>
          <a className="button button-primary" href="/install.html">
            Get Loaf <ArrowRight size={17} aria-hidden="true" />
          </a>
        </div>
      </section>

      <FooterIslands />
    </main>
  );
}
