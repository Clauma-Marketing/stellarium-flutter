export 'stellarium_engine_stub.dart'
    if (dart.library.js_interop) 'stellarium_engine_web.dart'
    if (dart.library.io) 'stellarium_engine_mobile.dart';
