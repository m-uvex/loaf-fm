//! Support for acting as an xdg-desktop-portal backend. Everything that can
//! live without Qt is kept here so it can be unit tested: file chooser
//! filter parsing and matching now, option validation and URI helpers with
//! the D-Bus layer.

pub mod filters;
