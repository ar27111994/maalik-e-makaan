import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';

void main() {
  final row = JsonRow.of({
    'name': 'Gulberg',
    'note': null,
    'count': 2,
    'active': true,
    'owner': {'id': 'u1'},
    'items': [1, 2],
  });

  test('reads typed fields', () {
    expect(row.string('name'), 'Gulberg');
    expect(row.optionalString('note'), isNull);
    expect(row.optionalString('name'), 'Gulberg');
    expect(row.integer('count'), 2);
    expect(row.boolean('active'), isTrue);
    expect(row.object('owner').string('id'), 'u1');
    expect(row.list('items'), [1, 2]);
  });

  test('accepts maps with other key types from JSON decoders', () {
    expect(JsonRow.of(<dynamic, dynamic>{'a': 'b'}).string('a'), 'b');
  });

  test('a missing or mistyped field names itself', () {
    expect(
      () => row.string('missing'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'missing is missing',
        ),
      ),
    );
    expect(() => row.string('count'), throwsFormatException);
    expect(() => row.optionalString('count'), throwsFormatException);
    expect(() => row.integer('name'), throwsFormatException);
    expect(() => row.boolean('count'), throwsFormatException);
    expect(() => row.object('name'), throwsFormatException);
    expect(() => row.list('owner'), throwsFormatException);
    expect(() => JsonRow.of('x', 'portfolio'), throwsFormatException);
  });
}
