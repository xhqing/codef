<div align="center">
  <img src="assets/logo.svg" alt="codef" width="640">

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)
  [![Version](https://img.shields.io/badge/Version-0.1.0-blue)](CHANGELOG.md)
  [![Type](https://img.shields.io/badge/Type-CLI-4F46E5)](#)
  [![Visitors](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/xhqing/xhqing/main/traffic/badges/codef.json)](https://github.com/xhqing)

  [简体中文](README_cn.md)
</div>

# codef

`codef` is a tiny macOS terminal tool: **open VSCode fullscreen, with the window you just opened guaranteed to be on top**. It is equivalent to `code <dir>` + auto fullscreen + target window raised.

```bash
codef                     # open the current directory, fullscreen
codef ~/Developer/blog    # open a given directory, fullscreen
```

## Problems it solves

Bare `code <dir>` + a simulated fullscreen hotkey has three pitfalls, all fixed here:

1. **Wrong window on top**: macOS `activate` only brings the VSCode *app* to the front — with multiple windows open, the topmost one may not be the window you just asked for.
2. **Fragile fixed delays**: window creation is asynchronous (slow on cold start), so a fixed `sleep` before sending the hotkey can fire too early and do nothing.
3. **Accidentally un-fullscreening**: pressing Ctrl+Cmd+F on a window that is already fullscreen *exits* fullscreen.

## How it works

1. Record the titles of existing VSCode windows before opening anything;
2. Run `code <dir>` (VSCode decides whether to reuse an existing window or open a new one);
3. Poll until the target window appears — matched by window title (VSCode titles look like "folder — file"), preferring the window that is **newly created by this invocation**, so other windows never steal the focus;
4. Click the matching item in the menu-bar **Window** menu to bring the target window to the front (system-level focus semantics — works even when the target window lives on **another Space or is already fullscreen**); falls back to AXRaise when the menu is unavailable;
5. Check the window's `AXFullScreen` attribute first, and send Ctrl+Cmd+F **only when it is not fullscreen** — never un-fullscreens an existing window.

## Install & Requirements

- macOS only; requires the `code` CLI that ships with VSCode;
- **The terminal app that runs `codef` must be granted Assistive Access** (System Settings → Privacy & Security → Accessibility), otherwise window enumeration and synthetic keystrokes are rejected (`not allowed assistive access`);
- Install: drop the `codef` script somewhere on your `PATH` (e.g. `~/.local/bin/`) and make it executable.

Run `CODEF_DEBUG=1 codef` to print per-stage debug state when troubleshooting.

## Development vs Production

This repo is the **development directory** of `codef` (`~/Developer/codef`); the **production directory** is the local `~/.local/bin/` (the copy actually running). Rules:

- The production copy must come **only from a released artifact** (tag + GitHub Release; install by downloading/copying from the Release) — never run development sources directly, never symlink them into place; running and development versions stay strictly isolated;
- Both sides carry a `# version:` line at the top of the script, kept in sync with the repo's `VERSION` file, so you can always tell whether the production copy lags behind the latest release.

## License & Attribution

Copyright (c) 2026 All Contributors. Released under the [MIT License](LICENSE.md).

Attribution: if you use or reference this project, please keep the copyright notice and credit the source: [codef](https://github.com/xhqing/codef).
