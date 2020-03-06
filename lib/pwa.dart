
import 'package:service_worker/window.dart' as ServiceWorker ;

class PWA {

  static bool activate(String dartFile) {
    if (!ServiceWorker.isSupported) {
      print("PWA not supported!");
      return false;
    }

    String jsFile = "$dartFile.js";

    try {
      ServiceWorker.register(jsFile);

      print("PWA> registered: $jsFile");
    }
    catch (e,s) {
      print("ERROR registering PWA service worker: $jsFile");
      print(e);
      print(s);
    }
  }

}


