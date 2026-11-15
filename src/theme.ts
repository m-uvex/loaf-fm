//! Theme mode: light / dark / auto.
//! Stored in localStorage under `loaf-theme`. `auto` resolves against the
//! operating-system preference and re-resolves live when the system flips.

export type ThemeMode = "auto" | "light" | "dark";

const KEY = "loaf-theme";

export function getMode(): ThemeMode {
  try {
    const v = localStorage.getItem(KEY);
    if (v === "light" || v === "dark") return v;
  } catch {
    /* ignore */
  }
  return "auto";
}

export function resolved(mode: ThemeMode): "light" | "dark" {
  if (mode === "light") return "light";
  if (mode === "dark") return "dark";
  try {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  } catch {
    return "light";
  }
}

export function applyTheme(mode: ThemeMode): void {
  try {
    localStorage.setItem(KEY, mode);
  } catch {
    /* ignore */
  }
  document.documentElement.dataset.theme = resolved(mode);
  window.dispatchEvent(new CustomEvent("loaf-theme-change", { detail: mode }));
}

export function initTheme(): void {
  document.documentElement.dataset.theme = resolved(getMode());
  try {
    const mm = window.matchMedia("(prefers-color-scheme: dark)");
    const resync = () => {
      if (getMode() === "auto") document.documentElement.dataset.theme = resolved("auto");
    };
    mm.addEventListener("change", resync);
  } catch {
    /* ignore */
  }
}