/// Directive 02k rule 1: the ads plugin is linked into Android only. On web the
/// import resolves to the stub, so `google_mobile_ads` is never part of the
/// web bundle (verified by tool/webtest/verify_prune.py: 0 third-party requests).
library;

export 'ads_service_io.dart' if (dart.library.js_interop) 'ads_service_web.dart';
