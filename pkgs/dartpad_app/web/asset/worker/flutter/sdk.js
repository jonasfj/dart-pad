const scriptUrl = document.currentScript?.src || self.location.href;

// Tell the Flutter engine where to find CanvasKit and assets
self.dartpadFlutterConfiguration = {
  canvasKitBaseUrl: new URL('./canvaskit/', scriptUrl).href,
  assetBase: new URL('./', scriptUrl).href,
};

const flutterJs = new URL('./flutter.js', scriptUrl);
const dartSdkJs = new URL('./dart_sdk.js', scriptUrl);
const flutterWebJs = new URL('./flutter_web.js', scriptUrl);

self.$dartLoader.forceLoadScript(flutterJs, () => null);
self.$dartLoader.forceLoadScript(dartSdkJs, () => null);
self.$dartLoader.forceLoadScript(flutterWebJs, () => null);
