/// <reference types="node" />
/**
 * Generates the social-card image in public/og/: what shows up when the site is shared in a chat or on social media.
 *
 * The card is a small HTML page (the app icon, name, tagline and summary), screenshotted at 1200 × 630 by a headless
 * Chromium browser. Run it after changing the tagline or description:
 *
 *   node scripts/og-images.ts
 *
 * It uses Brave by default; set OG_BROWSER to another Chromium-based browser's executable to use that instead.
 */
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { site } from "../app/utils/site.ts";

const BROWSER =
  process.env.OG_BROWSER ?? "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser";
const ROOT = resolve(import.meta.dirname, "..");
const OUTPUT = join(ROOT, "public/og");
const ICON = pathToFileURL(join(ROOT, "public/orbit-mark.png")).href;

const escape = (text: string) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const cardHtml = `<!doctype html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; margin: 0; }
  body {
    width: 1200px; height: 630px; overflow: hidden; position: relative;
    padding: 64px 72px; display: flex; flex-direction: column;
    background: radial-gradient(700px 420px at 85% 50%, rgba(143,136,255,.2), transparent 70%), #0b0a14;
    color: #f2f0fa; font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
  }
  .ring { position: absolute; border-radius: 50%; border: 2px solid; }
  .ring.a { width: 820px; height: 820px; right: -300px; top: -360px; border-color: rgba(255,138,91,.22); }
  .ring.b { width: 620px; height: 620px; right: -120px; bottom: -380px; border-color: rgba(143,136,255,.22); }
  .icon { position: absolute; right: 100px; top: 50%; width: 300px; height: 300px; translate: 0 -50%;
          border-radius: 23%; box-shadow: 0 30px 60px rgba(255,138,91,.3); }
  .brand { font-size: 28px; font-weight: 600; color: #a39fb8; letter-spacing: .02em; }
  h1 { margin-top: auto; font-size: 112px; font-weight: 800; letter-spacing: -.045em; line-height: 1; }
  h2 { margin-top: 18px; max-width: 660px; font-size: 40px; font-weight: 700; line-height: 1.15; letter-spacing: -.02em;
       background: linear-gradient(100deg, #ff8a5b, #8f88ff); -webkit-background-clip: text; color: transparent; }
  p { margin-top: 20px; max-width: 640px; color: #a39fb8; font-size: 25px; line-height: 1.35; }
  code { color: #f2f0fa; font-family: "SF Mono", Menlo, monospace; font-size: .9em; }
  .url { margin-top: 30px; color: #6b6783; font-size: 22px; }
</style></head><body>
  <div class="ring a"></div><div class="ring b"></div>
  <img class="icon" src="${ICON}">
  <div class="brand">Free &amp; open source for macOS</div>
  <h1>${escape(site.name)}</h1>
  <h2>${escape(site.tagline)}</h2>
  <p>Point <code>https://app.local</code> at <code>localhost:3000</code> in two clicks. No certificate warnings.</p>
  <div class="url">${escape(site.url.replace("https://", ""))}</div>
</body></html>`;

mkdirSync(OUTPUT, { recursive: true });
const scratch = mkdtempSync(join(tmpdir(), "og-cards-"));
try {
  const page = join(scratch, "home.html");
  writeFileSync(page, cardHtml);
  const output = join(OUTPUT, "home.png");
  execFileSync(
    BROWSER,
    [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      "--window-size=1200,630",
      `--screenshot=${output}`,
      pathToFileURL(page).href,
    ],
    { stdio: "ignore" },
  );
  console.log("public/og/home.png");
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
