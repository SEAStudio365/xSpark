# xSpark

English | [繁體中文](README.zh-TW.md)

A free, open-source macOS menu bar utility that brings **Cut & Paste (⌘X / ⌘V)** to Finder — a feature Finder has never natively supported for moving files.

Press **⌘X** to mark files for moving, then **⌘V** to move them to the new location, just like Windows Explorer. xSpark simulates Finder's native "Move Item Here" action, so it's fully native and safe — no custom file operations, no risk of data loss.

## Why xSpark exists

xSpark started as a feature inside **[MenuSpark – Right Click Menu](https://apps.apple.com/us/app/menuspark-right-click-menu/id6761634857?l=en-US&mt=12)**, my macOS Finder right-click menu extension app. Due to how macOS Accessibility permissions are scoped for Finder Sync extensions, the global ⌘X/⌘V hotkey feature couldn't reliably coexist with the extension architecture — so it was split out into this standalone, lightweight app.

If you like xSpark, check out **MenuSpark** for a full right-click context menu toolkit for Finder: quick actions, custom menu items, file utilities, and more, directly from your Finder right-click menu.

👉 **[MenuSpark - Right Click Menu on the Mac App Store](https://apps.apple.com/us/app/menuspark-right-click-menu/id6761634857?l=en-US&mt=12)**

## Features

- **⌘X to cut, ⌘V to paste** — native move behavior in Finder, powered by Finder's own "Move Item Here"
- Only active while **Finder is frontmost** — never intercepts ⌘X/⌘V in other apps
- Floating HUD confirms what's cut and reminds you to press ⌘V
- Toast notifications for cut/move results
- Optional sound feedback on cut
- Lightweight menu bar app — no Dock icon required, minimal memory footprint

## Requirements

- macOS (Apple Silicon & Intel)
- Accessibility permission (required to register global keyboard shortcuts and simulate Finder actions)

## Installation

1. Clone this repo
2. Open `xSpark.xcodeproj` in Xcode
3. In **Signing & Capabilities**, select your own Apple Developer Team (Automatic signing)
4. Build and run
5. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)

## How it works

xSpark uses the Carbon Event Hot Key API to register ⌘X/⌘V only when Finder is the frontmost app:

- **⌘X**: simulates ⌘C (copy to pasteboard), marks the cut state, and shows a HUD
- **⌘V** (while cutting): simulates ⌥⌘V, triggering Finder's native "Move Item Here"
- **⌘V** (not cutting): falls back to the normal system paste

No files are moved by custom code — xSpark only triggers Finder's own built-in commands.

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**Keywords:** macOS cut and paste, Finder cut paste, move files Finder, Finder cmd+x, macOS file manager utility, Windows-style cut paste for Mac, Finder move file shortcut, macOS menu bar app, MenuSpark, Finder right-click menu, Finder extension utility.
