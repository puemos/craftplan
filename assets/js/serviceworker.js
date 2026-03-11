// Make imported functions be considered macros
// They're executed at bundle time and only their results are emited in the resulting bundle.
// Not sure how data is handled, but it likely is inlined as is.
// Supports async functions, where results are awaited on.
// https://bun.sh/docs/bundler/macros
import { cacheMacro } from "./serviceworker/cache_manifest.js" with { type: "macro" };

const cache = cacheMacro();
const staticCacheName = "static-" + cache.hash;
const cacheList = [staticCacheName];

async function updateStaticCache() {
  let staticCache = await caches.open(staticCacheName);
  staticCache.addAll(cache.cache);
}

async function clearOldCaches() {
  let keys = await caches.keys();
  return Promise.all(
    keys
      .filter((key) => !cacheList.includes(key))
      .map((key) => caches.delete(key)),
  );
}

addEventListener("install", (installEvent) => {
  installEvent.waitUntil(updateStaticCache());
  skipWaiting();
});

addEventListener("activate", (activateEvent) => {
  activateEvent.waitUntil(clearOldCaches());
  clients.claim();
});

addEventListener("fetch", (fetchEvent) => {
  let request = fetchEvent.request;
  let url = new URL(request.url);

  // Only deal with requests to my own server
  if (url.origin !== location.origin) {
    return;
  }

  // Only deal with GET requests
  if (request.method !== "GET") {
    return;
  }

  // For HTML requests, try the preload first, then network, fall back to the cache, finally the offline page
  if (
    request.mode === "navigate" ||
    request.headers.get("Accept").includes("text/html")
  ) {
    return;
  }

  // For non-HTML requests, look in the cache first, fall back to the network
  fetchEvent.respondWith(
    caches.match(request).then((responseFromCache) => {
      return responseFromCache || fetch(request);
    }),
  );
});