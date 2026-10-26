import { absoluteUrl, personSchema, websiteSchema } from "~/utils/structured-data";
import { site } from "~/utils/site";

/**
 * Everything a page needs to be found and shared, in one call:
 *   - the title and description (search results, browser tab);
 *   - a canonical URL, so the same page reached by different addresses counts once;
 *   - Open Graph and Twitter cards, so links shared in chats and social posts show a title, summary and image;
 *   - structured data (JSON-LD): the page's own entries plus who made the site, for search engines and AI.
 * Because the pages are pre-rendered, all of it is written into the HTML, readable without running any JavaScript.
 */
export function usePageSeo(options: {
  title: string;
  description: string;
  /** The page's path, e.g. "/". */
  path: string;
  /** Social card image path (1200 × 630), e.g. "/og/home.png". */
  image?: string;
  /** Extra schema.org objects describing this page's content. */
  schema?: object[];
}) {
  const url = absoluteUrl(options.path);
  const image = absoluteUrl(options.image ?? "/og/home.png");

  useSeoMeta({
    title: options.title,
    description: options.description,
    author: site.author.name,
    ogType: "website",
    ogSiteName: site.name,
    ogTitle: options.title,
    ogDescription: options.description,
    ogUrl: url,
    ogImage: image,
    ogImageWidth: 1200,
    ogImageHeight: 630,
    ogImageAlt: options.title,
    ogLocale: "en_GB",
    twitterCard: "summary_large_image",
    twitterTitle: options.title,
    twitterDescription: options.description,
    twitterImage: image,
  });

  useHead({
    link: [{ rel: "canonical", href: url }],
    script: [
      {
        type: "application/ld+json",
        // One graph: the site, its author, and whatever this page adds.
        innerHTML: JSON.stringify({
          "@context": "https://schema.org",
          "@graph": [websiteSchema(), personSchema(), ...(options.schema ?? [])],
        }),
      },
    ],
  });
}
