// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",
  devtools: { enabled: true },
  css: ["~/assets/css/main.css"],
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
        { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" },
        { rel: "apple-touch-icon", href: "/orbit-mark.png" },
        { rel: "preconnect", href: "https://fonts.googleapis.com" },
        { rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: "" },
        {
          rel: "stylesheet",
          href: "https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500..800&family=Inter:wght@400..600&family=JetBrains+Mono:wght@400;500&display=swap",
        },
      ],
      meta: [{ name: "theme-color", content: "#0b0a14" }],
    },
  },
});
