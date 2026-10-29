// Kill-switch service worker.
//
// Builds use --pwa-strategy=none, but browsers that visited an earlier build
// still have Flutter's caching worker installed and will keep serving that old
// bundle. Deleting the script isn't enough — the update then fails and the old
// worker survives. So we deploy this file *as* flutter_service_worker.js: the
// browser fetches it as an update, installs it, and it immediately clears every
// cache, unregisters itself and reloads any open window on the fresh bundle.
self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      await self.registration.unregister();
      const windows = await self.clients.matchAll({ type: "window" });
      windows.forEach((c) => c.navigate(c.url));
    })()
  );
});

// Never serve from cache while this worker is still controlling a page.
self.addEventListener("fetch", () => {});
