<script setup lang="ts">
withDefaults(defineProps<{ size?: number; animated?: boolean }>(), {
  size: 32,
  animated: true,
});

// Gradient ids must be unique per instance; the logo appears several times on a page.
const id = useId();
</script>

<template>
  <svg
    class="logo"
    :class="{ 'is-animated': animated }"
    :width="size"
    :height="size"
    viewBox="0 0 64 64"
    aria-hidden="true"
  >
    <defs>
      <radialGradient :id="`${id}-sun`" cx="0.4" cy="0.38" r="0.7">
        <stop offset="0" stop-color="#ffe6a8" />
        <stop offset="0.45" stop-color="#ffb26b" />
        <stop offset="1" stop-color="#ff6b4a" />
      </radialGradient>
      <radialGradient :id="`${id}-glow`">
        <stop offset="0" stop-color="#ff8a5b" stop-opacity="0.55" />
        <stop offset="1" stop-color="#ff8a5b" stop-opacity="0" />
      </radialGradient>
    </defs>

    <circle cx="32" cy="32" r="30" class="track" />
    <circle cx="32" cy="32" r="20" class="track" />

    <circle cx="32" cy="32" r="15" :fill="`url(#${id}-glow)`" />
    <circle cx="32" cy="32" r="8.5" :fill="`url(#${id}-sun)`" />

    <g class="spin spin--inner">
      <circle cx="52" cy="32" r="3.6" fill="#5ef0c0" />
    </g>
    <g class="spin spin--outer">
      <circle cx="32" cy="2" r="4.6" fill="#8f88ff" />
      <g class="spin spin--moon">
        <circle cx="32" cy="-6" r="1.7" fill="#ffb3c7" />
      </g>
    </g>
  </svg>
</template>

<style scoped>
.logo {
  display: block;
  flex: none;
  overflow: visible;
}
.track {
  fill: none;
  stroke: currentColor;
  stroke-opacity: 0.18;
  stroke-width: 1.4;
}
.spin {
  transform-box: view-box;
  transform-origin: 32px 32px;
}
.spin--inner {
  transform: rotate(-35deg);
}
.spin--outer {
  transform: rotate(40deg);
}
.spin--moon {
  transform-origin: 32px 2px;
}
.is-animated .spin--inner {
  animation: orbit 6s linear infinite;
}
.is-animated .spin--outer {
  animation: orbit 14s linear infinite;
  animation-delay: -4s;
}
.is-animated .spin--moon {
  animation: orbit 3s linear infinite;
}
@keyframes orbit {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
