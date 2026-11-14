import 'dart:js_interop';

/// The browser's IANA zone name (`Europe/London`), or null when it gives
/// none.
String? deviceZoneName() => _DateTimeFormat().resolvedOptions().timeZone;

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory();

  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}
