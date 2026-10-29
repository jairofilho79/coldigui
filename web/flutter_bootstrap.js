{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
    // WebKit (Safari/iPad) usa dart2js por padrão; habilita skwasm quando WasmGC existe.
    wasmAllowList: { webkit: true },
  },
  // Sem definir o service worker no loader: o stub flutter_service_worker.js
  // do Flutter 3.47 desregista-se sempre que corre — se corresse aqui,
  // apagava o registo do nosso web/sw.js a cada boot (o client.navigate dele
  // só afeta clients já controlados por ele, não é esse o problema). O shell
  // offline é só do web/sw.js.
});
