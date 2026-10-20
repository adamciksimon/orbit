# Orbit

Orbit is a macOS app for exposing local development servers through trusted HTTPS domains, e.g. `https://app.local` → `http://localhost:3000`.

It is a native Swift/SwiftUI rewrite of the earlier Tauri + Rust version.

## How it works

- **Projects** are stored in `~/.localcan/projects.bin`. The JSON format is the same as before, so existing configs load unchanged.
- **Proxy**: an in-process HTTPS reverse proxy (Network.framework) listens on port 443. macOS lets unprivileged processes bind 443 on all interfaces, so no root process is needed at all. Each request's `Host` is matched to a route and rewritten to `localhost:<port>` (plus `X-Forwarded-Host`/`X-Forwarded-Proto`), so dev servers that check the host (Vite, webpack) accept it. Responses stream through, so SSE works, and WebSocket upgrades are tunneled.
- **Certificates**: the bundled `mkcert` (`Vendor/mkcert`, embedded into `Contents/MacOS`) manages a local CA in `~/.localcan/mkcert` and issues `~/.localcan/tls/proxy.p12` for every configured domain. The certificate is reissued automatically when domains change. On first launch Orbit adds the CA to your login keychain and marks it trusted for your user. macOS asks for your password or Touch ID. If you dismiss the prompt, use **Trust Certificate…** in the sidebar to try again.
- **DNS**: `.local` domains are published to this Mac through mDNSResponder (local-only A records → 127.0.0.1). A single-word domain like `portfolio` is served as `portfolio.local`. Other domains, like `app.example.com`, can be added to a marked Orbit block in `/etc/hosts` with **Add to /etc/hosts…**, which asks for an admin password.

## Development

Open `Orbit.xcodeproj` in Xcode and run the `Orbit` scheme, or build from the command line:

```bash
xcodebuild -project Orbit.xcodeproj -scheme Orbit build
```

The app is not sandboxed: it runs `mkcert`, writes to `~/.localcan`, and listens on port 443.

## Releasing

Push a version tag from the repo root:

```bash
git tag v0.2 && git push origin v0.2
```

The `Release app` workflow builds an ad hoc signed `Orbit.dmg` (version taken from the tag), publishes it as a GitHub release, and redeploys the website, which always serves the latest release.

To build locally instead:

```bash
scripts/package.sh
```

This builds a Release app and writes `dist/Orbit.dmg`. The app needs an Apple silicon Mac (the bundled `mkcert` is arm64-only) on macOS 15.6 or later.

For a release that opens without warnings, sign it with Developer ID and notarize it. This needs the paid Apple Developer Program.

1. In Xcode › Settings › Accounts › Manage Certificates, add a **Developer ID Application** certificate. Only the team's Account Holder can create one.
2. Create an app-specific password at account.apple.com, then store notarization credentials once:
   ```bash
   xcrun notarytool store-credentials orbit-notary --apple-id you@example.com --team-id TEAMID
   ```
3. Build, sign, notarize and staple:
   ```bash
   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=orbit-notary scripts/package.sh
   ```

Upload `dist/Orbit.dmg` to a GitHub release or your website.

Unsigned builds still work: recipients open the app once, then click **Open Anyway** in System Settings › Privacy & Security.
