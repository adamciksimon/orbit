// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",
  devtools: { enabled: true },
  css: ["~/assets/css/fonts.css", "~/assets/css/main.css"],
  // Inline all CSS, global stylesheets included, into each page's HTML, so the first paint doesn't wait for a
  // stylesheet request. server/plugins/async-entry-css.ts stops the duplicate entry stylesheet blocking rendering.
  features: { inlineStyles: true },
  hooks: {
    // Nuxt adds <link rel="prefetch"> for every lazy chunk (here: the error pages), which slow connections download
    // before the page has finished loading. They're fetched on demand instead.
    "build:manifest": (manifest) => {
      for (const resource of Object.values(manifest)) {
        resource.prefetch = false;
      }
    },
  },
  runtimeConfig: {
    public: {
      // The deploy workflow sets these from the latest GitHub release
      // (NUXT_PUBLIC_APP_VERSION, NUXT_PUBLIC_APP_SIZE).
      appVersion: "0.1",
      appSize: "3.5 MB",
    },
  },
  app: {
    head: {
      htmlAttrs: { lang: "en" },
      link: [
        // Tells AI tools where the plain-text summary of the site is.
        { rel: "alternate", type: "text/plain", href: "/llms.txt", title: "llms.txt" },
        { rel: "icon", href: "/favicon.ico", sizes: "32x32" },
        { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" },
        { rel: "apple-touch-icon", href: "/apple-touch-icon.png" },
        // The fonts the first screen needs (headline and body text), requested alongside the HTML. Without
        // crossorigin the preload doesn't match the font request and the file downloads twice.
        ...["bricolage-grotesque-latin", "inter-latin"].map(
          (name) =>
            ({
              rel: "preload",
              href: `/fonts/${name}.woff2`,
              as: "font",
              type: "font/woff2",
              crossorigin: "anonymous",
            }) as const,
        ),
      ],
      meta: [{ name: "theme-color", content: "#0b0a14" }],
    },
  },
  // A full Nuxt app on Cloudflare Workers (`vp run build`). Every page is still prerendered to a complete HTML file
  // (text, metadata, structured data) that Cloudflare serves as a static asset without running the Worker, so search
  // engines and AI crawlers can read it without JavaScript. The Worker only handles what isn't prerendered, such as
  // unknown addresses, which now get a real 404. `crawlLinks` finds pages by following links; the routes below make
  // sure nothing is missed, including the generated sitemap.xml and llms.txt.
  nitro: {
    preset: "cloudflare-module",
    prerender: {
      crawlLinks: true,
      autoSubfolderIndex: false,
      routes: ["/", "/sitemap.xml", "/llms.txt"],
    },
  },
  ssr: true,
});
