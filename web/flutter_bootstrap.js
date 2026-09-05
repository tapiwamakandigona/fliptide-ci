// Custom bootstrap: load the renderer from OUR canvaskit/ folder, never from
// gstatic (school Chromebooks, adblockers and CrazyGames incognito checks all
// block third-party CDNs). Template tokens are filled by `flutter build web`.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    // Pin the single full CanvasKit build for every non-WasmGC browser (Safari,
    // Firefox, Chrome < 119) so the Chromium-only variant can be pruned from the
    // package (scripts/prune_web.sh). Chromium >= 119 still gets skwasm.
    canvasKitVariant: "full",
  },
});
