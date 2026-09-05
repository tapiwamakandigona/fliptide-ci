// Custom bootstrap: load the renderer from OUR canvaskit/ folder, never from
// gstatic (school Chromebooks, adblockers and CrazyGames incognito checks all
// block third-party CDNs). Template tokens are filled by `flutter build web`.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
