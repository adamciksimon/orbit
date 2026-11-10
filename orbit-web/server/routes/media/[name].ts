/**
 * /media/<name>.mp4: the site's videos (public/video), with HTTP range support.
 *
 * Cloudflare's static assets ignore Range headers and always send the whole file with a 200, and Safari (macOS and
 * iOS) won't play a <video> served that way. There's no static file at /media/…, so these requests reach the Worker,
 * which reads the file from the static assets and answers ranges itself with 206 Partial Content.
 */
export default defineEventHandler(async (event) => {
  const name = getRouterParam(event, "name") ?? "";
  if (!/^[\w.-]+\.mp4$/.test(name)) {
    throw createError({ statusCode: 404, statusMessage: "Not Found" });
  }
  const assetPath = `/video/${name}`;

  const assets = (event.context.cloudflare?.env as { ASSETS?: { fetch: typeof fetch } } | undefined)
    ?.ASSETS;
  if (!assets) {
    // `nuxt dev`: Vite serves public/ with range support already.
    return sendRedirect(event, assetPath);
  }

  const file = await assets.fetch(new URL(assetPath, getRequestURL(event)));
  if (!file.ok) {
    throw createError({ statusCode: 404, statusMessage: "Not Found" });
  }
  const body = new Uint8Array(await file.arrayBuffer());
  const size = body.byteLength;

  setResponseHeaders(event, {
    "content-type": "video/mp4",
    "accept-ranges": "bytes",
    "cache-control": "public, max-age=3600",
  });

  // A single range: "bytes=start-end", "bytes=start-" or "bytes=-suffixLength".
  const match = getRequestHeader(event, "range")?.match(/^bytes=(\d*)-(\d*)$/);
  if (!match || (!match[1] && !match[2])) {
    setResponseHeader(event, "content-length", size);
    return body;
  }

  const start = match[1] ? Number(match[1]) : Math.max(size - Number(match[2]), 0);
  const end = match[1] && match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
  if (start >= size || start > end) {
    setResponseStatus(event, 416);
    setResponseHeader(event, "content-range", `bytes */${size}`);
    return "";
  }

  setResponseStatus(event, 206);
  setResponseHeaders(event, {
    "content-range": `bytes ${start}-${end}/${size}`,
    "content-length": end - start + 1,
  });
  return body.subarray(start, end + 1);
});
