import { site } from "../../app/utils/site";

/**
 * /sitemap.xml: every page on the site, for search engines. Written to a static file at build time (it's in the
 * prerender routes in nuxt.config.ts), so it never goes stale.
 */
export default defineEventHandler((event) => {
  const today = new Date().toISOString().slice(0, 10);
  const pages = [{ path: "/", priority: "1.0" }];
  const entries = pages
    .map(
      ({ path, priority }) =>
        `  <url>\n    <loc>${new URL(path, site.url).href}</loc>\n    <lastmod>${today}</lastmod>\n    <priority>${priority}</priority>\n  </url>`,
    )
    .join("\n");
  setHeader(event, "content-type", "application/xml; charset=utf-8");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`;
});
