// Contract tests: every stored phone number, CNIC and IBAN in
// contracts/identity_vectors.json is read back by mm_core exactly when the
// database CHECKs accept it (the SQL side is asserted by
// supabase/tests/database/20_identity_contract.test.sql). The app reads these
// columns strictly (PhoneNumber.fromE164, Cnic.parse, Iban.parse), so a value
// only the database accepts would break every screen that lists its row.
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('../../contracts/identity_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (vectors[key] as List<dynamic>).cast<Map<String, dynamic>>();

  String label(Map<String, dynamic> v) =>
      '${jsonEncode(v['value'])} (${v['name']})';

  group('phone', () {
    for (final v in cases('phone')) {
      final value = v['value'] as String;
      final valid = v['valid'] as bool;
      test(label(v), () {
        expect(PhoneNumber.tryParse(value)?.e164 == value, valid);
        if (valid) {
          final phone = PhoneNumber.fromE164(value);
          expect(phone.e164, value);
          // A Raast ID (portfolios.raast_id) is a valid Pakistani mobile.
          expect(phone.isMobile, v['mobile'] as bool);
        } else {
          expect(() => PhoneNumber.fromE164(value), throwsFormatException);
          expect(v['mobile'], isFalse);
        }
      });
    }
  });

  group('cnic', () {
    for (final v in cases('cnic')) {
      final value = v['value'] as String;
      test(label(v), () {
        expect(Cnic.tryParse(value)?.digits == value, v['valid'] as bool);
      });
    }
  });

  group('iban', () {
    for (final v in cases('iban')) {
      final value = v['value'] as String;
      test(label(v), () {
        expect(Iban.tryParse(value)?.value == value, v['valid'] as bool);
      });
    }
  });
}
