/// Directive 02O-1: Play Billing is linked into Android only. On web the import
/// resolves to the stub, so `in_app_purchase` is never part of the web bundle
/// (verified by tool/webtest/verify_prune.py: 0 third-party requests).
library;

export 'iap_service_io.dart' if (dart.library.js_interop) 'iap_service_web.dart';
