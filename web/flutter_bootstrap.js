{{flutter_js}}
{{flutter_build_config}}

// Branch administration must load its renderer from the local server without WAN.
_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/'},
});
