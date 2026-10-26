import { faqs, features, site } from "~/utils/site";

/*
 * Structured data (JSON-LD, schema.org): a machine-readable description of the app, who made it and where to get
 * it. Search engines use it for rich results, and AI assistants use it to answer questions like "what is Orbit and
 * is it free?" accurately. Every object links to the others by `@id`, so together they form one graph.
 */

const personId = `${site.author.url}/#person`;
const websiteId = `${site.url}/#website`;
const appId = `${site.url}/#app`;

/** Absolute URL for a path on this site. */
export const absoluteUrl = (path: string) => new URL(path, site.url).href;

export function personSchema() {
  return {
    "@type": "Person",
    "@id": personId,
    name: site.author.name,
    url: site.author.url,
    email: `mailto:${site.author.email}`,
  };
}

export function websiteSchema() {
  return {
    "@type": "WebSite",
    "@id": websiteId,
    url: site.url,
    name: site.name,
    description: site.description,
    inLanguage: "en",
    publisher: { "@id": personId },
  };
}

/** The app: free, open source, for macOS, with its current version and download. */
export function appSchema(version: string, size: string) {
  return {
    "@type": "SoftwareApplication",
    "@id": appId,
    name: site.name,
    description: site.description,
    url: site.url,
    image: absoluteUrl("/orbit-mark.png"),
    screenshot: absoluteUrl("/og/home.png"),
    applicationCategory: "DeveloperApplication",
    applicationSubCategory: "Local HTTPS proxy",
    operatingSystem: site.operatingSystem,
    softwareVersion: version,
    fileSize: size,
    downloadUrl: absoluteUrl(site.downloadUrl),
    featureList: features.map((feature) => feature.title),
    license: `https://opensource.org/licenses/${site.license}`,
    isAccessibleForFree: true,
    sameAs: [site.repoUrl],
    author: { "@id": personId },
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
      url: absoluteUrl(site.downloadUrl),
    },
  };
}

/** The source code on GitHub, linked to the app it builds. */
export function sourceCodeSchema() {
  return {
    "@type": "SoftwareSourceCode",
    name: `${site.name} source code`,
    codeRepository: site.repoUrl,
    programmingLanguage: "Swift",
    license: `https://opensource.org/licenses/${site.license}`,
    targetProduct: { "@id": appId },
    author: { "@id": personId },
  };
}

/** The FAQ as question-and-answer pairs, the format answer engines quote from. */
export function faqSchema(size: string) {
  return {
    "@type": "FAQPage",
    "@id": `${site.url}/#faq`,
    isPartOf: { "@id": websiteId },
    about: { "@id": appId },
    mainEntity: faqs(size).map((item) => ({
      "@type": "Question",
      name: item.q,
      acceptedAnswer: { "@type": "Answer", text: item.a },
    })),
  };
}
