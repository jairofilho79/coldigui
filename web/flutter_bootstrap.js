{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
    // WebKit (Safari/iPad) usa dart2js por padrão; habilita skwasm quando WasmGC existe.
    wasmAllowList: { webkit: true },
  },
  // Sem definir o service worker no loader: o flutter_service_worker.js do
  // Flutter 3.47 é um stub que se desregista e faz client.navigate (reload) —
  // no mesmo scope que o sw.js próprio (registado em index.html após o
  // primeiro frame) seria um loop. O shell offline é do web/sw.js.
});
