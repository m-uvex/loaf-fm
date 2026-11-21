//! Theme mode: light / dark.
//! No stored choice means follow the OS preference live. Once the user toggles,
//! their explicit choice is stored and sticks.

export type ThemeMode = "light" | "dark";

const KEY = "loaf-theme";

function systemTheme(): ThemeMode {
  try {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  } catch {
    return "light";
  }
}

function hasStoredChoice(): boolean {
  try {
    const v = localStorage.getItem(KEY);
    return v === "light" || v === "dark";
  } catch {
    return false;
  }
}

export function getMode(): ThemeMode {
  try {
    const v = localStorage.getItem(KEY);
    if (v === "light" || v === "dark") return v;
  } catch {
    /* ignore */
  }
  return systemTheme();
}

export function resolved(mode: ThemeMode): "light" | "dark" {
  return mode === "dark" ? "dark" : "light";
}

export function applyTheme(mode: ThemeMode): void {
  try {
    localStorage.setItem(KEY, mode);
  } catch {
    /* ignore */
  }
  document.documentElement.dataset.theme = mode;
  window.dispatchEvent(new CustomEvent("loaf-theme-change", { detail: mode }));
}

export function initTheme(): void {
  document.documentElement.dataset.theme = getMode();
  try {
    const mm = window.matchMedia("(prefers-color-scheme: dark)");
    const resync = () => {
      if (!hasStoredChoice()) {
        document.documentElement.dataset.theme = systemTheme();
        window.dispatchEvent(new CustomEvent("loaf-theme-change", { detail: systemTheme() }));
      }
    };
    mm.addEventListener("change", resync);
  } catch {
    /* ignore */
  }
}