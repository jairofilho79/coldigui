{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
    // WebKit (Safari/iPad) usa dart2js por padrão; habilita skwasm quando WasmGC existe.
    wasmAllowList: { webkit: true },
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
