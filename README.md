# MSL Visual Studio Code Extension

Open folders in MSL Linux distributions from VS Code on macOS, like WSL on Windows.

The extension starts VS Code Server inside the selected distribution and connects over MSL's managed pipes and vsock. It does not need an SSH server or a TCP port on your Mac for the connection.

## Install

The extension uses VS Code's proposed remote resolver API, so it is not available on the Marketplace. Install it with MSL:

```sh
msl --manage-ide
```

To install into one editor directly, use:

```sh
msl --manage-ide --ide vscode --install
```

Supported editor IDs are `vscode`, `vscode-insiders`, `vscode-oss` (VSCodium), `cursor` and `all`. The installer enables the proposed API in the editor's `argv.json` and saves a backup before changing it. Quit and reopen the editor after installation; closing its windows is not enough.

To remove the extension from all managed editors and undo the runtime setting:

```sh
msl --manage-ide --ide all --uninstall
```

The MSL installer can also set up detected editors. Pass `--no-ide` to skip editor setup.

## Connect to a distribution

In VS Code, open the Command Palette and choose **MSL: Connect to Distro** or **MSL: Connect to Distro in New Window**. Then select a distribution.

You can also open a remote URI directly:

```text
vscode-remote://msl+<distro>/home/<user>
```

On the first connection, the extension downloads the matching VS Code Server to macOS, caches it, and installs it in the distribution. The distribution does not need `curl` or `wget`. Forwarded ports listen on `127.0.0.1` on your Mac.

## Troubleshooting

- **“No remote extension installed to resolve msl”**
  The proposed API may be disabled. Check **Output → Log (Extension Host)** for `CANNOT use API proposal: resolvers`. Run `msl --manage-ide`, then quit and reopen the editor. You can also enable `onexay.msl` under `enable-proposed-api` in `argv.json` with **Preferences: Configure Runtime Arguments**.

- **“Invalid command line argument: --connect”**
  The extension found an older MSL executable. Run `msl --manage-ide --ide all --install` with the MSL version you want, or set `msl.path` to that executable.

## Build and develop

Build a local VSIX package from the repository root:

```sh
./scripts/build.sh
```

Development builds use the SemVer version from `package.json`. To build a release version locally, set `MSL_VERSION` to its SemVer version. From the MSL repository root, bundle a local VSIX with:

```sh
MSL_VSIX=<path-to-this-repo>/dist/msl-<version>.vsix scripts/build.sh
```

For development, launch VS Code with an isolated profile:

```sh
code --user-data-dir /tmp/msl-vsc \
  --extensions-dir /tmp/msl-vsc-ext \
  --enable-proposed-api onexay.msl \
  --extensionDevelopmentPath="$PWD" \
  --folder-uri vscode-remote://msl+<distro>/home/<user>
```

Keep `--user-data-dir` short. VS Code limits its IPC socket path to 103 characters. The MSL repository's `tests/e2e/sodium.sh` covers the `msl --connect` transport. Check the extension by opening a distribution, restarting its VM with `msl --shutdown`, forwarding a port, and connecting to two distributions at once.

## Release

Push the extension changes to main, then choose **Actions → VS Code extension → Run workflow**. The first SemVer release uses the version in `package.json`; later releases bump from the latest SemVer tag based on commits since that release. Use Conventional Commit subjects: `feat:` bumps minor, `BREAKING CHANGE:` or a type with `!` (such as `feat!:`) bumps major, and other commits bump patch. If package.json has a version higher than the calculated version, the workflow uses it. The workflow creates the version tag and publishes the VSIX and SHA-256 checksum as a GitHub release.

In the MSL checkout, run `scripts/pin.sh vscode <release-tag>` and commit the updated pin files.

## Contributing

Follow the [MSL contribution guidelines](https://github.com/onexay/msl/blob/main/CONTRIBUTING.md). Sign off each commit with `git commit -s` under the [Developer Certificate of Origin](https://developercertificate.org/).

## License

The extension is licensed under Apache-2.0. The VS Code Server is Microsoft's build and is licensed for use with VS Code.
