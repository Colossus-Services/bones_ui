// import 'package:service_worker/window.dart' as service_worker;
//
// class PWA {
//   static bool activate(String dartFile) {
//     if (!service_worker.isSupported) {
//       print('PWA not supported!');
//       return false;
//     }
//
//     var jsFile = '$dartFile.js';
//
//     try {
//       service_worker.register(jsFile);
//       print('PWA> registered: $jsFile');
//       return true;
//     } catch (e, s) {
//       print('ERROR registering PWA service worker: $jsFile');
//       print(e);
//       print(s);
//       return false;
//     }
//   }
// }
