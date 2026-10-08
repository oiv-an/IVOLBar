# IVOL Bar

**Keep the menu bar useful. Hide the middle, keep both sides visible.**

[Русская документация](README.ru.md) · [Download](https://github.com/oiv-an/IVOLBar/releases/latest) · [Report an issue](https://github.com/oiv-an/IVOLBar/issues) · [MIT license](LICENSE)

IVOL Bar is a small, open-source macOS menu bar utility written in Swift and Objective-C with AppKit. Arrange icons using the standard Command-drag gesture, then collapse the group between two markers.

```text
Always visible    │    Collapsible icons    ‹    Always visible
```

> **Experimental — macOS 27, Apple Silicon.** Tested on macOS 27.0.1 (arm64). IVOL Bar uses an undocumented Apple framework. macOS updates can break it. The first release is ad-hoc signed, **not Developer ID signed or notarized**. It is not an App Store application.

## Features

- Hide the group between a divider and an arrow; keep both sides visible.
- Click the arrow to collapse or expand.
- Optional auto-hide after the pointer leaves the menu bar: 3, 5, 10 or 30 seconds.
- Native menu bar icons: no separate replacement panel.
- No account, network service, analytics or external package dependencies.
- Local diagnostics and safe release of the visibility restriction when the application quits.

## Requirements

|                      | Requirement                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------------- |
| Runtime              | macOS 27 or later; only 27.0.1 has been verified                                             |
| Release architecture | Apple Silicon / arm64; Intel is not tested or shipped                                        |
| Permission           | Accessibility access to read menu bar icon positions                                         |
| Build                | Xcode Command Line Tools with the macOS 27 SDK, Swift 6.4 toolchain, Clang, Python 3 and zsh |

Older macOS versions are not supported. Availability of the private framework is checked at runtime, but that does not guarantee compatibility with future macOS releases.

## Install the release

1. Download `IVOL-Bar-0.1.3-macos-arm64.zip` and `SHA256SUMS.txt` from [Releases](https://github.com/oiv-an/IVOLBar/releases/latest).
2. Optionally verify the archive in the download folder:

   ```sh
   shasum -a 256 -c SHA256SUMS.txt
   ```

3. Unzip it and move **IVOL Bar.app** into **Applications**. Do not run it directly inside the downloaded archive or keep multiple running copies.
4. Open the app. Since the release is not notarized, macOS may refuse the first launch. Only if you trust the downloaded source, use **System Settings → Privacy & Security → Open Anyway** when macOS offers it, then confirm. Do not disable Gatekeeper globally. If your Mac or organization does not permit this, build from source instead.
5. Grant **IVOL Bar** access in **System Settings → Privacy & Security → Accessibility** when prompted. Depending on your macOS language/version, the label may differ. If the arrow reports missing permission, enable it there and click the arrow again.
6. Arrange the markers and icons as described below. **Auto-hide is off for a new profile**, so you can arrange icons first; turn it on in the menu when ready.

No installer, administrator script or background launch agent is included. Launch at login is not configured automatically; you may add the installed app in **System Settings → General → Login Items** yourself.

## Build from source

Install Apple's Command Line Tools if needed:

```sh
xcode-select --install
```

Check that your selected toolchain provides the macOS 27 SDK and Swift 6.4:

```sh
xcrun --show-sdk-version
xcrun swiftc --version
```

Then clone and build:

```sh
git clone https://github.com/oiv-an/IVOLBar.git
cd IVOLBar
/bin/zsh build.sh
```

The output is `build/IVOL Bar.app`. The script compiles the sources, creates the application bundle, applies an **ad-hoc signature by default**, and verifies it. It does not install, launch, modify preferences, or request permissions. No Homebrew, Swift packages or Xcode project is needed.

### Install your build

Quit any running IVOL Bar through its menu before replacing it. Then, from the project directory:

```sh
ditto 'build/IVOL Bar.app' '/Applications/IVOL Bar.app'
open '/Applications/IVOL Bar.app'
```

If your account cannot write to Applications, use Finder's normal authorization prompt rather than changing directory permissions.

### Signing and output directory

For a stable local signing identity already present in your Keychain:

```sh
IVOL_SIGN_IDENTITY='Your Code Signing Identity' /bin/zsh build.sh
```

To build into a separate directory:

```sh
IVOL_BUILD_DIR="$PWD/build/custom" /bin/zsh build.sh
```

A self-signed development certificate does **not** make downloads trusted on other Macs. Developer ID distribution requires a suitable Apple certificate, appropriate signing settings and a separate notarization process; this repository does not automate that process. Never commit private keys or certificates. Changing signing identity, or replacing an ad-hoc build, can require granting Accessibility permission again.

### Package a release locally

On an Apple Silicon Mac with the required toolchain:

```sh
/bin/zsh scripts/package-release.sh
```

This makes a fresh, ad-hoc-signed build and writes a ZIP and SHA-256 checksum to `dist/0.1.3/`. It neither installs the result nor uploads anything. See [release checklist](docs/RELEASING.md).

## Usage

Before changing membership, open the menu → **Настроить группу по расположению…** (Configure group from positions). Auto-hide pauses until you save or cancel.

1. Hold **⌘ Command** and drag the **│** divider to the left of the **‹** arrow.
2. Drag the icons you want to hide **between** the two markers.
3. Leave important icons outside this group on either side.
4. Choose **Сохранить группу по расположению** (Save group from positions). Then click the arrow to hide or reveal the saved group. The arrow changes direction when collapsed.
5. Click the divider, or right-click the arrow, to open the menu:
   - **Показать всё** — Show all.
   - **Автоскрытие после ухода мыши** — Auto-hide after the pointer leaves.
   - **Задержка** — Delay: 3, 5, 10 or 30 seconds; default 5.
   - **Как пользоваться** — Instructions.
   - **Открыть диагностику** — Open local diagnostics.
   - **Завершить IVOL Bar** — Quit.

The application UI currently uses Russian labels; this guide includes their English equivalents.

Auto-hide waits while the pointer is in a menu bar, a mouse button or Command is held, or IVOL Bar's own menu is open. Hovering does not expand the group. If hiding fails, the preference stays enabled and automatic retry waits at least 30 seconds. Manual retry remains available.

Exiting or relaunching a previously known application does not expand the group. A newly encountered application, sleep/wake, or a display change releases the restriction for safety; after the displays settle, auto-hide reuses the saved membership rather than transient coordinates. Membership survives relaunches; newly encountered apps are not added automatically. The diagnostic environment variable `IVOLBAR_DIAGNOSTIC=1` deliberately expands after five seconds; do not use it for normal operation.

## How it works and limitations

IVOL Bar reads hosted status-item geometry from macOS's MenuBarAgent using Accessibility. It identifies the two markers on one display and uses the private MenuBarClientCore assessment-mode mechanism to allow applications outside the group while restricting those inside it.

Important limitations:

- **Per application, not per individual icon.** When saving a group, if an application has multiple icons and any is outside the group, the application is kept visible.
- System menu items are requested to remain visible; private system behavior may still differ between macOS versions.
- Updates, changed paths and duplicate installations of other apps do not block the entire group from collapsing. Membership is persisted by bundle identifier without installation-path bindings. Geometry is used only for initial selection and explicitly saving a new group; sleep and system-driven marker movement do not change membership. However, macOS can still hide a conflicting copy outside the group. Expand using the arrow to access it. Dragging sets a new position but does not by itself guarantee resolution of the system's duplicate-app conflict.
- Compatibility is not universal. Unexpected disappearing icons have been observed with some third-party utilities, including noTunes. Do not depend on IVOL Bar to keep a critical control visible without checking it yourself.
- Independent per-display layouts are not supported. During configuration, the app selects a valid pair of markers with the largest gap. Saved membership is shared across displays. IVOL Bar does not restore the physical macOS icon order; it preserves the selected hiding membership. Notched displays and unusual multi-monitor arrangements may prevent a valid group being found.
- IVOL Bar protects its own open menu from auto-hide; arbitrary third-party menus are not guaranteed to be protected.
- Private API success and retained Accessibility nodes do not prove what is visible. Always visually inspect your layout after installation or a macOS update.

Use **Show all** or quit IVOL Bar to release its visibility restriction. Do not run multiple menu bar hiding utilities simultaneously while diagnosing an issue.

## Troubleshooting

| Symptom                                 | What to check                                                                                                         |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Nothing hides                           | Accessibility permission; divider left of arrow; third-party icons between them; last error in the menu               |
| Auto-hide does not run                  | Enable it in the menu; move the pointer away; release mouse/Command; close the app's menu; allow the configured delay |
| Icons unexpectedly disappear            | Show all or quit; check duplicate app installations and the limitations above                                         |
| Permission stopped working after update | Keep the same app path and signing identity where possible; re-enable Accessibility in System Settings if necessary   |
| Build fails after moving the project    | Select the correct SDK/toolchain and use a fresh output directory; compiler caches can contain absolute paths         |
| A download is blocked                   | Review the unnotarized-release warning; use macOS's per-app Open Anyway only if you trust it, or build locally        |

Local logs are in **Library/Logs/IVOLBar.log inside your user folder**. Preferences use the domain `pro.ivol.bar`; icon placement is managed by macOS and the owning applications. Logs may include application names, paths and icon coordinates. **Redact personal data before attaching diagnostics to an issue.** IVOL Bar does not upload them.

## Update and uninstall

**Update:** quit IVOL Bar, replace the app in Applications with the new version, then open it. Do not remove preferences or rearrange icons. Keep the same installation path. A different signature may require renewing Accessibility permission. Keep a copy of the previous app if you want to roll back.

**Uninstall:** quit IVOL Bar and move its app from Applications to Trash. If you manually added a Login Item, remove it there. Existing preferences and local logs are intentionally retained; uninstalling does not reset other applications' icon positions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Small, focused fixes and compatibility reports are welcome. This is an experimental utility, not a promise of support for every macOS configuration.

## License and references

[MIT](LICENSE) © 2026 Ivan Olyansky. Apple frameworks are system components and are not redistributed.

Related research into macOS 27 menu bar behavior: [Pelmet FAQ](https://github.com/fif7y/pelmet/blob/main/docs/FAQ.md), [Stash design notes](https://github.com/brentc22/stash/blob/main/docs/superpowers/specs/2026-09-22-stash-design.md), and [Ice-2 prototype](https://github.com/teddychan/ice-2/blob/main/scripts/macos27-prototype.m). These links are references, not endorsements or compatibility guarantees.
