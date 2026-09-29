# MSL for VS Code (preview)

Opens folders inside [msl](https://github.com/onexay/msl) distros, like the WSL extension on Windows. VS Code talks to the VS Code Server in the distro over managed pipes (msl → vsock → the server's Unix socket). It uses no SSH and opens no TCP port on macOS. Design: [onexay/msl#38](https://github.com/onexay/msl/issues/38) (option C′), milestone Sodium.

The extension uses VS Code's proposed `resolvers` API, so it isn't on the Marketplace. msl ships it (`share/msl/msl.vsix`) and sets it up:

```console
$ msl --manage-ide                              # shows the IDEs found and asks
$ msl --manage-ide --ide vscode --install       # or vscode-insiders, vscode-oss (vscodium), cursor, all
$ msl --manage-ide --ide all --uninstall
```

It installs the extension with the IDE's own CLI and adds `"enable-proposed-api": ["onexay.msl"]` to its `argv.json`, keeping comments and other keys. The first change saves a backup, `argv.json.msl-backup`. The installer runs it for the IDEs it finds, unless you pass `--no-ide`, and `msl --uninstall` undoes it. Quit and reopen the IDE (⌘Q), then run **MSL: Connect to Distro**. You can also open `vscode-remote://msl+<distro>/home/<user>` directly.

To build the `.vsix`: `npm install && npm run package` (writes `dist/msl-<version>.vsix`). To bundle a local build into msl: `MSL_VSIX=<this repo>/dist/msl-<version>.vsix scripts/build.sh` in an msl checkout.

Every connection goes through msld's `connect.sock`. With an older msld that doesn't have it, the extension falls back to one `msl -e … msl-bridge` process per connection. On first connect to a distro, the extension installs the VS Code Server that matches your VS Code into `~/.vscode-server/bin/<commit>`. It downloads the server on macOS, caches it in `~/Library/Caches/msl/vscode-server/` for every distro to reuse, and pipes it in, so the distro needs no `curl` or `wget` (stock Debian has neither). The server listens on `~/.vscode-server/msl/<commit>.sock`. Forwarded ports listen on macOS's `127.0.0.1`.

**Which msl:** the `msl.path` setting if it's set. Otherwise the msl that ran `msl --manage-ide --install`, which records its path in `~/Library/Application Support/msl/cli-path`, so any install location works. Failing both, `~/.local/bin/msl`, then `/usr/local/bin/msl`, then `PATH`. It must be msl 0.1.3 or newer, because the extension relies on `--list --json`. Running `build/bin/msl --manage-ide` points the extension at a development build.

**Troubleshooting:**
- *"No remote extension installed to resolve msl":* the extension didn't activate. Output › Log (Extension Host) shows `CANNOT use API proposal: resolvers`. Run `msl --manage-ide`, or add `enable-proposed-api` to `~/.vscode/argv.json` by hand (**Preferences: Configure Runtime Arguments**). Then quit VS Code with ⌘Q; closing the window isn't enough.
- *"msl --list --verbose --json exited with 255":* the extension found an `msl` older than 0.1.3. Run `msl --manage-ide --install` with the msl you want, or set `msl.path`.

**Licence note:** the VS Code Server is Microsoft's build, which is licensed for use with VS Code.

## Testing

msl's `Tests/e2e/sodium.sh` covers everything below the extension: `msl-bridge`, `connect.sock`, its allowlist, and idle-timeout sessions. The extension needs a manual check. Launch an isolated VS Code so your own profile is left alone. Keep `--user-data-dir` short, because VS Code's IPC socket path must be at most 103 characters.

```console
$ code --user-data-dir /tmp/msl-vsc --extensions-dir /tmp/msl-vsc-ext --enable-proposed-api onexay.msl \
    --extensionDevelopmentPath=$PWD --folder-uri vscode-remote://msl+<distro>/home/<user>
```

- [ ] **Open:** the window connects, and the log (Output › MSL, or `exthost/onexay.msl/*.log`) shows `server at …`. No `msl` processes are running for pipes.
- [ ] **VM restart:** `msl --shutdown` while the window is open. VS Code resolves again, `resolve()` starts the distro and server, and the window reloads.
- [ ] **Forwarded port:** start a server in the distro. It's auto-forwarded, and a large download through the local port matches its hash even when read slowly (`curl … | shasum`).
- [ ] **Two distros:** windows on two distros at once, each with its own server and label. Use the installed `.vsix` for this: a second launch with `--extensionDevelopmentPath` reloads the development window instead of opening a new one.
- [ ] **Label:** the window title and remote indicator show `MSL: <distro>`.
- [ ] **Install:** install the `.vsix` into a normal profile, add `enable-proposed-api` to `~/.vscode/argv.json`, then run **MSL: Connect to Distro**.

## Release

Each version is a GitHub release, `vscode-<version>`.

1. Bump `"version"` in `package.json` and push. CI's *VS Code extension* workflow builds the `.vsix` as artifact `vscode-<version>`.
2. Run `./publish.sh`. It publishes that artifact with `release.sha256`, after checking that CI built it from a tree identical to HEAD's.
3. In msl, run `scripts/pin.sh vscode vscode-<version>` and commit the pin. msl releases bundle the pinned `.vsix`.

## Contributing

Same rules as msl: see its [CONTRIBUTING.md](https://github.com/onexay/msl/blob/main/CONTRIBUTING.md). Sign off every commit (`git commit -s`, [DCO](https://developercertificate.org/)).
