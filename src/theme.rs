//! System appearance, dark mode detection, and wallpaper palettes.

use std::fs;
use std::path::{Path, PathBuf};

fn run_cmd_stdout(cmd: &str, args: &[&str]) -> Option<String> {
    let output = std::process::Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn dark_from_gsettings() -> Option<bool> {
    let out = run_cmd_stdout("gsettings", &["get", "org.gnome.desktop.interface", "color-scheme"])?;
    let s = out.to_lowercase();
    if s.contains("prefer-dark") {
        Some(true)
    } else if s.contains("prefer-light") {
        Some(false)
    } else {
        // "default"/unset means "no preference": try the next source.
        None
    }
}

fn dark_from_portal() -> Option<bool> {
    let out = run_cmd_stdout(
        "gdbus",
        &[
            "call",
            "--session",
            "--dest",
            "org.freedesktop.portal.Desktop",
            "--object-path",
            "/org/freedesktop/portal/desktop",
            "--method",
            "org.freedesktop.portal.Settings.Read",
            "org.freedesktop.appearance",
            "color-scheme",
        ],
    )?;
    // Reply shape: (<uint32 1>,) where 0 = no preference, 1 = prefer dark, 2 = prefer light.
    if out.contains("uint32 1") {
        Some(true)
    } else if out.contains("uint32 2") {
        Some(false)
    } else {
        None
    }
}

fn dark_from_gtk_settings() -> Option<bool> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-3.0/settings.ini")),
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-4.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-3.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-4.0/settings.ini")),
    ];

    for candidate in candidates.into_iter().flatten() {
        let Ok(content) = fs::read_to_string(&candidate) else { continue };
        for line in content.lines() {
            let line = line.trim();
            let Some((key, value)) = line.split_once('=') else { continue };
            if key.trim() != "gtk-application-prefer-dark-theme" {
                continue;
            }
            let v = value.trim().to_lowercase();
            if v == "1" || v == "true" || v == "yes" || v == "on" {
                return Some(true);
            }
            if v == "0" || v == "false" || v == "no" || v == "off" {
                return Some(false);
            }
        }
    }
    None
}

/// Detection order: gsettings -> XDG desktop portal -> GTK settings.ini -> dark.
pub fn detect_system_dark_mode() -> bool {
    if let Some(dark) = dark_from_gsettings() {
        return dark;
    }
    if let Some(dark) = dark_from_portal() {
        return dark;
    }
    if let Some(dark) = dark_from_gtk_settings() {
        return dark;
    }
    true
}

pub fn read_system_hostname() -> String {
    if let Ok(s) = fs::read_to_string("/proc/sys/kernel/hostname") {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "PC".to_string()
}

fn parse_hex(s: &str) -> Option<(u8, u8, u8)> {
    let s = s.trim().trim_start_matches('#');
    if s.len() == 3 {
        let r = u8::from_str_radix(&s[0..1], 16).ok()? * 17;
        let g = u8::from_str_radix(&s[1..2], 16).ok()? * 17;
        let b = u8::from_str_radix(&s[2..3], 16).ok()? * 17;
        Some((r, g, b))
    } else if s.len() == 6 {
        let r = u8::from_str_radix(&s[0..2], 16).ok()?;
        let g = u8::from_str_radix(&s[2..4], 16).ok()?;
        let b = u8::from_str_radix(&s[4..6], 16).ok()?;
        Some((r, g, b))
    } else {
        None
    }
}

fn to_hex((r, g, b): (u8, u8, u8)) -> String {
    format!("#{:02x}{:02x}{:02x}", r, g, b)
}

fn rgb_to_hsl((r, g, b): (u8, u8, u8)) -> (f32, f32, f32) {
    let rf = (r as f32) / 255.0;
    let gf = (g as f32) / 255.0;
    let bf = (b as f32) / 255.0;
    let max = rf.max(gf).max(bf);
    let min = rf.min(gf).min(bf);
    let d = max - min;
    let l = (max + min) / 2.0;
    if d.abs() < 1e-4 {
        return (0.0, 0.0, l);
    }
    let s = if l > 0.5 { d / (2.0 - max - min) } else { d / (max + min) };
    let mut h = if (max - rf).abs() < 1e-4 {
        (gf - bf) / d + (if gf < bf { 6.0 } else { 0.0 })
    } else if (max - gf).abs() < 1e-4 {
        (bf - rf) / d + 2.0
    } else {
        (rf - gf) / d + 4.0
    };
    h *= 60.0;
    (h, s, l)
}

fn hue_to_rgb(p: f32, q: f32, mut t: f32) -> f32 {
    if t < 0.0 { t += 1.0; }
    if t > 1.0 { t -= 1.0; }
    if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t; }
    if t < 1.0 / 2.0 { return q; }
    if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0; }
    p
}

fn hsl_to_rgb((h, s, l): (f32, f32, f32)) -> (u8, u8, u8) {
    let l_clamped = l.clamp(0.0, 1.0);
    if s <= 1e-4 {
        let val = (l_clamped * 255.0).round() as u8;
        return (val, val, val);
    }
    let q = if l_clamped < 0.5 { l_clamped * (1.0 + s) } else { l_clamped + s - l_clamped * s };
    let p = 2.0 * l_clamped - q;
    let h_norm = (h.rem_euclid(360.0)) / 360.0;
    let r = (hue_to_rgb(p, q, h_norm + 1.0 / 3.0).clamp(0.0, 1.0) * 255.0).round() as u8;
    let g = (hue_to_rgb(p, q, h_norm).clamp(0.0, 1.0) * 255.0).round() as u8;
    let b = (hue_to_rgb(p, q, h_norm - 1.0 / 3.0).clamp(0.0, 1.0) * 255.0).round() as u8;
    (r, g, b)
}

fn channel_lum(c: u8) -> f32 {
    let v = (c as f32) / 255.0;
    if v <= 0.04045 {
        v / 12.92
    } else {
        ((v + 0.055) / 1.055).powf(2.4)
    }
}

fn relative_lum(rgb: (u8, u8, u8)) -> f32 {
    0.2126 * channel_lum(rgb.0) + 0.7152 * channel_lum(rgb.1) + 0.0722 * channel_lum(rgb.2)
}

fn contrast_ratio(c1: (u8, u8, u8), c2: (u8, u8, u8)) -> f32 {
    let l1 = relative_lum(c1);
    let l2 = relative_lum(c2);
    let (bright, dark) = if l1 > l2 { (l1, l2) } else { (l2, l1) };
    (bright + 0.05) / (dark + 0.05)
}

fn ensure_contrast(text_hex: &str, bg_hex: &str, min_contrast: f32, prefer_light: bool) -> String {
    let Some(bg_rgb) = parse_hex(bg_hex) else { return text_hex.to_string(); };
    let Some(text_rgb) = parse_hex(text_hex) else { return text_hex.to_string(); };
    if contrast_ratio(text_rgb, bg_rgb) >= min_contrast {
        return text_hex.to_string();
    }
    let (h, s, _) = rgb_to_hsl(text_rgb);
    for i in 1..25 {
        let candidate_l = if prefer_light {
            (0.5 + i as f32 * 0.02).clamp(0.04, 0.98)
        } else {
            (0.5 - i as f32 * 0.02).clamp(0.04, 0.98)
        };
        let candidate_rgb = hsl_to_rgb((h, s * 0.7, candidate_l));
        if contrast_ratio(candidate_rgb, bg_rgb) >= min_contrast {
            return to_hex(candidate_rgb);
        }
    }
    let fallback_l = if prefer_light { 0.96 } else { 0.08 };
    to_hex(hsl_to_rgb((h, s * 0.5, fallback_l)))
}

fn str_from<'a>(obj: &'a serde_json::Map<String, serde_json::Value>, key: &str) -> Option<&'a str> {
    obj.get(key).and_then(|v| v.as_str())
}

pub fn normalize_wallpaper_colors(content: &str) -> String {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(content) else {
        return content.to_string();
    };

    // If source already has nested colors.dark and colors.light (e.g. DMS / Matugen multi-mode)
    let nested_dark = val.get("colors").and_then(|c| c.get("dark")).and_then(|d| d.as_object());
    let nested_light = val.get("colors").and_then(|c| c.get("light")).and_then(|l| l.as_object());

    // Fallback pywal 16 colors
    let pywal_colors = val.get("colors").and_then(|c| c.as_object());
    let pywal_special = val.get("special").and_then(|s| s.as_object());

    // Extract seed primary and background
    let raw_primary = val.get("primary").and_then(|v| v.as_str())
        .or_else(|| nested_dark.and_then(|d| str_from(d, "primary")))
        .or_else(|| nested_light.and_then(|l| str_from(l, "primary")))
        .or_else(|| pywal_colors.and_then(|c| str_from(c, "color4")))
        .or_else(|| pywal_colors.and_then(|c| str_from(c, "color1")))
        .unwrap_or("#cfc6ab");

    let raw_bg = val.get("background").and_then(|v| v.as_str())
        .or_else(|| nested_dark.and_then(|d| str_from(d, "background")))
        .or_else(|| pywal_special.and_then(|s| str_from(s, "background")))
        .or_else(|| pywal_colors.and_then(|c| str_from(c, "color0")))
        .unwrap_or("#141311");

    let primary_rgb = parse_hex(raw_primary).unwrap_or((207, 198, 171));
    let (p_h, p_s, _) = rgb_to_hsl(primary_rgb);
    let bg_rgb = parse_hex(raw_bg).unwrap_or((20, 19, 17));
    let (bg_h, bg_s, _) = rgb_to_hsl(bg_rgb);

    let tint_h = if bg_s > 0.05 { bg_h } else { p_h };
    let tint_s = bg_s.clamp(0.04, 0.25);

    // Is the source data itself fundamentally light (e.g. light mode matugen generated colors)?
    let source_is_light = relative_lum(bg_rgb) > 0.40;

    // Build dark palette:
    // If source is light, do NOT reuse light surfaces for dark mode! Invert or derive proper dark tones.
    let dark_bg = if source_is_light {
        val.get("inverse_surface").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "background")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.07))))
    } else {
        raw_bg.to_string()
    };

    let dark_surf_lowest = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.04)))
    } else {
        val.get("surface_container_lowest").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container_lowest")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s, 0.04))))
    };

    let dark_surf_low = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.09)))
    } else {
        val.get("surface_container_low").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container_low")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s, 0.09))))
    };

    let dark_surf = if source_is_light {
        val.get("inverse_surface").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.13))))
    } else {
        val.get("surface_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s, 0.13))))
    };

    let dark_surf_high = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.17)))
    } else {
        val.get("surface_container_high").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container_high")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s, 0.17))))
    };

    let dark_surf_highest = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, tint_s * 0.8, 0.22)))
    } else {
        val.get("surface_container_highest").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "surface_container_highest")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s, 0.22))))
    };

    let dark_primary = if source_is_light {
        val.get("inverse_primary").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "primary")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, p_s.max(0.4), 0.76))))
    } else {
        raw_primary.to_string()
    };

    let dark_on_primary = if source_is_light {
        to_hex(hsl_to_rgb((p_h, p_s * 0.7, 0.14)))
    } else {
        val.get("on_primary").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_primary")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, p_s * 0.7, 0.14))))
    };

    let dark_container = if source_is_light {
        to_hex(hsl_to_rgb((p_h, p_s * 0.6, 0.28)))
    } else {
        val.get("primary_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "primary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, p_s * 0.6, 0.28))))
    };

    let dark_on_container = if source_is_light {
        to_hex(hsl_to_rgb((p_h, p_s * 0.5, 0.92)))
    } else {
        val.get("on_primary_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_primary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, p_s * 0.5, 0.92))))
    };

    let dark_sec_container = if source_is_light {
        to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.5).max(0.12), 0.24)))
    } else {
        val.get("secondary_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "secondary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.5).max(0.12), 0.24))))
    };

    let dark_on_sec_container = if source_is_light {
        to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.4).max(0.1), 0.90)))
    } else {
        val.get("on_secondary_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_secondary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.4).max(0.1), 0.90))))
    };

    let dark_tertiary_container = if source_is_light {
        to_hex(hsl_to_rgb(((p_h + 50.0) % 360.0, (p_s * 0.4).max(0.1), 0.22)))
    } else {
        val.get("tertiary_container").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "tertiary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 50.0) % 360.0, (p_s * 0.4).max(0.1), 0.22))))
    };

    let raw_dark_text = if source_is_light {
        val.get("inverse_on_surface").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_surface")))
            .unwrap_or("#e6e2dd")
    } else {
        val.get("on_surface").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_surface")))
            .or_else(|| pywal_special.and_then(|s| str_from(s, "foreground")))
            .unwrap_or("#e6e2dd")
    };

    let raw_dark_muted = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, 0.12, 0.72)))
    } else {
        val.get("on_surface_variant").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "on_surface_variant")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.12, 0.72))))
    };

    let dark_text = ensure_contrast(raw_dark_text, &dark_surf, 9.0, true);
    let dark_muted = ensure_contrast(&raw_dark_muted, &dark_surf, 4.5, true);

    let dark_outline = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, 0.10, 0.56)))
    } else {
        val.get("outline").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "outline")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.10, 0.56))))
    };

    let dark_outline_variant = if source_is_light {
        to_hex(hsl_to_rgb((tint_h, 0.15, 0.28)))
    } else {
        val.get("outline_variant").and_then(|v| v.as_str())
            .or_else(|| nested_dark.and_then(|d| str_from(d, "outline_variant")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.15, 0.28))))
    };

    // Build light palette:
    // If source is already light, use its native light tokens directly!
    let light_bg = if source_is_light {
        val.get("background").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "background")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.98))))
    } else {
        nested_light.and_then(|l| str_from(l, "background"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.98))))
    };

    let light_surf_lowest = if source_is_light {
        val.get("surface_container_lowest").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "surface_container_lowest")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| "#ffffff".to_string())
    } else {
        nested_light.and_then(|l| str_from(l, "surface_container_lowest"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| "#ffffff".to_string())
    };

    let light_surf_low = if source_is_light {
        val.get("surface_container_low").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "surface_container_low")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.96))))
    } else {
        nested_light.and_then(|l| str_from(l, "surface_container_low"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.96))))
    };

    let light_surf = if source_is_light {
        val.get("surface_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "surface_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.93))))
    } else {
        nested_light.and_then(|l| str_from(l, "surface_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.93))))
    };

    let light_surf_high = if source_is_light {
        val.get("surface_container_high").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "surface_container_high")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.89))))
    } else {
        nested_light.and_then(|l| str_from(l, "surface_container_high"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.89))))
    };

    let light_surf_highest = if source_is_light {
        val.get("surface_container_highest").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "surface_container_highest")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.85))))
    } else {
        nested_light.and_then(|l| str_from(l, "surface_container_highest"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, tint_s * 0.6, 0.85))))
    };

    let light_primary = if source_is_light {
        raw_primary.to_string()
    } else {
        val.get("inverse_primary").and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .or_else(|| nested_light.and_then(|l| str_from(l, "primary")).map(|s| s.to_string()))
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, p_s.max(0.65), 0.38))))
    };

    let light_on_primary = if source_is_light {
        val.get("on_primary").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "on_primary")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| "#ffffff".to_string())
    } else {
        nested_light.and_then(|l| str_from(l, "on_primary"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| "#ffffff".to_string())
    };

    let light_container = if source_is_light {
        val.get("primary_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "primary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, (p_s * 0.55).max(0.15), 0.88))))
    } else {
        nested_light.and_then(|l| str_from(l, "primary_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, (p_s * 0.55).max(0.15), 0.88))))
    };

    let light_on_container = if source_is_light {
        val.get("on_primary_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "on_primary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, (p_s * 0.75).max(0.3), 0.14))))
    } else {
        nested_light.and_then(|l| str_from(l, "on_primary_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((p_h, (p_s * 0.75).max(0.3), 0.14))))
    };

    let light_sec_container = if source_is_light {
        val.get("secondary_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "secondary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.45).max(0.12), 0.87))))
    } else {
        nested_light.and_then(|l| str_from(l, "secondary_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.45).max(0.12), 0.87))))
    };

    let light_on_sec_container = if source_is_light {
        val.get("on_secondary_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "on_secondary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.7).max(0.25), 0.15))))
    } else {
        nested_light.and_then(|l| str_from(l, "on_secondary_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 25.0) % 360.0, (p_s * 0.7).max(0.25), 0.15))))
    };

    let light_tertiary_container = if source_is_light {
        val.get("tertiary_container").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "tertiary_container")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 50.0) % 360.0, (p_s * 0.35).max(0.1), 0.88))))
    } else {
        nested_light.and_then(|l| str_from(l, "tertiary_container"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb(((p_h + 50.0) % 360.0, (p_s * 0.35).max(0.1), 0.88))))
    };

    let raw_light_text = if source_is_light {
        val.get("on_surface").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "on_surface")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| "#1d1b19".to_string())
    } else {
        nested_light.and_then(|l| str_from(l, "on_surface"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.12, 0.12))))
    };

    let raw_light_muted = if source_is_light {
        val.get("on_surface_variant").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "on_surface_variant")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.15, 0.36))))
    } else {
        nested_light.and_then(|l| str_from(l, "on_surface_variant"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.15, 0.36))))
    };

    let light_text = ensure_contrast(&raw_light_text, &light_surf, 9.0, false);
    let light_muted = ensure_contrast(&raw_light_muted, &light_surf, 4.5, false);

    let light_outline = if source_is_light {
        val.get("outline").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "outline")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.12, 0.48))))
    } else {
        nested_light.and_then(|l| str_from(l, "outline"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.12, 0.48))))
    };

    let light_outline_variant = if source_is_light {
        val.get("outline_variant").and_then(|v| v.as_str())
            .or_else(|| nested_light.and_then(|l| str_from(l, "outline_variant")))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.15, 0.78))))
    } else {
        nested_light.and_then(|l| str_from(l, "outline_variant"))
            .map(|s| s.to_string())
            .unwrap_or_else(|| to_hex(hsl_to_rgb((tint_h, 0.15, 0.78))))
    };

    let mut dark_map = serde_json::Map::new();
    dark_map.insert("background".to_string(), serde_json::json!(dark_bg));
    dark_map.insert("surface_container_lowest".to_string(), serde_json::json!(dark_surf_lowest));
    dark_map.insert("surface_container_low".to_string(), serde_json::json!(dark_surf_low));
    dark_map.insert("surface_container".to_string(), serde_json::json!(dark_surf));
    dark_map.insert("surface_container_high".to_string(), serde_json::json!(dark_surf_high));
    dark_map.insert("surface_container_highest".to_string(), serde_json::json!(dark_surf_highest));
    dark_map.insert("primary".to_string(), serde_json::json!(dark_primary));
    dark_map.insert("on_primary".to_string(), serde_json::json!(dark_on_primary));
    dark_map.insert("primary_container".to_string(), serde_json::json!(dark_container));
    dark_map.insert("on_primary_container".to_string(), serde_json::json!(dark_on_container));
    dark_map.insert("secondary_container".to_string(), serde_json::json!(dark_sec_container));
    dark_map.insert("on_secondary_container".to_string(), serde_json::json!(dark_on_sec_container));
    dark_map.insert("tertiary_container".to_string(), serde_json::json!(dark_tertiary_container));
    dark_map.insert("on_surface".to_string(), serde_json::json!(dark_text));
    dark_map.insert("on_surface_variant".to_string(), serde_json::json!(dark_muted));
    dark_map.insert("outline".to_string(), serde_json::json!(dark_outline));
    dark_map.insert("outline_variant".to_string(), serde_json::json!(dark_outline_variant));

    let mut light_map = serde_json::Map::new();
    light_map.insert("background".to_string(), serde_json::json!(light_bg));
    light_map.insert("surface_container_lowest".to_string(), serde_json::json!(light_surf_lowest));
    light_map.insert("surface_container_low".to_string(), serde_json::json!(light_surf_low));
    light_map.insert("surface_container".to_string(), serde_json::json!(light_surf));
    light_map.insert("surface_container_high".to_string(), serde_json::json!(light_surf_high));
    light_map.insert("surface_container_highest".to_string(), serde_json::json!(light_surf_highest));
    light_map.insert("primary".to_string(), serde_json::json!(light_primary));
    light_map.insert("on_primary".to_string(), serde_json::json!(light_on_primary));
    light_map.insert("primary_container".to_string(), serde_json::json!(light_container));
    light_map.insert("on_primary_container".to_string(), serde_json::json!(light_on_container));
    light_map.insert("secondary_container".to_string(), serde_json::json!(light_sec_container));
    light_map.insert("on_secondary_container".to_string(), serde_json::json!(light_on_sec_container));
    light_map.insert("tertiary_container".to_string(), serde_json::json!(light_tertiary_container));
    light_map.insert("on_surface".to_string(), serde_json::json!(light_text));
    light_map.insert("on_surface_variant".to_string(), serde_json::json!(light_muted));
    light_map.insert("outline".to_string(), serde_json::json!(light_outline));
    light_map.insert("outline_variant".to_string(), serde_json::json!(light_outline_variant));

    let mut out = dark_map.clone();
    out.insert("dark".to_string(), serde_json::Value::Object(dark_map));
    out.insert("light".to_string(), serde_json::Value::Object(light_map));

    serde_json::to_string(&out).unwrap_or_else(|_| content.to_string())
}

/// Returns (source_path, content, mtime_secs) for the first readable color source.
pub fn read_wallpaper_colors_source() -> Option<(String, String, u64)> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        format!("{}/.local/state/quickshell/user/generated/colors.json", home),
        format!("{}/.cache/wal/colors.json", home),
        format!("{}/.cache/matugen/colors.json", home),
        format!("{}/.config/matugen/colors.json", home),
        format!("{}/.cache/DankMaterialShell/dms-colors.json", home),
        format!("{}/.cache/current_wallpaper_palette.json", home),
    ];

    for path_str in candidates {
        let path = Path::new(&path_str);
        let Ok(raw_content) = fs::read_to_string(path) else { continue };
        let is_object = serde_json::from_str::<serde_json::Value>(&raw_content)
            .ok()
            .map(|v| v.is_object() && v.as_object().map(|o| !o.is_empty()).unwrap_or(false))
            .unwrap_or(false);
        if !is_object {
            continue;
        }
        let content = normalize_wallpaper_colors(&raw_content);
        let mtime = fs::metadata(path)
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        return Some((path_str, content, mtime));
    }
    None
}

pub fn read_wallpaper_colors() -> String {
    read_wallpaper_colors_source()
        .map(|(_, content, _)| content)
        .unwrap_or_else(|| "{}".to_string())
}


pub fn detect_device_type() -> &'static str {
    if let Ok(chassis) = fs::read_to_string("/sys/class/dmi/id/chassis_type") {
        match chassis.trim() {
            "8" | "9" | "10" | "11" | "14" | "30" | "31" | "32" => return "laptop",
            _ => {}
        }
    }
    if Path::new("/sys/class/power_supply/BAT0").exists() || Path::new("/sys/class/power_supply/BAT1").exists() {
        return "laptop";
    }
    "desktop"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn color_conversions_and_contrast() {
        let hex = "#381e72";
        let rgb = parse_hex(hex).expect("parse hex");
        assert_eq!(rgb, (56, 30, 114));
        assert_eq!(to_hex(rgb), hex);

        let white = (255, 255, 255);
        let black = (0, 0, 0);
        assert!((contrast_ratio(white, black) - 21.0).abs() < 0.1);

        let adjusted = ensure_contrast("#606060", "#101010", 4.5, true);
        let adj_rgb = parse_hex(&adjusted).expect("parse adjusted hex");
        assert!(contrast_ratio(adj_rgb, (16, 16, 16)) >= 4.5);
    }

    #[test]
    fn normalizes_wallpaper_flat_and_pywal() {
        let pywal_input = serde_json::json!({
            "special": { "background": "#1b1923", "foreground": "#f8f8f2" },
            "colors": { "color0": "#1b1923", "color4": "#bd93f9", "color8": "#6272a4" }
        });
        let normalized = normalize_wallpaper_colors(&pywal_input.to_string());
        let val: serde_json::Value = serde_json::from_str(&normalized).expect("valid json");
        assert!(val.get("dark").is_some());
        assert!(val.get("light").is_some());
        assert_eq!(val["dark"]["background"], "#1b1923");
        assert!(val["light"]["surface_container_lowest"] == "#ffffff");
    }
}
