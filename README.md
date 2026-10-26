# Pouch

A tiny floating shelf for macOS. Park files and screenshots on it, switch apps, then drag them out into Slack, Figma, a browser, Jira, Finder, or anywhere else that takes files.

Take a screenshot and it jumps into the pouch by itself, already waiting next to the upload field you were about to drag it into.

<!-- TODO: replace with a demo GIF, e.g. docs/demo.gif -->
_Demo GIF coming soon._

## What it does

- **Floating shelf**: stays above your windows on every Space and over full-screen apps, without stealing focus from the app you're using.
- **Drag in**: files, folders, images, links and text. Files are kept by reference (bookmarks), so moving or renaming them doesn't break anything. Nothing is copied.
- **Drag out**: one item or a whole selection, as real files, into any app.
- **Auto-collects screenshots** taken with ⌘⇧3, ⌘⇧4 or ⌘⇧5, wherever you save them.
- **Quick Look, Reveal in Finder, Copy, Open**, plus a clear-all button.
- **It's a little creature.** The shelf is a canvas pouch with a stitched leather flap, and the flap has eyes.
  - Its eyes follow your cursor, blink, and wander off when you stop moving.
  - It naps when it's empty, and wakes up when you come close.
  - When you drag something over it, the flap lifts open. Drop it, and you can see it swallow.
  - New screenshots get a double take, and "Clear all" shakes everything out.
- **Things look like what they are.** Screenshots and photos keep their real shape, text arrives as a paper slip, and links as a luggage tag.
- **Four leathers** for the flap: Cognac, Oxblood, Olive and Navy, plus optional sound effects. Everything respects Reduce Motion.

No accounts, no cloud, no analytics.

## Install

1. Download `Pouch.zip` from the [latest release](../../releases/latest), unzip it, and move **Pouch.app** to `/Applications`.
2. Pouch isn't notarized by Apple, so macOS will refuse to open it the first time. Do one of these:
   - **macOS 15 and later:** open Pouch once and dismiss the warning. Then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   - **macOS 14:** right-click Pouch.app → **Open** → **Open**.
   - **Or, from Terminal**, remove the quarantine flag:
     ```sh
     xattr -dr com.apple.quarantine /Applications/Pouch.app
     ```
3. Pouch lives in the menu bar (the tray icon). Click the icon to show or hide the shelf, and right-click it for the menu. There's no Dock icon.

The first time a screenshot is collected, macOS asks whether Pouch may access your Desktop (or wherever your screenshots go). Allow it so Pouch can see new screenshots and show thumbnails.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌥⌘P | Show or hide the shelf, from anywhere (change it in Settings) |
| Space | Quick Look the selected items |
| ⌫ or ⌦ | Remove from the shelf (your files stay put) |
| ⌘A | Select all |
| ⌘C | Copy (images paste as pictures) |
| ⌘O or double-click | Open |
| Esc | Deselect, or hide the shelf |
| ⌘-click / ⇧-click | Add to the selection / select a range |

Click the menu bar icon (or press ⌥⌘P) to show or hide the shelf. Esc hides it too. Pouch remembers whether you left it open.

The shelf handles keys once you've clicked it. Right-click an item for Open, Reveal in Finder, Quick Look, Copy and Remove.

> Note: ⌥⌘P is also Finder's "Show Path Bar". Pouch's global shortcut wins while Pouch is running; pick another one in Settings if you use that.

## Screenshots, in a bit more detail

Pouch watches for new screenshots two ways at once:

- a **Spotlight query** for files macOS marks as screen captures (`kMDItemIsScreenCapture`), which works wherever screenshots are saved, and
- a **folder watcher** on your screenshot location (`defaults read com.apple.screencapture location`, `~/Desktop` by default), which is faster and works even if Spotlight indexing is off.

Both check the same metadata, so renaming the screenshot format or using another language doesn't matter.

With the floating thumbnail enabled (the macOS default), macOS only saves the file once the thumbnail slides away, about 5 seconds. To get screenshots instantly, turn off **Show Floating Thumbnail** in the Screenshot app (⌘⇧5 → Options).

Screenshots copied to the clipboard (with ⌃) never become files, so Pouch doesn't see them.

## Build from source

Requirements: Xcode 26 or later (the app uses the macOS 26 SDK for Liquid Glass but runs on macOS 14+) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate            # creates Pouch.xcodeproj from project.yml
xcodebuild -project Pouch.xcodeproj -scheme Pouch -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Pouch.app
```

Run the tests:

```sh
xcodebuild -project Pouch.xcodeproj -scheme Pouch -destination 'platform=macOS' test
```

The `.xcodeproj` isn't checked in. Edit `project.yml` and regenerate instead. The only dependency is [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for the global hotkey, fetched by Swift Package Manager.

### Layout

```
project.yml       XcodeGen project definition
Pouch/            the app: AppKit windows and menus, SwiftUI views
  App/            app delegate, menu bar, hotkey
  Shelf/          the floating panel, drag in/out, Quick Look, actions
  Settings/       settings window, launch at login
  Character/      the pouch's face, flap and the director that brings it to life
  Design/         palette, fabric colorways, shapes, grain, motion
PouchCore/        UI-free model and services (unit tested)
  Models/         ShelfItem, ShelfStore
  Services/       persistence, bookmarks, drop inbox, screenshot watcher
PouchCoreTests/   XCTest
scripts/          app icon generator
```

### Debug helpers

Debug builds read a few environment variables:

- `POUCH_DATA_DIR=/some/folder` stores the shelf there instead of `~/Library/Application Support/Pouch`.
- `POUCH_SNAPSHOT=/tmp/shelf.png` renders the shelf to a PNG after launch (`POUCH_SNAPSHOT_DELAY` sets the delay in seconds, `POUCH_SNAPSHOT_WINDOW=settings` captures Settings instead).
- `POUCH_APPEARANCE=dark|light` forces an appearance, `POUCH_DEBUG_HOVER=1` shows the drop-hover state, and `POUCH_DEBUG_REACT=gulp|snap|shake` fires a reaction after one second (handy with a snapshot delay of about 1.2 s).
- Any setting can be overridden for one run with a launch argument, e.g. `Pouch.app/Contents/MacOS/Pouch -theme navy`.

## Where things are stored

- Shelf contents: `~/Library/Application Support/Pouch/shelf.json`
- Images dropped without a file (for example from a browser) and files delivered by apps like Mail: `~/Library/Application Support/Pouch/Drops/`. These are Pouch's own copies and are deleted when you remove them from the shelf. Pouch never deletes your other files.

## License

MIT. See [LICENSE](LICENSE).
