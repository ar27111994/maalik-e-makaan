// Contract tests: the app's sanitiser against contracts/clean_text.json, the
// text-safety contract the database CHECKs (app.is_clean_text), the Edge
// Functions and the repository guard share. Whatever the sanitiser outputs
// must pass the database, so it may be stricter than the contract, never
// looser.
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

typedef Range = ({int from, int to, String label});

int codePoint(Object? text) {
  final value = text! as String;
  if (!value.startsWith('U+')) throw FormatException('not a code point', value);
  return int.parse(value.substring(2), radix: 16);
}

List<Range> ranges(Object? entries) => [
  for (final entry in (entries! as List<dynamic>).cast<Map<String, dynamic>>())
    (
      from: codePoint(entry['from']),
      to: codePoint(entry['to']),
      label: entry['label'] as String,
    ),
];

void main() {
  final contract = jsonDecode(
    File('../../contracts/clean_text.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final forbidden = ranges(contract['forbidden']);
  final clientExtras = contract['client_also_removes'] as Map<String, dynamic>;
  final toSpace = ranges(clientExtras['to_space']);
  bool inRanges(List<Range> list, int cp) =>
      list.any((range) => cp >= range.from && cp <= range.to);
  bool forbiddenIn(String text) =>
      text.runes.any((rune) => inRanges(forbidden, rune));

  group('every forbidden code point', () {
    for (final range in forbidden) {
      test(range.label, () {
        for (var cp = range.from; cp <= range.to; cp++) {
          final input = 'Ali${String.fromCharCode(cp)}Raza';
          expect(
            forbiddenIn(sanitizeSingleLine(input)),
            isFalse,
            reason: 'single line keeps U+${cp.toRadixString(16)}',
          );
          expect(
            forbiddenIn(sanitizeMultiline(input)),
            isFalse,
            reason: 'multiline keeps U+${cp.toRadixString(16)}',
          );
          // Whitespace-like controls are replaced by a space rather than
          // flagged; everything else is reported as unsafe.
          expect(
            containsUnsafeCharacters(String.fromCharCode(cp)),
            !inRanges(toSpace, cp),
            reason: 'U+${cp.toRadixString(16)}',
          );
        }
      });
    }
  });

  test('allowed samples are never reported as unsafe', () {
    for (final sample
        in (contract['allowed_samples'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      final cp = codePoint(sample['code_point']);
      expect(
        containsUnsafeCharacters(String.fromCharCode(cp)),
        isFalse,
        reason: '${sample['code_point']} ${sample['label']}',
      );
    }
  });

  test('Urdu with joiners and marks survives sanitising', () {
    final urdu = String.fromCharCodes([
      0x0645, 0x0627, 0x0644, 0x06A9, 0x0650, //
      0x200C, 0x0645, 0x06A9, 0x0627, 0x0646, 0x200F,
    ]);
    expect(sanitizeSingleLine(urdu), urdu);
  });
}
