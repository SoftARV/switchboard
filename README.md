<div align="center">

<img src="data/icons/hicolor/scalable/apps/dev.miguel.Switchboard.svg" width="112" alt="Switchboard">

# Switchboard

**A small GTK4 / libadwaita companion for [cardwire](https://github.com/OpenGamingCollective/cardwire) — switch GPU modes, see what is waking your dGPU, and keep it asleep.**

</div>

Switchboard is a pure D-Bus client of `cardwired`. It does not patch cardwire, wrap its CLI, or
install anything alongside it — it speaks the same system-bus API the official CLI does. Written in
Vala with Blueprint.

## What it does

- **Mode switching** — Integrated, Hybrid, Smart, whichever your system reports as available
- **Per-GPU status** — name, driver, live power state (`D0` vs `D3cold`) and a block toggle
- **Activity feed** — the processes cardwire blocked from touching the dGPU, live
- **Preferences** — battery auto-switch and the rest of the daemon config
- **Tray icon** — the current mode at a glance, with mode switching from the menu

Everything updates live. Change the mode from the CLI, the GNOME extension or `cardwire-gui` and the
window follows, because every cardwire property emits change notifications.

## Requirements

A running `cardwired`, and membership of `wheel` or `sudo` — cardwire's D-Bus policy grants those
groups access, so Switchboard never asks for a password or runs anything as root.

The tray needs a StatusNotifierItem host. On GNOME that is the
[AppIndicator](https://extensions.gnome.org/extension/615/appindicator-support/) extension.

## Build

```sh
sudo pacman -S gtk4 libadwaita vala meson blueprint-compiler libdbusmenu-glib
```

```sh
meson setup build
meson compile -C build
```

### Running from the build tree

Two environment variables are needed uninstalled. The GSettings schema is not installed yet, and
the tray host is a separate process that resolves the icon through the icon theme rather than
Switchboard's gresource:

```sh
GSETTINGS_SCHEMA_DIR=$PWD/build/data SWITCHBOARD_ICON_PATH=$PWD/data/icons ./build/src/switchboard
```

### Installed

```sh
sudo meson install -C build
switchboard
```

### Checking the daemon without the UI

`--probe` connects to `cardwired`, prints everything it can see and exits. It needs no environment
variables and touches no GTK:

```sh
./build/src/switchboard --probe          # read-only
./build/src/switchboard --probe write    # also round-trips one inert property
```

## Licence

GPL-3.0-or-later.
