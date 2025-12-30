'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ac8125013588908b6a7fc0de83e99165",
"assets/AssetManifest.bin.json": "fd0b1acfba02cd05fe91c94c60c651d8",
"assets/AssetManifest.json": "86971e619dd04c02c385e24163c6a2b8",
"assets/assets/fonts/Jalnan2/Jalnan2.otf": "e43589e6fc81c4e0415fae29aa7a3927",
"assets/assets/images/Animal_Baer.png": "80e3033c1a1e34a0ee8c9f7d34551b43",
"assets/assets/images/Animal_Cat.png": "88d41d49f1d77795520d9a1a17770bac",
"assets/assets/images/Animal_Dog.png": "9718f922e95196b64461212f45698b9e",
"assets/assets/images/Animal_Giraffe.png": "6a71327ac9340c1acbd0ee4605659870",
"assets/assets/images/Animal_Hedgehog.png": "82678eebe81be401d13a8a7eac52d80d",
"assets/assets/images/Animal_Koala.png": "8eaedc5521050b049a783672b98941b6",
"assets/assets/images/Animal_Lion.png": "5f6a3a0c51b4ae1e1d929138f4e6caf9",
"assets/assets/images/Animal_Panda.png": "e1977351bc65ca3493ed565ed6fd0f4e",
"assets/assets/images/Animal_Rabbit.png": "3bf810d65aaa09db58fbb3d73ac00cf9",
"assets/assets/images/Animal_Tiger.png": "9ddddf6d1d79860684b325647c06c7a6",
"assets/assets/images/appicon.png": "b3dc34ef3c26374a4e29b016a06ad9c7",
"assets/assets/images/App_Name.png": "1899bd2b9e9f91626c12b19af2cc6490",
"assets/assets/images/Button_Answer.png": "585e86a959c424c639f8004399c9a758",
"assets/assets/images/Button_CreateQuiz.png": "21e5f0f16ded1733c136549aa33921b7",
"assets/assets/images/Button_Home.png": "bba906386fe6ec3f80b57c1cadf66487",
"assets/assets/images/Button_Next.png": "999eedee077adac16d06fe161f1f48d5",
"assets/assets/images/Button_O.png": "08c9f1fb4d722425e0c6e0c0891d856b",
"assets/assets/images/Button_X.png": "0fed6aee6909e96f2c05b59549131d1d",
"assets/assets/images/Country_Canada.png": "5a85c243bb4546985f293fafd57b88eb",
"assets/assets/images/Country_China.png": "d13ace7e9bd95e1a47f878d8f52ce927",
"assets/assets/images/Country_France.png": "fcd219c9310263bb6aa886edd910421c",
"assets/assets/images/Country_Germany.png": "539708d853db9cd884b714b60ef139c1",
"assets/assets/images/Country_Italy.png": "a9fc61e062e9ed54ac70f57b8f8f297d",
"assets/assets/images/Country_Japan.png": "c3ff5ab0aa471907c503bdc201dc5b1e",
"assets/assets/images/Country_Korea.png": "5c5c5eb84e55665182a03d3b0fc84833",
"assets/assets/images/Country_United%2520Kingdom.png": "f27de95a02522933acbe10c6762a6ecb",
"assets/assets/images/Country_UnitedStates.png": "51e2234029185427793f37f3c1485079",
"assets/assets/images/Country_Vietnam.png": "8325ca380177abf2fe85156fb8073c9f",
"assets/assets/images/Fruit_Apple.png": "048a28484e52f8de65c554ac6114df9d",
"assets/assets/images/Fruit_Banana.png": "cf58a3a24c9604baaec890f766136f1d",
"assets/assets/images/Fruit_Cherry.png": "c7ee114bccf61e5223b99826259d0a86",
"assets/assets/images/Fruit_Grape.png": "6ddb38fd3ffb27fc569e0995e1e05168",
"assets/assets/images/Fruit_Kiwi.png": "f3b28f980492f94466d85e81a9b745b7",
"assets/assets/images/Fruit_Lemon.png": "7000582d349315d59c6c170d6f050990",
"assets/assets/images/Fruit_Pineapple.png": "98765e5e61d2e9d2a63400cf3b5c14b2",
"assets/assets/images/Fruit_Pomegranate.png": "7f414d78525ba18f5937c831b38b053e",
"assets/assets/images/Fruit_Strawberry.png": "b0ce660e10f946321d3d9b17d9e8955b",
"assets/assets/images/Fruit_Watermelon.png": "607184e8c10238133d3be13b33a9517a",
"assets/assets/images/Widget_Countdown.png": "4bb2f74aca1756e386b9a36775725589",
"assets/assets/images/Widget_Progress.png": "e5c6647795773ed3867b15688ccd103b",
"assets/assets/sounds/answer.wav": "590f793358d1556efab37f1209d30f05",
"assets/assets/sounds/beep.flac": "145aee6aa52425ef36cc6657dd8dbfbf",
"assets/assets/sounds/click.wav": "c2ad36633e9a8bba777767d070803ef8",
"assets/assets/sounds/hover.wav": "2f14bed60d59b53a702a0d460b17c4a7",
"assets/assets/videos/soundwave.mp4": "0f398054b2be5c64d2a05af613d77083",
"assets/FontManifest.json": "61a4df417dc9f7231a32d4886bea8d95",
"assets/fonts/MaterialIcons-Regular.otf": "d7386c3168706e24d4f0b65b4b6d1850",
"assets/NOTICES": "d6f2e7c7de6d81e4f3cf33c06ecae605",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "b3dc34ef3c26374a4e29b016a06ad9c7",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "1f9786b771df2b632be91b0b6c859f7a",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "37f66f1faa24876146ecb066db82eee4",
"/": "37f66f1faa24876146ecb066db82eee4",
"main.dart.js": "9d98223e326fd6fbc99015fde12f9aac",
"manifest.json": "2c20f13b245992f799d22727b42ba171",
"version.json": "ed6224453623bebf18b3d66a21f60759"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
