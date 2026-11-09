import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';

void main() {
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('is a version 4, RFC 4122 UUID', () {
    for (var i = 0; i < 200; i++) {
      expect(newUuid(), matches(v4));
    }
  });

  test('is random', () {
    final ids = {for (var i = 0; i < 1000; i++) newUuid()};
    expect(ids, hasLength(1000));
  });

  test('takes its bytes from the given source', () {
    expect(newUuid(Random(7)), newUuid(Random(7)));
    expect(newUuid(Random(7)), matches(v4));
  });
}
