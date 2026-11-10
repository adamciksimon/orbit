# Orbit website

The product site for [Orbit](../orbit-app), live at [orbit.simon-studio.cc](https://orbit.simon-studio.cc). It's a
Nuxt app that runs on Cloudflare Workers; every page is prerendered, so Cloudflare serves it as static files and the
Worker only runs for anything else (like a 404).

## Development

```bash
vp install
vp run dev
```

The download button points at `/downloads/Orbit.dmg`, which isn't in git. To try it locally, put a DMG there (for
example `gh release download --pattern Orbit.dmg --dir public/downloads`).

## Checks

```bash
vp check
```

## Build and preview

```bash
vp run build
vp exec wrangler dev --local
```

`vp run build` prerenders the pages, `sitemap.xml` and `llms.txt` into `.output/public` and builds the Worker into
`.output/server`. `wrangler dev` runs both the way Cloudflare does.

## Deploy

Pushing changes to `orbit-web/` on `main` (or releasing a new app version) runs
[`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml): it downloads the latest release's DMG, builds
the site with that version and size, and deploys it with `wrangler deploy` (config in [`wrangler.jsonc`](wrangler.jsonc)).
It needs the `CLOUDFLARE_API_TOKEN` repository secret.

To deploy by hand:

```bash
vp run build
vp exec wrangler deploy
```
