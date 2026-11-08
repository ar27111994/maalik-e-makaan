// The app's readers against the shared identity vectors
// (contracts/identity_vectors.json): the database's CHECKs accept a stored
// phone number, CNIC or IBAN exactly when mm_core reads it back, so every
// stored value reads in the app's strict record readers, and the lenient
// summary reader (JsonRow.dialablePhone) keeps exactly the valid numbers.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';

import '../../support/fakes.dart';

void main() {
  final vectors = jsonDecode(
    File('../contracts/identity_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<({String value, String name, bool valid})> cases(String key) => [
    for (final v in (vectors[key] as List).cast<Map<String, dynamic>>())
      (
        value: v['value'] as String,
        name: v['name'] as String,
        valid: v['valid'] as bool,
      ),
  ];

  group('phone', () {
    for (final v in cases('phone')) {
      test('${v.value} (${v.name})', () {
        // A summary keeps a valid number and drops one it cannot dial.
        expect(
          JsonRow({'phone': v.value}).dialablePhone('phone')?.e164,
          v.valid ? v.value : isNull,
        );
        // A tenant's record reads every number the database stores.
        final row = {...aliRaza.toRow(), 'phone': v.value};
        if (v.valid) {
          expect(Tenant.fromRow(row).phone!.e164, v.value);
        } else {
          expect(() => Tenant.fromRow(row), throwsFormatException);
        }
      });
    }
  });

  group('cnic', () {
    for (final v in cases('cnic')) {
      test('${v.value} (${v.name})', () {
        final row = {...aliRaza.toRow(), 'cnic': v.value};
        if (v.valid) {
          expect(Tenant.fromRow(row).cnic!.digits, v.value);
        } else {
          // Never read back as stored: refused, or tidied into another
          // value (the database refuses both).
          expect(
            _readBack(() => Tenant.fromRow(row).cnic!.digits),
            isNot(v.value),
          );
        }
      });
    }
  });

  group('iban', () {
    for (final v in cases('iban')) {
      test('${v.value} (${v.name})', () {
        final row = {...gulbergDetails.toRow(), 'bank_iban': v.value};
        if (v.valid) {
          expect(PortfolioDetails.fromRow(row).bankIban!.value, v.value);
        } else {
          expect(
            _readBack(() => PortfolioDetails.fromRow(row).bankIban!.value),
            isNot(v.value),
          );
        }
      });
    }
  });

  test('a missing phone is no phone', () {
    expect(const JsonRow({'phone': null}).dialablePhone('phone'), isNull);
  });
}

/// What [read] reads, or null when it refuses the value.
String? _readBack(String Function() read) {
  try {
    return read();
  } on FormatException {
    return null;
  }
}
