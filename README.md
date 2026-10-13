# IVOL Bar

**Keep the menu bar useful. Hide the middle, keep both sides visible.**

[Русская документация](README.ru.md) · [Download](https://github.com/oiv-an/IVOLBar/releases/latest) · [Report an issue](https://github.com/oiv-an/IVOLBar/issues) · [MIT license](LICENSE)

IVOL Bar is a small, open-source macOS menu bar utility written in Swift and Objective-C with AppKit. Arrange icons using the standard Command-drag gesture, then collapse the group between two markers.

```text
Always visible    │    Collapsible icons    ‹    Always visible
```

> **Experimental — macOS 27, Apple Silicon.** Tested on macOS 27.0.1 (arm64). IVOL Bar uses an undocumented Apple framework. macOS updates can break it. The first release is ad-hoc signed, **not Developer ID signed or notarized**. It is not an App Store application.

## Reset

Right-click the arrow → **«Сбросить настройки и расстановку IVOL Bar…»** → **«Сбросить»**. Cancel leaves preferences unchanged.

Reset releases hiding, clears IVOL Bar preferences and historical lists, and recreates its arrow/divider. On macOS 27 the system itself keeps their positions, so they may reappear in the same places. It does not clear other apps' positions, macOS permissions, login items or diagnostic logs.

Command-drag icons you want to keep to the right of │, then choose **«Закончить расстановку»**. Auto-hide stays paused across restarts until arrangement is finished or explicitly cancelled; afterward it is enabled with a five-second delay.

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

1. Download `IVOL-Bar-0.1.4-macos-arm64.zip` and `SHA256SUMS.txt` from [Releases](https://github.com/oiv-an/IVOLBar/releases/latest).
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

This makes a fresh, ad-hoc-signed build and writes a ZIP and SHA-256 checksum to `dist/0.1.4/`. It neither installs the result nor uploads anything. See [release checklist](docs/RELEASING.md).

## Usage

**Left of the divider: hide. Right of the divider: keep visible.** The arrow is only a toggle, not a second boundary. No membership list needs saving.

1. Expand using the arrow. For timer-free arrangement, choose **Настроить группу по расположению…**.
2. Hold **⌘ Command** and drag important icons **right of │**.
3. Leave other icons **left of │**. You can also move the divider with Command.
4. Click the arrow, or **Закончить расстановку** (Finish arranging) if configuring. Identified third-party applications on the left are hidden; system items and IVOL Bar remain allowed.
5. Click the divider, or right-click the arrow, to open the menu:
   - **Показать всё** — Show all.
   - **Автоскрытие после ухода мыши** — Auto-hide after the pointer leaves.
   - **Задержка** — Delay: 3, 5, 10 or 30 seconds; default 5.
   - **Как пользоваться** — Instructions.
   - **Открыть диагностику** — Open local diagnostics.
   - **Завершить IVOL Bar** — Quit.

The application UI currently uses Russian labels; this guide includes their English equivalents.

Auto-hide waits while the pointer is in a menu bar, a mouse button or Command is held, or IVOL Bar's own menu is open. Hovering does not expand the group. If hiding fails, the preference stays enabled and automatic retry waits at least 30 seconds. Manual retry remains available.

Exiting or relaunching a known application does not expand the group. A new application, sleep/wake or display change releases the restriction for safety. After displays settle, membership is recalculated from expanded positions; historical membership is not applied. Diagnostic mode deliberately expands after five seconds and is not intended for normal use.

## How it works and limitations

IVOL Bar reads hosted geometry from MenuBarAgent using Accessibility, identifies the divider separately from the arrow, and uses private MenuBarClientCore to restrict selected applications on the left while allowing others.

Important limitations:

- **Apps must run from /Applications.** macOS 27 matches allowed apps by their LaunchServices registration. An app running from another location (a VS Code extension folder, Xcode DerivedData, a build directory) is hidden even when it sits right of the divider. IVOL Bar lists such apps in its menu. Copy the app to /Applications and launch it from there.
- **Per application, not per individual icon.** If any icon is right of the divider, the whole application remains allowed.
- System menu items are requested to remain visible; private system behavior may still differ between macOS versions.
- Membership is calculated before each collapse from marker positions, without installation-path bindings. Old membership preferences are retained but ignored. The private macOS mechanism can still hide a conflicting application copy outside the group; expand to access it. Moving icons does not resolve system duplicate-copy conflicts.
- Compatibility is not universal. Unexpected disappearing icons have been observed with some third-party utilities, including noTunes. Do not depend on IVOL Bar to keep a critical control visible without checking it yourself.
- Independent per-display hiding is not supported. Membership comes only from the menu bar with the most detected items. Other displays do not veto selection, but the system restriction applies globally. Unknown geometry on the selected display excludes an application. IVOL Bar does not restore other applications' physical icon order.
- IVOL Bar protects its own open menu from auto-hide; arbitrary third-party menus are not guaranteed to be protected.
- Private API success and retained Accessibility nodes do not prove what is visible. Always visually inspect your layout after installation or a macOS update.

Use **Show all** or quit IVOL Bar to release its visibility restriction. Do not run multiple menu bar hiding utilities simultaneously while diagnosing an issue.

## Troubleshooting

| Symptom                                 | What to check                                                                                                         |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Nothing hides                           | Accessibility permission; divider left of arrow; third-party icons between them; last error in the menu               |
| Auto-hide does not run                  | Enable it in the menu; move the pointer away; release mouse/Command; close the app's menu; allow the configured delay |
| Icons unexpectedly disappear            | Is the app running from /Applications? Check the warning in IVOL Bar's menu; then duplicate installations             |
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
