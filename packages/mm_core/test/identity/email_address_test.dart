import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  test('accepts and normalises real-world addresses', () {
    for (final input in [
      'ali@example.com',
      ' Ali.Khan@Example.COM ',
      'ali+rent@mail.example.com.pk',
      "o'brien@example.co.uk",
      'a_b-c@sub-domain.example.pk',
    ]) {
      expect(EmailAddress.tryParse(input), isNotNull, reason: input);
    }
    final email = EmailAddress.parse(' Ali.Khan@Example.COM ');
    expect(email.value, 'ali.khan@example.com');
    expect(email.domain, 'example.com');
    expect('$email', 'ali.khan@example.com');
  });

  test('rejects common mistakes', () {
    for (final bad in [
      '',
      'ali',
      'ali@',
      '@example.com',
      'ali@example',
      'ali @example.com',
      'ali@@example.com',
      'ali..khan@example.com',
      '.ali@example.com',
      'ali.@example.com',
      'ali@-example.com',
      'ali@example..com',
      'ali@example.c',
      '${'a' * 65}@example.com',
      'a@${'b' * 250}.com',
    ]) {
      expect(EmailAddress.tryParse(bad), isNull, reason: bad);
    }
    expect(() => EmailAddress.parse('nope'), throwsFormatException);
  });

  test('equality', () {
    expect(EmailAddress.parse('A@B.CO'), EmailAddress.parse('a@b.co'));
    expect(
      EmailAddress.parse('A@B.CO').hashCode,
      EmailAddress.parse('a@b.co').hashCode,
    );
    expect(EmailAddress.parse('a@b.co') == Object(), isFalse);
  });
}
