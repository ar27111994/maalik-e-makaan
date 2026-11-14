// Contract tests: parseAmount and formatAmountWords give exactly what
// contracts/amount_vectors.json says, for every vector. The Deno and website
// ports will run the same file (work item 6 of docs/roadmap/amount-parser.md),
// so the three cannot read an amount differently.
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('../../contracts/amount_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (vectors[key] as List<dynamic>).cast<Map<String, dynamic>>();

  test('the vectors bound amounts as Money does', () {
    expect(vectors['max_paisa'], Money.maxValue.paisa);
  });

  group('parseAmount', () {
    for (final v in cases('parse')) {
      final context = AmountContext.values.byName(v['context'] as String);
      test('${v['name']}: ${jsonEncode(v['input'])} (${context.name})', () {
        final reading = parseAmount(v['input'] as String, context: context);
        switch (v['expected']) {
          case final int paisa:
            expect(reading, AmountFound(Money.fromPaisa(paisa)));
          case 'ambiguous':
            expect(reading, isA<AmountAmbiguous>());
          default:
            expect(reading, isA<AmountNotFound>());
        }
      });
    }
  });

  group('formatAmountWords', () {
    const scripts = {
      'urdu': AmountScript.urdu,
      'roman': AmountScript.roman,
      'english': AmountScript.english,
    };
    for (final v in cases('words')) {
      final money = Money.fromPaisa(v['paisa'] as int);
      final script = scripts[v['script']]!;
      test('${v['paisa']} paisa in ${script.name}', () {
        expect(formatAmountWords(money, script), v['words']);
        expect(
          parseAmount(v['words'] as String, context: AmountContext.field),
          AmountFound(money),
        );
      });
    }
  });
}
