<script setup lang="ts">
import type { NuxtError } from "#app";
// Nuxt's own error designs, imported directly. Nuxt's built-in error page loads them lazily, and on Cloudflare
// Workers that lazy load renders nothing on the server: a 404 arrived as an empty page and only appeared once the
// JavaScript ran, with a hydration mismatch. These are the same components, so the pages look exactly the same.
import Error404 from "#app/components/error-404.vue";
import Error500 from "#app/components/error-500.vue";

const props = defineProps<{ error: NuxtError }>();

const status = Number(props.error.statusCode || 500);
const statusText =
  props.error.statusMessage ?? (status === 404 ? "Page Not Found" : "Internal Server Error");
const description = props.error.message || String(props.error);
</script>

<template>
  <Error404 v-if="status === 404" :status :status-text :description />
  <Error500 v-else :status :status-text :description />
</template>
