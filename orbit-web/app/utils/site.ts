/* The site's content in one place: the page, llms.txt, the sitemap and the structured data all read from here. */

export const site = {
  name: "Orbit",
  /** The live address, used for canonical links, social cards, the sitemap and llms.txt. */
  url: "https://orbit.simon-studio.cc",
  tagline: "Trusted HTTPS domains for your local dev servers",
  /** One-sentence summary for search results, social cards and AI tools. */
  description:
    "Orbit is a native macOS app that gives every local dev server a real, trusted HTTPS address like https://app.local. No config files, no root daemon, no certificate warnings.",
  requirements: "macOS 15.6 or later on Apple silicon",
  operatingSystem: "macOS 15.6",
  downloadUrl: "/downloads/Orbit.dmg",
  repoUrl: "https://github.com/adamciksimon/orbit",
  license: "MIT",
  support: { label: "Support Orbit on Ko-fi", href: "https://ko-fi.com/simonadamcik" },
  author: {
    name: "Simon Adamcik",
    url: "https://simon-studio.cc",
    email: "hello@simon-studio.cc",
  },
};

export const features = [
  {
    icon: "lock",
    title: "Certificates your browser trusts",
    body: "A bundled mkcert creates a local certificate authority and adds it to your login keychain once. Every domain is covered, and the certificate is reissued automatically when your domains change.",
  },
  {
    icon: "radar",
    title: ".local names, zero setup",
    body: "Domains ending in .local are announced to your Mac over mDNS. Type portfolio and Orbit serves portfolio.local, with no hosts file and no DNS server.",
  },
  {
    icon: "globe",
    title: "Or bring any domain",
    body: "Want app.example.com? Orbit keeps a clearly marked block in /etc/hosts and updates it for you with a single admin prompt.",
  },
  {
    icon: "shield",
    title: "No root daemon",
    body: "The proxy runs inside the app on port 443. macOS lets regular processes bind it, so there's no privileged helper running in the background.",
  },
  {
    icon: "bolt",
    title: "Made for dev servers",
    body: "The Host header is rewritten to localhost with X-Forwarded-Host and -Proto added, so Vite, webpack and friends accept requests without allowlist changes.",
  },
  {
    icon: "stream",
    title: "Streams and WebSockets",
    body: "Responses stream through as they're produced, so server-sent events work and WebSocket upgrades (hot reload included) are tunneled untouched.",
  },
] as const;

export const steps = [
  {
    title: "Add a project",
    body: "Group related servers together: a storefront, its API, the docs site.",
  },
  {
    title: "Map a domain to a port",
    body: "Type a name and the port your dev server is listening on. That's the whole config.",
  },
  {
    title: "Open it over HTTPS",
    body: "Click the link. Green padlock, real origin, cookies and service workers behave like production.",
  },
];

/** The FAQ; `size` is the current download size from the latest release. */
export const faqs = (size: string) => [
  {
    q: "Is Orbit open source?",
    a: "Yes. The macOS app and this website are on GitHub at github.com/adamciksimon/orbit. Issues and pull requests are welcome.",
  },
  {
    q: "What do I need to run it?",
    a: `A Mac with Apple silicon running macOS 15.6 or later. The download is about ${size}.`,
  },
  {
    q: "Why does macOS ask for my password on first launch?",
    a: "Orbit adds its local certificate authority to your login keychain and marks it as trusted for your user. macOS asks you to confirm with your password or Touch ID. If you dismiss it, click Trust Certificate… in the sidebar to try again.",
  },
  {
    q: "macOS says it can't verify the developer.",
    a: "Open Orbit once, then go to System Settings › Privacy & Security and click Open Anyway. You only need to do this the first time.",
  },
  {
    q: "Where is my configuration stored?",
    a: "Projects live in ~/.orbit/projects.bin, and the local CA and issued certificate live under ~/.orbit as well. Nothing leaves your machine.",
  },
  {
    q: "Can other devices on my network open my domains?",
    a: "Not by default. Your domains resolve only on your own Mac, and the proxy only accepts connections from it. Turn on Share on local network to open your .local domains from a phone or another computer on the same network; share Orbit's root certificate with those devices so they trust it.",
  },
];
