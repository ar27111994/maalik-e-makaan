import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/transport_error_stub.dart';

void main() {
  test('without dart:io nothing is a dart:io transport failure', () {
    expect(isTransportError(StateError('x')), isFalse);
    expect(isTransportError(Exception('handshake')), isFalse);
  });
}
