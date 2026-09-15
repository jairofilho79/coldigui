'use strict';
// Service worker do shell do PLPCG (spec 2026-09-14-pwa-shell-offline).
//
// Cobre só o shell same-origin: index.html, flutter_bootstrap, main.dart.*,
// engine (canvaskit/<hash>/), isar, fontes, ícones, manifest. Catálogo e
// materiais continuam a cargo do Dart (Isar + Cache API própria, gerida só
// pelo Dart): requests para outras origens nunca passam por respondWith e o
// cache dos PDFs nunca é tocado aqui.
//
// Três classes de ficheiro:
//  - CRITICAL: precache no install, all-or-nothing (~3 MB).
//  - ENGINE (main.dart.wasm|mjs|js e canvaskit/<hash>/**): NÃO está em lista
//    nenhuma. O flutter_bootstrap.js escolhe a variante por browser (skwasm no
//    Chrome, skwasm_heavy no Safari/Firefox, canvaskit/chromium + main.dart.js
//    sem WasmGC) e só a usada interessa: a página manda-nos a lista `used`
//    do que carregou e nós copiamo-la para o cache — vem do cache HTTP,
//    custa ~0 rede. Precachear todas as variantes eram ~33 MB por deploy.
//  - WARM: o resto carregável, em background e só sem Save-Data/2g.
//
// Os três placeholders são substituídos por scripts/generate_sw_manifest.py
// no pós-build (cache_bust_web_entrypoints.sh). Em `flutter run` ficam
// intactos e o index.html não regista este ficheiro.
const TAG = '__PLPCG_TAG__';
const CRITICAL = __PLPCG_CRITICAL__;
const WARM = __PLPCG_WARM__;
const CACHE = `plpcg-shell-${TAG}`;
// Caches do flutter_service_worker.js de versões antigas do Flutter: já não
// há quem os limpe (o stub 3.47 só se desregista).
const LEGACY_CACHES = ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'];
const SCOPE_PATH = new URL(self.registration.scope).pathname;
// Mudam de conteúdo sem mudar de nome: rede primeiro, cache só sem rede (S10).
const NETWORK_FIRST = new Set([SCOPE_PATH + 'version.json', SCOPE_PATH + 'manifest.json']);
// Nunca entram no cache mesmo que a página os tenha carregado: o próprio SW
// (congelaria a versão) e o stub do Flutter.
const NEVER_CACHED = new Set([SCOPE_PATH + 'sw.js', SCOPE_PATH + 'flutter_service_worker.js']);
const USED_PARALLEL = 4;

// Falhar um item de CRITICAL falha o install inteiro e o SW anterior continua
// a servir — é o comportamento desejado (S3).
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(CRITICAL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((key) => (key.startsWith('plpcg-shell-') && key !== CACHE) || LEGACY_CACHES.includes(key))
          .map((key) => caches.delete(key)),
      ))
      .then(() => self.clients.claim()),
  );
});

// index.html envia {type:'warm', used:[...], full:bool} depois do
// flutter-first-frame. `used` = URLs same-origin que a página carregou
// (performance resource timing) — inclui o engine escolhido; vem sempre.
// `full` = false com Save-Data / 2g: aquece só `used`, não WARM. Chega mesmo
// com o SW ainda em install: corre em paralelo.
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'warm') return;
  // Página com tag antiga (deploy a meio de sessão): a lista `used` refere-se
  // aos ficheiros da tag dela, não aos desta cache — descarta-a para não
  // meter ficheiros da tag A na cache B. O WARM continua válido: é sempre
  // desta própria tag, nunca vem da mensagem.
  const staleTag = event.data.tag && event.data.tag !== TAG;
  const used = !staleTag && Array.isArray(event.data.used) ? event.data.used : [];
  const full = event.data.full === true;
  event.waitUntil(warm(used, full));
});

async function warm(used, full) {
  const cache = await caches.open(CACHE);
  await warmUsed(cache, used);
  if (!full) return;
  // Sequencial: a warm corre enquanto o app está em uso; não disputa banda.
  for (const url of WARM) {
    if (await cache.match(url)) continue;
    try {
      const response = await fetch(url);
      if (response.ok) await cache.put(url, response);
    } catch (e) {
      // Uma falha individual nunca impede as restantes nem o boot (S3).
    }
  }
}

// Só same-origin e nunca o SW/stub; até USED_PARALLEL em paralelo porque as
// respostas vêm do cache HTTP. `force-cache`: o conteúdo de um URL com ?v=
// ou hash nunca muda dentro da tag, logo não vale a pena revalidar os
// entrypoints no-cache (main.dart.wasm?v=…) — poupa um round-trip por ficheiro.
async function warmUsed(cache, used) {
  const queue = [];
  for (const entry of used) {
    let url;
    try {
      url = new URL(entry);
    } catch (e) {
      continue;
    }
    if (url.origin !== self.location.origin || NEVER_CACHED.has(url.pathname)) continue;
    queue.push(url.href);
  }
  const worker = async () => {
    while (queue.length) {
      const href = queue.shift();
      if (await cache.match(href)) continue;
      try {
        const response = await fetch(href, { cache: 'force-cache' });
        if (response.ok && response.status === 200 && response.type === 'basic') {
          await cache.put(href, response);
        }
      } catch (e) {
        // Falha individual (ex.: 404 de um preload errado) nunca trava o resto.
      }
    }
  };
  await Promise.all(Array.from({ length: USED_PARALLEL }, worker));
}

// Cache-first só para o shell: assets/, canvaskit/<hash>/, icons/, e
// ficheiros na raiz do scope que ou levam ?v= (entrypoints com cache-bust:
// main.dart.*, flutter_bootstrap.js, MaterialIcons-Regular.<hash>.otf) ou
// estão listados em CRITICAL/WARM (flutter.js, isar_plus.*, favicon.png…).
// Sem isto o `cacheFirst` era catch-all para qualquer GET same-origin —
// incluiria um futuro /api/* que nada tem a ver com o shell.
const SHELL_FILES = new Set(
  [...CRITICAL, ...WARM].map((u) => new URL(u, self.registration.scope).pathname),
);

function isRootLevel(pathname) {
  const rest = pathname.slice(SCOPE_PATH.length);
  return rest !== '' && !rest.includes('/');
}

function isShellRequest(url) {
  const pathname = url.pathname;
  if (pathname.startsWith(SCOPE_PATH + 'assets/')) return true;
  if (pathname.startsWith(SCOPE_PATH + 'canvaskit/')) return true;
  if (pathname.startsWith(SCOPE_PATH + 'icons/')) return true;
  return isRootLevel(pathname) && (url.searchParams.has('v') || SHELL_FILES.has(pathname));
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  // Range (áudio/PDF por partes) tem de ir à rede: uma resposta 200 inteira
  // vinda do cache confunde os consumidores de media.
  if (request.method !== 'GET' || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate' || url.pathname === SCOPE_PATH || url.pathname === SCOPE_PATH + 'index.html') {
    event.respondWith(networkFirst(request, './'));
  } else if (NETWORK_FIRST.has(url.pathname)) {
    event.respondWith(networkFirst(request, request));
  } else if (isShellRequest(url)) {
    event.respondWith(cacheFirst(request));
  }
  // Resto same-origin (ex.: futuro /api/*): sem respondWith — vai à rede
  // normal, nunca pelo cache do shell.
});

// Rede primeiro sem atualizar o cache: o index.html em cache é sempre o da
// própria tag (consistente com os chunks precacheados). Um deploy novo chega
// por um sw.js?v=<tag nova>, nunca por este cache.
async function networkFirst(request, fallbackKey) {
  try {
    return await fetch(request);
  } catch (e) {
    const cached = await caches.match(fallbackKey, { cacheName: CACHE, ignoreSearch: true });
    if (cached) return cached;
    // Sem rede e sem index.html em cache: o browser mostra o erro nativo.
    throw e;
  }
}

// Ficheiros com hash / ?v= / canvaskit/<hash>/ / assets: o conteúdo de um URL
// nunca muda dentro da mesma tag. Preenche no primeiro fetch controlado
// (chunks deferidos, engine numa visita em que a lista `used` não chegou).
async function cacheFirst(request) {
  const cached = await caches.match(request, { cacheName: CACHE });
  if (cached) return cached;
  const response = await fetch(request);
  // Só respostas completas e same-origin entram — nunca opaque, erro ou 206.
  if (response.ok && response.status === 200 && response.type === 'basic') {
    const cache = await caches.open(CACHE);
    await cache.put(request, response.clone());
  }
  return response;
}
