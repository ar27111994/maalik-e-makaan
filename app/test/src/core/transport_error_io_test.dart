@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/transport_error_io.dart';

void main() {
  test('dart:io transport failures are connection problems', () {
    for (final error in <Object>[
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      const CertificateException('expired'),
      const TlsException('closed'),
      const SocketException('Failed host lookup'),
      const HttpException('Connection closed before full header'),
    ]) {
      expect(isTransportError(error), isTrue, reason: '$error');
      expect(AppFailure.from(error), isA<NetworkFailure>(), reason: '$error');
    }
  });

  test('other I/O errors are not', () {
    const error = FileSystemException('cannot read', '/tmp/x');
    expect(isTransportError(error), isFalse);
    expect(AppFailure.from(error), isA<UnexpectedFailure>());
  });
}
