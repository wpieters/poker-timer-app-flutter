// Flutter no longer generates an offline cache. Keep the worker at its previous
// URL so existing installations upgrade without leaving two registrations.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../build/web');
function files(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? files(file) : [file];
  });
}
const resources = files(root).map(file => path.relative(root, file).split(path.sep).join('/'))
  .filter(file => file !== 'flutter_service_worker.js' &&
    !file.endsWith('.map') && !file.endsWith('.symbols') &&
    !file.startsWith('canvaskit/skwasm'))
  .sort();
const hash = crypto.createHash('sha256');
for (const file of resources) hash.update(file).update(fs.readFileSync(path.join(root, file)));
const version = hash.digest('hex').slice(0, 16);
fs.writeFileSync(path.join(root, 'flutter_service_worker.js'), `
'use strict';
const PREFIX = 'poker-timer-' + self.registration.scope;
const CACHE = PREFIX + ${JSON.stringify(version)};
const RESOURCES = ${JSON.stringify(resources)};
const urls = new Set(RESOURCES.map(file => new URL(file, self.registration.scope).href));
self.addEventListener('install', event => {
  // Wait for existing clients to close before activating an updated build.
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(
    RESOURCES.map(file => new Request(new URL(file, self.registration.scope), {cache: 'reload'}))
  )));
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (!url.href.startsWith(self.registration.scope)) return;
  const key = event.request.mode === 'navigate'
    ? new URL('index.html', self.registration.scope).href
    : url.origin + url.pathname;
  if (!urls.has(key)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    return await cache.match(key) || fetch(event.request);
  })());
});
`);
console.log(`Offline worker generated: ${resources.length} files, build ${version}.`);
