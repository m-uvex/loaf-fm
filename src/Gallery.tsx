import { ArrowRight } from "lucide-react";
import { TopNav, FooterIslands } from "./components";

const stops = [
  {
    src: "/gallery/this-pc.png",
    title: "This PC",
    body: "Drives, partitions and network shares on one shelf. Usage bars, mount and eject, frequent folders, even a rename-the-machine field.",
  },
  {
    src: "/gallery/home.png",
    title: "Home",
    body: "The grid you land on every launch: recent files up top, pinned places below. Your desk, tidy without trying.",
  },
  {
    src: "/gallery/quick-look.png",
    title: "Quick Look",
    body: "Press space on anything — image, video, PDF, font — and it previews in place. No launching random apps to check one file.",
  },
  {
    src: "/gallery/search.png",
    title: "Search",
    body: "Ctrl+F starts filtering instantly. Results narrow while you type, straight from the folder you're in.",
  },
  {
    src: "/gallery/archives.png",
    title: "Archives",
    body: "Zip, tar.gz, 7z — they open like folders. Browse the tree, drag files out, or compress a selection right where it is.",
  },
  {
    src: "/gallery/themes.png",
    title: "Themes",
    body: "Eight tuned palettes, or an accent pulled live from your wallpaper. Window and panel opacity sliders, and a calm low-power mode.",
  },
  {
    src: "/gallery/beam.png",
    title: "Beam",
    body: "Right-click anything, pick Share via Link, hand the URL to anyone in range. Nothing touches the cloud, no account required.",
  },
];

export default function Gallery() {
  return (
    <main id="top" className="site-shell gallery-page">
      <a className="skip-link" href="#gallery-content">Skip to content</a>

      <div className="hero-wrap gallery-hero">
        <TopNav />

        <section id="gallery-content" className="gallery-head" aria-labelledby="gallery-title">
          <div className="gallery-hero-copy">
            <h1 id="gallery-title">A walkthrough of Loaf.</h1>
            <p className="gallery-lead">Seven stops, down the sidebar and back. Straight from a real build — no mockups involved.</p>
          </div>
        </section>
      </div>

      <section className="walkthrough" aria-label="Tour of Loaf">
        {stops.map((stop, i) => (
          <article
            key={stop.title}
            className={`walk-row${i % 2 ? " walk-row--flip" : ""}`}
          >
            <figure className="walk-figure">
              <img
                src={stop.src}
                alt={`Loaf showing ${stop.title}`}
                loading={i === 0 ? "eager" : "lazy"}
                width="1600"
                height="900"
              />
              <figcaption>Loaf · {stop.title}</figcaption>
            </figure>
            <div className="walk-copy">
              <span className="walk-index">0{i + 1}</span>
              <h2>{stop.title}</h2>
              <p>{stop.body}</p>
            </div>
          </article>
        ))}

        <div className="walk-cta">
          <p>Like what you see?</p>
          <a className="button button-primary" href="/install.html">Get Loaf <ArrowRight size={17} aria-hidden="true" /></a>
        </div>
      </section>

      <FooterIslands />
    </main>
  );
}
