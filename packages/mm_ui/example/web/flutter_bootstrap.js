{{flutter_js}}
{{flutter_build_config}}

// The gallery loads CanvasKit from its own build instead of the CDN, so it
// runs offline and behind firewalls during user acceptance testing.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});
