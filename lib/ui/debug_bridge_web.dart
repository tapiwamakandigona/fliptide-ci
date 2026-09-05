import 'dart:js_interop';

@JS('__fliptideState')
external set _state(JSString s);

/// Web: expose run state to test harnesses as `window.__fliptideState`.
void publishState(String s) => _state = s.toJS;

@JS('__fliptideRestartMs')
external set _restart(JSArray<JSNumber> a);

void publishRestartMs(List<int> ms) => _restart = ms.map((e) => e.toJS).toList().toJS;
