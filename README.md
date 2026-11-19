# TripleClick

A tiny macOS menu-bar app: **click the trackpad with three fingers to middle-click.**
Open a link in a new tab, close a tab, paste in a terminal, and so on.
To middle-drag, click with three fingers, keep holding, lift two fingers and drag with one.

The mouse icon in the menu bar lets you switch it off, turn middle-drag off (Drag Enabled), launch it at login, or quit.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/wilu222/tripleclick/main/install.sh | bash
```

(Read [install.sh](install.sh) first if you like. It downloads the latest release zip into `/Applications` and opens it.)

Or download `TripleClick.zip` from [Releases](https://github.com/wilu222/tripleclick/releases).
Because the app isn't notarized, macOS will block the first launch. Allow it under
System Settings → Privacy & Security → **Open Anyway**, or run
`xattr -dr com.apple.quarantine /Applications/TripleClick.app`.

Or build from source (needs the Xcode command line tools):

```sh
git clone https://github.com/wilu222/tripleclick && cd tripleclick && make install
```

On first launch, grant **Accessibility** access in System Settings → Privacy & Security. The app needs it to change clicks.

## Uninstall

Quit the app, delete `/Applications/TripleClick.app`, and remove it from the Accessibility list.

## License

[MIT](LICENSE)
