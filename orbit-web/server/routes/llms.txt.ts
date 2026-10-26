import { faqs, features, site, steps } from "../../app/utils/site";

/**
 * /llms.txt: a plain-text summary of the site for AI assistants and the tools that feed them (the llmstxt.org
 * format: a title, a one-line summary, then sections of links with descriptions). It's generated from the same data
 * as the page and written to a static file at build time, with the version and size of the latest release.
 */
export default defineEventHandler((event) => {
  const { appVersion: version, appSize: size } = useRuntimeConfig(event).public;
  const link = (path: string) => new URL(path, site.url).href;
  const lines = [
    `# ${site.name}`,
    "",
    `> ${site.description}`,
    "",
    `${site.name} is a free, open-source (${site.license}) macOS app made by ${site.author.name} (${site.author.url}). ` +
      `It runs on ${site.requirements}. The current version is ${version} (${size}).`,
    "",
    "## How it works",
    "",
    ...steps.map((step, index) => `${index + 1}. ${step.title}: ${step.body}`),
    "",
    "## Features",
    "",
    ...features.map((feature) => `- ${feature.title}: ${feature.body}`),
    "",
    "## FAQ",
    "",
    ...faqs(String(size)).flatMap((item) => [`### ${item.q}`, "", item.a, ""]),
    "## Links",
    "",
    `- [Website](${site.url})`,
    `- [Download for macOS](${link(site.downloadUrl)})`,
    `- [Source code on GitHub](${site.repoUrl})`,
    `- [${site.support.label}](${site.support.href})`,
    `- Contact: ${site.author.email}`,
    "",
  ];
  setHeader(event, "content-type", "text/plain; charset=utf-8");
  return lines.join("\n");
});
