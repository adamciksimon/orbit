<script setup lang="ts">
const { appVersion: version, appSize: size } = useRuntimeConfig().public;
const downloadUrl = "/downloads/Orbit.dmg";

useSeoMeta({
  title: "Orbit — trusted HTTPS domains for your local dev servers",
  description:
    "Orbit is a native macOS app that gives every local dev server a real, trusted HTTPS address like https://app.local. No config files, no root daemon, no certificate warnings.",
  ogTitle: "Orbit — trusted HTTPS domains for localhost",
  ogDescription: "Point https://app.local at localhost:3000 in two clicks. A tiny native Mac app.",
  ogImage: "/orbit-mark.png",
});

// Mirrors Domain.served / Domain.isValid in the app.
const hostnamePattern = /^(\*\.)?[0-9a-z_-]([0-9a-z._-]*[0-9a-z_-])?$/;

const domainInput = ref("storefront");
const portInput = ref("3000");

const served = computed(() => {
  const normalized = domainInput.value.trim().toLowerCase().replace(/\.+$/, "");
  if (!normalized || normalized.includes(".") || normalized === "localhost") return normalized;
  return `${normalized}.local`;
});
const port = computed(() => Number(portInput.value));
const isValidDomain = computed(() => hostnamePattern.test(served.value));
const isValidPort = computed(
  () => Number.isInteger(port.value) && port.value >= 1 && port.value <= 65535,
);
const resolution = computed(() => {
  if (!isValidDomain.value)
    return { tone: "warn", text: "Not a valid hostname; this proxy is inactive." };
  if (!isValidPort.value) return { tone: "warn", text: "Port must be between 1 and 65535." };
  if (served.value.endsWith(".local") || served.value === "localhost")
    return { tone: "ok", text: "Resolves instantly over mDNS. Nothing else to set up." };
  return {
    tone: "info",
    text: "Orbit adds this domain to its own /etc/hosts block (one admin prompt).",
  };
});

const features = [
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

const steps = [
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

const faqs = [
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
    a: "Projects live in ~/.localcan/projects.bin, and the local CA and issued certificate live under ~/.localcan as well. Nothing leaves your machine.",
  },
  {
    q: "Is any of my traffic exposed to the network?",
    a: ".local records point to 127.0.0.1, and /etc/hosts entries do too, so the domains only resolve on your own Mac.",
  },
];

const openFaq = ref<number | null>(0);
</script>

<template>
  <div class="page">
    <div class="sky" aria-hidden="true">
      <div class="ring ring--sun" />
      <div class="ring ring--planet" />
      <div class="glow" />
    </div>

    <header class="nav">
      <a href="#top" class="brand">
        <OrbitLogo :size="30" />
        <span>Orbit</span>
      </a>
      <nav class="nav__links" aria-label="Sections">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a href="#faq">FAQ</a>
      </nav>
      <a :href="downloadUrl" class="btn btn--small" download>Download</a>
    </header>

    <main id="top">
      <!-- Hero -->
      <section class="hero">
        <h1>
          Real HTTPS domains<br />
          for your <span class="grad">localhost</span>.
        </h1>
        <p class="lede">
          Orbit gives every dev server a trusted address like
          <code>https://app.local</code>. No config files, no root daemon, no certificate warnings.
        </p>
        <div class="cta">
          <a :href="downloadUrl" class="btn btn--primary" download>
            <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
              <path
                fill="currentColor"
                d="M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.8 1.2 1.8 2.6 3.1 2.5 1.3 0 1.7-.8 3.3-.8 1.5 0 1.9.8 3.3.8 1.4 0 2.2-1.2 3-2.5 1-1.4 1.3-2.7 1.4-2.8-.1 0-2.6-1-2.4-4.1zM13.9 5c.7-.8 1.2-2 1-3.1-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.9-1 3 1.1.1 2.2-.6 2.9-1.4z"
              />
            </svg>
            Download for macOS
          </a>
          <a href="#how" class="btn btn--ghost">See how it works</a>
        </div>
        <p class="meta">Apple silicon · macOS 15.6 or later · {{ size }}</p>

        <!-- App window mock -->
        <div
          class="window"
          role="img"
          aria-label="Orbit's main window showing a project with two proxies"
        >
          <div class="window__sidebar">
            <div class="traffic"><i /><i /><i /></div>
            <p class="side__label">Projects</p>
            <ul class="side__list">
              <li class="is-active"><b class="badge">S</b>Storefront</li>
              <li><b class="badge">P</b>Portfolio</li>
              <li><b class="badge">D</b>Docs</li>
            </ul>
            <div class="status">
              <p><i class="led led--aurora" />Proxy running on :443</p>
              <p><i class="led led--aurora" />Local CA trusted</p>
            </div>
          </div>
          <div class="window__main">
            <div class="toolbar">
              <span>Storefront</span>
              <span class="toolbar__icon">+</span>
            </div>
            <div class="form">
              <div class="group">
                <div class="group__title">Storefront</div>
              </div>
              <div class="group__header">
                <span>Proxies</span>
                <span class="mini-btn">+ Add Proxy</span>
              </div>
              <div class="group">
                <div class="row">
                  <div class="fields">
                    <span class="field">storefront</span>
                    <span class="field field--port">3000</span>
                  </div>
                  <p class="route">
                    <span class="link">https://storefront.local</span>
                    <span class="arrow">→</span>
                    <span class="muted">http://localhost:3000</span>
                  </p>
                </div>
                <div class="row">
                  <div class="fields">
                    <span class="field">api.storefront.local</span>
                    <span class="field field--port">8080</span>
                  </div>
                  <p class="route">
                    <span class="link">https://api.storefront.local</span>
                    <span class="arrow">→</span>
                    <span class="muted">http://localhost:8080</span>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Flow -->
      <section class="flow" aria-label="How a request travels through Orbit">
        <div class="node">
          <span class="node__kicker">Browser</span>
          <code>https://storefront.local</code>
          <span class="node__note">🔒 trusted certificate</span>
        </div>
        <div class="wire wire--sun" aria-hidden="true"><span /></div>
        <div class="node node--orbit">
          <OrbitLogo :size="40" />
          <span class="node__kicker">Orbit · :443</span>
          <span class="node__note">terminates TLS, matches Host, rewrites headers</span>
        </div>
        <div class="wire wire--planet" aria-hidden="true"><span /></div>
        <div class="node">
          <span class="node__kicker">Your dev server</span>
          <code>http://localhost:3000</code>
          <span class="node__note">unchanged, unaware</span>
        </div>
      </section>

      <!-- Features -->
      <section id="features" class="section">
        <div class="section__head">
          <p class="kicker">Features</p>
          <h2>Everything production HTTPS gives you. On your laptop.</h2>
          <p class="sub">
            Secure cookies, service workers, OAuth redirects, clipboard and camera APIs: the things
            that quietly break on <code>http://localhost</code> just work.
          </p>
        </div>
        <div class="grid">
          <article v-for="f in features" :key="f.title" class="card">
            <div class="card__icon" aria-hidden="true">
              <svg v-if="f.icon === 'lock'" viewBox="0 0 24 24">
                <rect x="5" y="11" width="14" height="10" rx="2" />
                <path d="M8 11V8a4 4 0 0 1 8 0v3" />
              </svg>
              <svg v-else-if="f.icon === 'radar'" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="2" />
                <path
                  d="M7.8 16.2a6 6 0 0 1 0-8.4M16.2 7.8a6 6 0 0 1 0 8.4M4.9 19.1a10 10 0 0 1 0-14.2M19.1 4.9a10 10 0 0 1 0 14.2"
                />
              </svg>
              <svg v-else-if="f.icon === 'globe'" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="9" />
                <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
              </svg>
              <svg v-else-if="f.icon === 'shield'" viewBox="0 0 24 24">
                <path d="M12 3 5 6v6c0 4.5 3 7.7 7 9 4-1.3 7-4.5 7-9V6l-7-3Z" />
                <path d="m9 12 2 2 4-4" />
              </svg>
              <svg v-else-if="f.icon === 'bolt'" viewBox="0 0 24 24">
                <path d="M13 3 5 14h6l-1 7 8-11h-6l1-7Z" />
              </svg>
              <svg v-else viewBox="0 0 24 24">
                <path d="M3 7h12M3 12h18M3 17h9" />
                <path d="m17 4 3 3-3 3M15 14l3 3-3 3" />
              </svg>
            </div>
            <h3>{{ f.title }}</h3>
            <p>{{ f.body }}</p>
          </article>
        </div>
      </section>

      <!-- How it works + playground -->
      <section id="how" class="section how">
        <div class="section__head">
          <p class="kicker">How it works</p>
          <h2>Three steps. About ten seconds.</h2>
        </div>
        <div class="how__grid">
          <ol class="steps">
            <li v-for="(s, i) in steps" :key="s.title">
              <span class="steps__n">{{ i + 1 }}</span>
              <div>
                <h3>{{ s.title }}</h3>
                <p>{{ s.body }}</p>
              </div>
            </li>
          </ol>

          <div class="play">
            <p class="play__label">Try it: this is exactly how Orbit reads a proxy</p>
            <div class="play__fields">
              <label>
                <span>Domain</span>
                <input
                  v-model="domainInput"
                  spellcheck="false"
                  autocapitalize="off"
                  placeholder="app.example.com"
                />
              </label>
              <label class="play__port">
                <span>Port</span>
                <input v-model="portInput" inputmode="numeric" placeholder="3000" />
              </label>
            </div>
            <div class="play__out">
              <code class="play__url">https://{{ served || "…" }}</code>
              <span class="play__arrow">→</span>
              <code class="play__target">http://localhost:{{ portInput || "…" }}</code>
            </div>
            <p class="play__note" :class="`is-${resolution.tone}`">{{ resolution.text }}</p>
          </div>
        </div>
      </section>

      <!-- FAQ -->
      <section id="faq" class="section faq">
        <div class="section__head">
          <p class="kicker">FAQ</p>
          <h2>Good questions.</h2>
        </div>
        <div class="faq__list">
          <div
            v-for="(item, i) in faqs"
            :key="item.q"
            class="faq__item"
            :class="{ 'is-open': openFaq === i }"
          >
            <button
              type="button"
              :aria-expanded="openFaq === i"
              :aria-controls="`faq-${i}`"
              @click="openFaq = openFaq === i ? null : i"
            >
              {{ item.q }}
              <span class="faq__chev" aria-hidden="true">+</span>
            </button>
            <div :id="`faq-${i}`" class="faq__body" role="region">
              <p>{{ item.a }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Final CTA -->
      <section class="final">
        <OrbitLogo :size="120" class="final__icon" />
        <h2>Put your localhost in orbit.</h2>
        <p>A {{ size }} download for Apple silicon Macs.</p>
        <a :href="downloadUrl" class="btn btn--primary" download>Download Orbit {{ version }}</a>
      </section>
    </main>

    <footer class="foot">
      <span>© {{ new Date().getFullYear() }} Orbit</span>
      <span>Made for people who are tired of clicking through certificate warnings.</span>
    </footer>
  </div>
</template>

<style scoped>
.page {
  position: relative;
  isolation: isolate;
}

/* ---------- background ---------- */
.sky {
  position: absolute;
  inset: 0 0 auto 0;
  height: 1100px;
  overflow: hidden;
  z-index: -1;
  pointer-events: none;
}
.ring {
  position: absolute;
  border-radius: 50%;
  border: 1px solid;
  opacity: 0.5;
}
.ring--sun {
  width: 900px;
  height: 900px;
  top: -420px;
  right: -260px;
  border-color: rgb(255 138 91 / 0.22);
  box-shadow: inset 0 0 120px rgb(255 138 91 / 0.05);
  animation: spin 80s linear infinite;
}
.ring--planet {
  width: 760px;
  height: 760px;
  top: -160px;
  left: -360px;
  border-color: rgb(143 136 255 / 0.2);
  box-shadow: inset 0 0 120px rgb(143 136 255 / 0.05);
  animation: spin 100s linear infinite reverse;
}
.ring::after {
  content: "";
  position: absolute;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  top: 50%;
  left: -5px;
  background: currentColor;
}
.ring--sun::after {
  background: var(--sun);
  box-shadow: 0 0 24px var(--sun);
}
.ring--planet::after {
  background: var(--planet);
  box-shadow: 0 0 24px var(--planet);
}
.glow {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(600px 300px at 50% 10%, rgb(143 136 255 / 0.08), transparent 70%),
    radial-gradient(500px 300px at 70% 0%, rgb(255 138 91 / 0.07), transparent 70%);
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* ---------- nav ---------- */
.nav {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 24px;
  max-width: var(--max);
  margin: 0 auto;
  padding: 14px 24px;
  backdrop-filter: blur(14px) saturate(1.4);
  -webkit-backdrop-filter: blur(14px) saturate(1.4);
  background: rgb(11 10 20 / 0.6);
  border-bottom: 1px solid transparent;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 19px;
  letter-spacing: -0.01em;
}
.nav__links {
  display: flex;
  gap: 24px;
  margin-left: auto;
  font-size: 14px;
}
.nav__links a {
  color: var(--text-muted);
  text-decoration: none;
  transition: color 0.15s;
}
.nav__links a:hover {
  color: var(--text);
}

/* ---------- buttons ---------- */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 13px 22px;
  border-radius: 999px;
  font-weight: 600;
  font-size: 15px;
  text-decoration: none;
  transition:
    transform 0.15s,
    box-shadow 0.2s,
    background 0.2s;
}
.btn:hover {
  transform: translateY(-1px);
}
.btn--primary {
  color: #150f1f;
  background: linear-gradient(135deg, var(--sun), #ffb3c7 45%, var(--planet));
  box-shadow:
    0 0 0 1px rgb(255 255 255 / 0.2) inset,
    0 10px 30px -8px rgb(255 138 91 / 0.45);
}
.btn--primary:hover {
  box-shadow:
    0 0 0 1px rgb(255 255 255 / 0.3) inset,
    0 14px 40px -8px rgb(143 136 255 / 0.5);
}
.btn--ghost {
  color: var(--text);
  border: 1px solid var(--line-strong);
}
.btn--ghost:hover {
  background: rgb(255 255 255 / 0.05);
}
.btn--small {
  padding: 8px 16px;
  font-size: 14px;
  color: var(--text);
  background: rgb(255 255 255 / 0.08);
  border: 1px solid var(--line-strong);
}

/* ---------- hero ---------- */
.hero {
  max-width: var(--max);
  margin: 0 auto;
  padding: 72px 24px 40px;
  text-align: center;
}
h1,
h2,
h3 {
  font-family: var(--font-display);
  letter-spacing: -0.025em;
  line-height: 1.05;
  margin: 0;
}
h1 {
  font-size: clamp(42px, 7.4vw, 84px);
  font-weight: 750;
}
.grad {
  background: linear-gradient(100deg, var(--sun) 10%, var(--planet) 90%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}
.lede {
  max-width: 600px;
  margin: 24px auto 0;
  font-size: clamp(17px, 2vw, 20px);
  color: var(--text-muted);
}
.lede code {
  color: var(--text);
  background: rgb(255 255 255 / 0.06);
  padding: 2px 7px;
  border-radius: 6px;
}
.cta {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 12px;
  margin-top: 36px;
}
.meta {
  margin: 16px 0 0;
  font-size: 13px;
  color: var(--text-faint);
}

/* ---------- window mock ---------- */
.window {
  display: grid;
  grid-template-columns: 220px 1fr;
  max-width: 880px;
  margin: 64px auto 0;
  text-align: left;
  border-radius: 14px;
  overflow: hidden;
  background: #1d1b24;
  border: 1px solid var(--line-strong);
  box-shadow:
    0 0 0 1px rgb(0 0 0 / 0.5),
    0 40px 80px -20px rgb(0 0 0 / 0.7),
    0 0 120px -30px rgb(143 136 255 / 0.25);
  font-size: 13px;
  animation: rise 0.9s cubic-bezier(0.2, 0.8, 0.2, 1) both;
}
@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(24px) scale(0.98);
  }
}
.window__sidebar {
  display: flex;
  flex-direction: column;
  padding: 14px 10px 10px;
  background: rgb(40 37 50 / 0.9);
  border-right: 1px solid rgb(0 0 0 / 0.4);
}
.traffic {
  display: flex;
  gap: 8px;
  padding: 0 6px 18px;
}
.traffic i {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #ff5f57;
}
.traffic i:nth-child(2) {
  background: #febc2e;
}
.traffic i:nth-child(3) {
  background: #28c840;
}
.side__label {
  margin: 0 0 6px;
  padding: 0 8px;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-faint);
}
.side__list {
  list-style: none;
  margin: 0;
  padding: 0;
}
.side__list li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 8px;
  border-radius: 6px;
  color: #d9dfdc;
}
.side__list li.is-active {
  background: #5b54d6;
  color: #fff;
}
.side__list li.is-active .badge {
  background: rgb(255 255 255 / 0.25);
}
.badge {
  display: grid;
  place-items: center;
  width: 20px;
  height: 20px;
  border-radius: 5px;
  background: #5b54d6;
  color: #fff;
  font-size: 11px;
}
.status {
  margin-top: auto;
  padding: 10px;
  border-radius: 8px;
  background: rgb(255 255 255 / 0.05);
  font-size: 11.5px;
  color: var(--text-muted);
}
.status p {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
}
.status p + p {
  margin-top: 6px;
}
.led {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}
.led--aurora {
  background: var(--aurora);
}
.window__main {
  min-height: 340px;
  background: #1c1a22;
}
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 46px;
  padding: 0 18px;
  font-weight: 600;
  border-bottom: 1px solid rgb(0 0 0 / 0.4);
}
.toolbar__icon {
  color: var(--text-faint);
  font-size: 18px;
  font-weight: 400;
}
.form {
  padding: 18px 22px 24px;
}
.group {
  border-radius: 9px;
  background: #27242f;
  border: 1px solid rgb(255 255 255 / 0.05);
}
.group__title {
  padding: 10px 14px;
  font-family: var(--font-display);
  font-weight: 650;
  font-size: 19px;
}
.group__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin: 20px 4px 8px;
  font-weight: 600;
  color: var(--text-muted);
  font-size: 12px;
}
.mini-btn {
  padding: 2px 8px;
  border-radius: 5px;
  background: rgb(255 255 255 / 0.1);
  color: var(--text);
  font-weight: 500;
}
.row {
  padding: 12px 14px;
}
.row + .row {
  border-top: 1px solid rgb(255 255 255 / 0.06);
}
.fields {
  display: flex;
  gap: 10px;
}
.field {
  flex: 1;
  padding: 4px 8px;
  border-radius: 5px;
  background: #17151d;
  border: 1px solid rgb(255 255 255 / 0.1);
  color: #e6e6e6;
}
.field--port {
  flex: 0 0 72px;
}
.route {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 8px 0 0;
  font-size: 12.5px;
}
.link {
  color: var(--planet);
}
.arrow,
.muted {
  color: var(--text-faint);
}

/* ---------- flow ---------- */
.flow {
  display: grid;
  grid-template-columns: 1fr 80px 1fr 80px 1fr;
  align-items: center;
  max-width: var(--max);
  margin: 72px auto 0;
  padding: 0 24px;
}
.node {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 22px 16px;
  text-align: center;
  border: 1px solid var(--line);
  border-radius: var(--radius);
  background: var(--bg-raised);
}
.node code {
  font-size: 14px;
  color: var(--text);
  overflow-wrap: anywhere;
}
.node--orbit {
  border-color: rgb(255 138 91 / 0.3);
  background:
    linear-gradient(var(--bg-raised), var(--bg-raised)) padding-box,
    linear-gradient(135deg, rgb(255 138 91 / 0.5), rgb(143 136 255 / 0.5)) border-box;
  border: 1px solid transparent;
}
.node__kicker {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-muted);
}
.node__note {
  font-size: 13px;
  color: var(--text-faint);
}
.wire {
  position: relative;
  height: 2px;
  background: var(--line-strong);
  overflow: hidden;
}
.wire span {
  position: absolute;
  top: 0;
  left: -30%;
  width: 30%;
  height: 100%;
  animation: travel 2.2s ease-in-out infinite;
}
.wire--sun span {
  background: linear-gradient(90deg, transparent, var(--sun), transparent);
}
.wire--planet span {
  background: linear-gradient(90deg, transparent, var(--planet), transparent);
  animation-delay: 1.1s;
}
@keyframes travel {
  to {
    left: 100%;
  }
}

/* ---------- sections ---------- */
.section {
  max-width: var(--max);
  margin: 0 auto;
  padding: 120px 24px 0;
}
.section__head {
  max-width: 680px;
  margin-bottom: 48px;
}
.kicker {
  margin: 0 0 12px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--sun);
}
h2 {
  font-size: clamp(32px, 4.4vw, 50px);
  font-weight: 700;
}
.sub {
  margin: 18px 0 0;
  font-size: 18px;
  color: var(--text-muted);
}
.sub code {
  color: var(--text);
}

.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}
.card {
  padding: 28px;
  border-radius: var(--radius);
  background: var(--bg-raised);
  border: 1px solid var(--line);
  transition:
    border-color 0.2s,
    transform 0.2s;
}
.card:hover {
  border-color: var(--line-strong);
  transform: translateY(-2px);
}
.card__icon {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  margin-bottom: 20px;
  border-radius: 11px;
  background: linear-gradient(135deg, rgb(255 138 91 / 0.15), rgb(143 136 255 / 0.15));
  border: 1px solid var(--line-strong);
}
.card__icon svg {
  width: 21px;
  height: 21px;
  fill: none;
  stroke: var(--text);
  stroke-width: 1.7;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.card:nth-child(odd) .card__icon svg {
  stroke: var(--sun);
}
.card:nth-child(even) .card__icon svg {
  stroke: var(--planet);
}
.card h3 {
  font-size: 20px;
  font-weight: 650;
  letter-spacing: -0.015em;
}
.card p {
  margin: 10px 0 0;
  font-size: 15px;
  color: var(--text-muted);
}

/* ---------- how ---------- */
.how__grid {
  display: grid;
  grid-template-columns: 1fr 1.1fr;
  gap: 48px;
  align-items: start;
}
.steps {
  list-style: none;
  margin: 0;
  padding: 0;
}
.steps li {
  display: flex;
  gap: 20px;
  padding: 22px 0;
  border-top: 1px solid var(--line);
}
.steps li:first-child {
  border-top: 0;
  padding-top: 0;
}
.steps__n {
  flex: none;
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  font-family: var(--font-display);
  font-weight: 700;
  color: var(--bg);
  background: var(--sun);
}
.steps li:nth-child(2) .steps__n {
  background: linear-gradient(135deg, var(--sun), var(--planet));
}
.steps li:nth-child(3) .steps__n {
  background: var(--planet);
}
.steps h3 {
  font-size: 21px;
  font-weight: 650;
}
.steps p {
  margin: 6px 0 0;
  color: var(--text-muted);
}

.play {
  padding: 28px;
  border-radius: 18px;
  background: var(--bg-sunken);
  border: 1px solid var(--line-strong);
  box-shadow: 0 30px 60px -30px rgb(0 0 0 / 0.8);
}
.play__label {
  margin: 0 0 18px;
  font-size: 13px;
  color: var(--text-faint);
}
.play__fields {
  display: flex;
  gap: 12px;
}
.play__fields label {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}
.play__fields .play__port {
  flex: 0 0 110px;
}
.play__fields span {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
}
.play input {
  width: 100%;
  padding: 11px 13px;
  border-radius: 9px;
  border: 1px solid var(--line-strong);
  background: var(--bg-raised);
  color: var(--text);
  font: 500 15px var(--font-mono);
  outline: none;
  transition:
    border-color 0.15s,
    box-shadow 0.15s;
}
.play input:focus {
  border-color: var(--planet);
  box-shadow: 0 0 0 3px rgb(143 136 255 / 0.2);
}
.play__out {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  margin-top: 22px;
  padding: 16px 18px;
  border-radius: 11px;
  background: rgb(255 255 255 / 0.03);
  border: 1px dashed var(--line-strong);
  font-size: 15px;
}
.play__url {
  color: var(--sun);
  overflow-wrap: anywhere;
}
.play__arrow {
  color: var(--text-faint);
}
.play__target {
  color: var(--planet);
}
.play__note {
  display: flex;
  gap: 8px;
  margin: 14px 0 0;
  font-size: 14px;
}
.play__note::before {
  content: "●";
  font-size: 10px;
  line-height: 22px;
}
.play__note.is-ok {
  color: var(--aurora);
}
.play__note.is-info {
  color: var(--planet);
}
.play__note.is-warn {
  color: #fb923c;
}

/* ---------- faq ---------- */
.faq__list {
  max-width: 780px;
  border-top: 1px solid var(--line);
}
.faq__item {
  border-bottom: 1px solid var(--line);
}
.faq__item button {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  width: 100%;
  padding: 22px 0;
  border: 0;
  background: none;
  color: var(--text);
  font: 600 18px var(--font-body);
  text-align: left;
  cursor: pointer;
}
.faq__chev {
  flex: none;
  font-size: 24px;
  font-weight: 300;
  color: var(--text-muted);
  transition: transform 0.25s;
}
.faq__item.is-open .faq__chev {
  transform: rotate(45deg);
  color: var(--sun);
}
.faq__body {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 0.3s ease;
}
.faq__item.is-open .faq__body {
  grid-template-rows: 1fr;
}
.faq__body p {
  overflow: hidden;
  margin: 0;
  color: var(--text-muted);
}
.faq__item.is-open .faq__body p {
  padding-bottom: 22px;
}

/* ---------- final ---------- */
.final {
  max-width: var(--max);
  margin: 140px auto 0;
  padding: 72px 24px;
  text-align: center;
  background: radial-gradient(500px 260px at 50% 40%, rgb(143 136 255 / 0.1), transparent 70%);
}
.final__icon {
  margin: 0 auto;
  filter: drop-shadow(0 20px 40px rgb(255 138 91 / 0.25));
  animation: float 6s ease-in-out infinite;
}
@keyframes float {
  50% {
    transform: translateY(-8px);
  }
}
.final h2 {
  margin-top: 24px;
}
.final p {
  margin: 14px 0 32px;
  color: var(--text-muted);
  font-size: 18px;
}

.foot {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 8px;
  max-width: var(--max);
  margin: 40px auto 0;
  padding: 28px 24px 40px;
  border-top: 1px solid var(--line);
  font-size: 13px;
  color: var(--text-faint);
}

/* ---------- responsive ---------- */
@media (max-width: 900px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .how__grid {
    grid-template-columns: 1fr;
  }
  .flow {
    grid-template-columns: 1fr;
    max-width: 420px;
  }
  .wire {
    width: 2px;
    height: 36px;
    margin: 0 auto;
  }
  .wire span {
    left: 0;
    top: -30%;
    width: 100%;
    height: 30%;
    animation-name: travel-down;
  }
  .wire--sun span {
    background: linear-gradient(180deg, transparent, var(--sun), transparent);
  }
  .wire--planet span {
    background: linear-gradient(180deg, transparent, var(--planet), transparent);
  }
}
@keyframes travel-down {
  to {
    top: 100%;
  }
}
@media (max-width: 640px) {
  .nav {
    padding: 12px 16px;
  }
  .nav__links {
    display: none;
  }
  .nav .btn--small {
    margin-left: auto;
  }
  .hero {
    padding: 48px 16px 24px;
  }
  .section {
    padding: 88px 16px 0;
  }
  .flow {
    padding: 0 16px;
  }
  .grid {
    grid-template-columns: 1fr;
  }
  .window {
    grid-template-columns: 1fr;
    margin-top: 48px;
  }
  .window__sidebar {
    display: none;
  }
  .form {
    padding: 14px;
  }
  .play {
    padding: 20px;
  }
  .play__fields .play__port {
    flex-basis: 90px;
  }
  .foot {
    padding: 24px 16px 32px;
  }
}
</style>
