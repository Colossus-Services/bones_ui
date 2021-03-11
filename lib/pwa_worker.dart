// library pwa_worker;
//
// import 'dart:async';
//
// import 'package:service_worker/worker.dart';
//
// void _log(Object o) => print('PWA_WORKER: $o');
//
// Cache _cache;
//
// Future _initCache() async {
//   _log('Init cache...');
//
//   _cache = await caches.open('offline-v1');
//
//   await _cache.addAll([
//     '/main.dart.js',
//   ]);
//
//   _log('Cache initialized.');
// }
//
// void _registerHandlers() {
//   var id = 0;
//
//   _log('SW started.');
//
//   onActivate.listen((ExtendableEvent event) {
//     _log('Activating.');
//   });
//
//   onFetch.listen((FetchEvent event) {
//     _log('Fetch request for $id: ${event.request.url}');
//     var response = _getCachedOrFetch(id, event.request);
//     event.respondWith(response);
//     id++;
//   });
//
//   onMessage.listen((ExtendableMessageEvent event) {
//     _log('Message received: `${event.data}`');
//     event.source.postMessage('reply from SW');
//     _log('Sent reply');
//   });
//
//   onPush.listen((PushEvent event) {
//     _log('onPush received: `${event.data}`');
//     registration.showNotification('Notification: ${event.data}');
//   });
//
//   onInstall.listen((InstallEvent event) {
//     _log('Installing.');
//
//     event.waitUntil(_initCache());
//   });
// }
//
// Future<Response> _getCachedOrFetch(int id, Request request) async {
//   var r = await caches.match(request);
//   if (r != null) {
//     _log('  $id: Found in cache: ${request.url}');
//     return r;
//   } else {
//     _log('  $id: No cached version. Fetching: ${request.url}');
//     await _cache.add(request);
//     r = await fetch(request);
//     _log('  $id: Got for ${request.url}: ${r.statusText}');
//   }
//   return r;
// }
//
// class PWAWorker {
//   static void start() {
//     print('PWAWorker: start');
//     _registerHandlers();
//   }
// }
