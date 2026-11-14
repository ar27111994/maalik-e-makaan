import 'package:meta/meta.dart';
import 'package:mm_core/src/money/amount_lexicon.g.dart';
import 'package:mm_core/src/money/money.dart';
import 'package:mm_core/src/text/digits.dart';

/// Where the text [parseAmount] reads comes from.
enum AmountContext {
  /// A single amount field: the person typed an amount and nothing else.
  /// Words with a second everyday meaning (`do`, `m`, `and`, a spaced `k`,
  /// `mn` or `bn`) are read as numbers and units here; `cr` is too, except
  /// after a rupee marker or two decimal places, as a pasted bank line has it
  /// for "credit".
  field,

  /// Free text: a message, a note or a voice-note transcript, or a span of
  /// one. A word with a second everyday meaning makes the amount ambiguous,
  /// except where its other meaning cannot be meant (`do` after `sawa`, or
  /// after `Rs` with a multiplier to follow). A bare `m`, and a spaced `k`,
  /// `mn` or `bn`, are never read here (the owner's question 1 in
  /// `docs/roadmap/amount-parser.md`, as recommended). Because the text may
  /// be a span cut out of a longer message, the start of it is not taken as
  /// the start of a sentence: `do hazar rupay` is ambiguous, since `bhej`
  /// may have come before it.
  text,
}

/// Why [parseAmount] found more than one possible amount, or a word it will
/// not guess at. The person is asked to confirm or retype the amount.
enum AmountAmbiguity {
  /// A word the lexicon always refuses: a fraction it does not read (`aadha`,
  /// `half`), a vague plural (`lakhon`), `aur` or `or`, a misspelt fraction
  /// (`sare`, `der`), a decimal point said in words (`point`).
  refusedWord,

  /// In free text, a word with a second everyday meaning (`do` for "give",
  /// `m` for minutes, `cr` for credit, a spaced `k` for "ke", a spaced `mn`
  /// for "main"); in a field, `cr` after a rupee marker or two decimal
  /// places (`Rs 25,000.00 Cr`, a bank's "credit").
  freeTextWord,

  /// Another currency (`$`, `AED`, `ڈالر`): never read as rupees.
  foreignCurrency,

  /// A word or a sign the lexicon does not know, beside an amount.
  unknownWord,

  /// Digit grouping that is neither Western (`1,500,000`) nor South Asian
  /// (`15,00,000`), or more than two decimal places with no multiplier
  /// (`1.500` may mean fifteen hundred).
  grouping,

  /// In free text, a number with a leading zero (`0300`): a phone number,
  /// an ID or a date rather than an amount.
  leadingZero,

  /// A rupee marker, a paisa word or `only` inside the amount
  /// (`2 lakh rupay 50 hazar`), or paise with no rupees before them.
  misplacedMarker,

  /// A fraction (`sawa`, `derh`) or a decimal quantity (`1.5`) that is not
  /// the whole amount (`sawa do lakh pachas hazar`), a prefix before a number
  /// it does not take (`sarhe do`), or a fraction with no multiplier after it.
  misplacedFraction,

  /// Two numbers with no multiplier between them (`do pachas`, `2 50`).
  adjacentNumbers,

  /// In free text, multipliers with no number and no rupee marker (`lakh`),
  /// which is often a figure of speech.
  bareMultiplier,

  /// Groups that do not descend (`pachas hazar do lakh`), a multiplier twice
  /// at the same level, a zero inside an amount, or `and` out of place.
  order,

  /// A lakh, million, crore, arab or kharab followed only by a number that
  /// would fit the next unit down: `ek lakh bees` may be 100,020 or, with
  /// hazar left out as people often say it, 120,000; `1 crore 20` may be
  /// 1.2 crore. A rupee word straight after the number pins it as rupees
  /// (`ek lakh bees rupay` is 100,020), as `formatAmountWords` writes it.
  elidedMultiplier,
}

/// Why [parseAmount] found no amount at all.
enum AmountAbsence {
  /// The text is empty or only spaces.
  empty,

  /// The text has no number, fraction or multiplier.
  noAmount,

  /// The amount is negative; amounts read from text never are.
  negative,

  /// The amount is above the largest the database stores
  /// (`numeric(14,2)`: Rs 999,999,999,999.99), or it has a number whose
  /// whole part is longer than 14 digits, which is above it wherever it
  /// stands.
  outOfRange,

  /// The amount is not a whole number of paisa (`1.23456789 lakh`), or it
  /// has a number with more decimal places than any multipliers after it
  /// could make whole paisa (more than 45).
  belowPaisa,
}

/// What [parseAmount] read: an amount, an ambiguity, or nothing.
@immutable
sealed class AmountReading {
  const new();
}

/// One amount, the only reading of the text.
final class AmountFound extends AmountReading {
  /// Wraps the amount read.
  const new(this.money);

  /// The amount: never negative, never above `Money.maxValue`.
  final Money money;

  @override
  bool operator ==(Object other) =>
      other is AmountFound && other.money == money;

  @override
  int get hashCode => money.hashCode;

  @override
  String toString() => 'AmountFound(${money.paisa} paisa)';
}

/// An amount is there, but it could be read in more than one way, or it
/// carries a word the parser will not guess at.
final class AmountAmbiguous extends AmountReading {
  /// Wraps the reason.
  const new(this.reason);

  /// Why the text was not read.
  final AmountAmbiguity reason;

  @override
  bool operator ==(Object other) =>
      other is AmountAmbiguous && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'AmountAmbiguous(${reason.name})';
}

/// No amount in the text.
final class AmountNotFound extends AmountReading {
  /// Wraps the reason.
  const new(this.reason);

  /// Why nothing was read.
  final AmountAbsence reason;

  @override
  bool operator ==(Object other) =>
      other is AmountNotFound && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'AmountNotFound(${reason.name})';
}

/// Reads an amount written or said the way Pakistanis write it: digits in
/// any script with any Western or South Asian grouping, Urdu words, Roman
/// Urdu and English words, lakh and crore, the fractions sawa, sarhe, paune,
/// derh and dhai, and rupee markers.
///
/// ```dart
/// parseAmount('ek lakh pachas hazar');   // AmountFound(Rs 150,000)
/// parseAmount('ڈیڑھ لاکھ');              // AmountFound(Rs 150,000)
/// parseAmount('Rs. 25,000/-');           // AmountFound(Rs 25,000)
/// parseAmount('pachas hazar do lakh');   // AmountAmbiguous(order)
/// ```
///
/// The whole of [input] must be one amount, with rupee markers, `only` and
/// a paise part (`pachas rupay bees paise`) around it. An amount is a sum of
/// groups, each a quantity times a multiplier (sau, hazar, lakh, million,
/// crore, arab), in strictly descending order; a quantity may itself be a
/// compound (`ek sau pachas crore`). Everything is exact integer arithmetic:
/// no floating-point type is used.
///
/// The parser refuses rather than guesses: a text with two possible
/// readings, or a word it does not know beside an amount, is
/// [AmountAmbiguous], never a number. The words are those of
/// `contracts/amount_lexicon.json` ([amountLexiconReviewed] says whether a
/// native speaker has reviewed them yet), and
/// `contracts/amount_vectors.json` is the contract every port runs.
///
/// `parseMoneyInput` keeps its own, more lenient rules for form fields.
AmountReading parseAmount(
  String input, {
  AmountContext context = AmountContext.text,
}) {
  final tokens = _tokenize(_normalise(input));
  if (tokens.isEmpty) return const AmountNotFound(AmountAbsence.empty);
  if (!tokens.any((t) => t.isQuantity) &&
      !(tokens.any((t) => t.kind == _Kind.refused) &&
          tokens.any((t) => t.kind == _Kind.currency))) {
    return const AmountNotFound(AmountAbsence.noAmount);
  }
  final sign = tokens.indexWhere((t) => !t.isMarker);
  // A hyphen joined to the rupee marker before it ('Rs-500') is a separator
  // or a minus: it is left to _refusal, which finds the amount ambiguous.
  if (sign >= 0 &&
      tokens[sign].kind == _Kind.minus &&
      sign + 1 < tokens.length &&
      tokens[sign + 1].isQuantity &&
      !(sign > 0 &&
          tokens[sign].joined &&
          tokens[sign - 1].kind == _Kind.currency)) {
    return const AmountNotFound(AmountAbsence.negative);
  }
  final refusal = _refusal(tokens, context);
  if (refusal != null) return AmountAmbiguous(refusal);
  // A number beyond the bound the reader holds exactly (see _digitValue) is
  // above the maximum, or below a paisa, in every reading of the text; it
  // has no value to read, so the grammar never sees one.
  for (final token in tokens) {
    if (token.excess case final excess?) return AmountNotFound(excess);
  }
  return _read(_mergeEnglishTens(tokens), context);
}

AmountAmbiguity? _refusal(List<_Token> tokens, AmountContext context) {
  if (tokens.any((t) => t.kind == _Kind.refused)) {
    return AmountAmbiguity.refusedWord;
  }
  if (tokens.any((t) => t.kind == _Kind.foreign)) {
    return AmountAmbiguity.foreignCurrency;
  }
  if (tokens.any((t) => t.kind == _Kind.unknown || t.kind == _Kind.minus)) {
    return AmountAmbiguity.unknownWord;
  }
  if (tokens.any((t) => t.badGrouping)) return AmountAmbiguity.grouping;
  for (var i = 1; i < tokens.length; i++) {
    // 'Rs 25,000.00 Cr' and '25,000.00 Cr' are a bank's credit, not crore.
    if (tokens[i].text == _credit &&
        ((tokens[i - 1].kind == _Kind.number && tokens[i - 1].decimals == 2) ||
            tokens.take(i).any((t) => t.kind == _Kind.currency))) {
      return AmountAmbiguity.freeTextWord;
    }
  }
  if (context == AmountContext.field) return null;
  if (tokens.any((t) => t.leadingZero)) return AmountAmbiguity.leadingZero;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final cues = amountFreeText[token.text];
    if (cues != null && !cues.any((cue) => _cued(tokens, i, cue))) {
      return AmountAmbiguity.freeTextWord;
    }
    if (amountSpaced.contains(token.text) &&
        !(token.joined && tokens[i - 1].kind == _Kind.number)) {
      return AmountAmbiguity.freeTextWord;
    }
  }
  return null;
}

/// The crore abbreviation that bank statements also write for "credit".
const String _credit = 'cr';

/// Whether [cue] comes before `tokens[i]`, so that its other meaning cannot
/// be meant there.
bool _cued(List<_Token> tokens, int i, AmountCue cue) {
  if (i == 0) return false;
  final before = tokens[i - 1];
  return switch (cue) {
    AmountCue.fraction => before.kind == _Kind.fraction,
    AmountCue.marker =>
      amountCurrencyMarkers.contains(before.text) &&
          tokens.skip(i + 1).any((t) => t.isMultiplier),
  };
}

/// The number below which a bare number after a group of this power would
/// fit the next unit down, so that the unit may have been left out: lakh and
/// crore take up to 99 of the unit below (hazar, lakh), as do kharab (arab);
/// million and billion (or arab, which shares its power) up to 999.
const Map<int, int> _elidedBelow = {5: 100, 6: 1000, 7: 100, 9: 1000, 11: 100};

AmountReading _read(List<_Token> tokens, AmountContext context) {
  var from = 0;
  var to = tokens.length;
  while (tokens[from].isMarker) {
    from++;
  }
  while (tokens[to - 1].kind == _Kind.filler) {
    to--;
  }
  var paisa = BigInt.zero;
  final hasPaisa = tokens[to - 1].kind == _Kind.paisa;
  if (hasPaisa) {
    final count = to - 3 >= from ? tokens[to - 2] : null;
    if (count == null ||
        count.kind != _Kind.number ||
        !count.value.isInteger ||
        count.value.compareTo(_Q.zero) <= 0 ||
        count.value.compareTo(_Q.integer(99)) > 0 ||
        tokens[to - 3].kind != _Kind.currency) {
      return const AmountAmbiguous(AmountAmbiguity.misplacedMarker);
    }
    paisa = count.value.numerator ~/ count.value.denominator;
    to -= 3;
  }
  while (to > from && tokens[to - 1].isMarker) {
    to--;
  }
  final middle = tokens.sublist(from, to);
  if (middle.isEmpty ||
      middle.any((t) => t.isMarker || t.kind == _Kind.paisa)) {
    return const AmountAmbiguous(AmountAmbiguity.misplacedMarker);
  }
  for (var i = 1; i < middle.length; i++) {
    if (middle[i].kind == _Kind.number && middle[i - 1].kind == _Kind.number) {
      return const AmountAmbiguous(AmountAmbiguity.adjacentNumbers);
    }
  }
  if (context == AmountContext.text &&
      middle.every((t) => t.isMultiplier) &&
      !tokens.any((t) => t.kind == _Kind.currency)) {
    return const AmountAmbiguous(AmountAmbiguity.bareMultiplier);
  }
  final last = middle.last;
  if (last.kind == _Kind.number && last.decimals > 2) {
    return const AmountAmbiguous(AmountAmbiguity.grouping);
  }

  final _Q rupees;
  final fractional = middle.indexed.any(
    (e) =>
        e.$2.kind == _Kind.fraction ||
        (e.$2.decimals > 0 && e.$1 != middle.length - 1),
  );
  if (fractional) {
    final value = _fractionForm(middle);
    if (value == null) {
      return const AmountAmbiguous(AmountAmbiguity.misplacedFraction);
    }
    rupees = value;
  } else {
    if (middle.length > 1 &&
        middle.any((t) => t.kind == _Kind.number && t.value.isZero)) {
      return const AmountAmbiguous(AmountAmbiguity.order);
    }
    final value = _expression(middle, 0, middle.length, rest: false);
    if (value == null) return const AmountAmbiguous(AmountAmbiguity.order);
    if (middle.length > 1 && last.kind == _Kind.number) {
      final group = middle[middle.length - 2];
      final below = _elidedBelow[group.index];
      final pinned = to < tokens.length && tokens[to].kind == _Kind.currency;
      if (group.isMultiplier &&
          below != null &&
          last.value.compareTo(_Q.integer(below)) < 0 &&
          !pinned) {
        return const AmountAmbiguous(AmountAmbiguity.elidedMultiplier);
      }
    }
    rupees = value;
  }
  if (hasPaisa && !rupees.isInteger) {
    return const AmountAmbiguous(AmountAmbiguity.misplacedMarker);
  }

  final scaled = rupees.numerator * _hundred;
  if (scaled % rupees.denominator != BigInt.zero) {
    return const AmountNotFound(AmountAbsence.belowPaisa);
  }
  final total = scaled ~/ rupees.denominator + paisa;
  if (total > BigInt.from(Money.maxValue.paisa)) {
    return const AmountNotFound(AmountAbsence.outOfRange);
  }
  return AmountFound(Money.fromPaisa(total.toInt()));
}

/// A fraction or a decimal quantity, then one or more multipliers in rising
/// order (`sawa do lakh`, `ڈیڑھ لاکھ`, `1.5 lac`, `paune sau`); `null`
/// for anything else.
_Q? _fractionForm(List<_Token> t) {
  final first = t.first;
  _Q quantity;
  var next = 1;
  if (first.kind == _Kind.fraction) {
    final f = amountFractions[first.index];
    final part = _Q(BigInt.from(f.num), BigInt.from(f.den));
    if (!f.prefix) {
      quantity = part;
    } else if (t.length > 1 && t[1].kind == _Kind.number) {
      final n = t[1].value;
      // A digit number of 100 or more after a prefix may be a transcribed
      // 'sau' or 'do sau' ('sawa 100 hazar' for 'sawa sau hazar', 125,000).
      if (!n.isInteger ||
          n.compareTo(_Q.integer(f.minNumber)) < 0 ||
          n.compareTo(_Q.integer(100)) >= 0) {
        return null;
      }
      quantity = n + part;
      next = 2;
    } else if (f.alone) {
      quantity = _Q.one + part;
    } else {
      return null;
    }
  } else if (first.kind == _Kind.number && first.decimals > 0) {
    quantity = first.value;
  } else {
    return null;
  }
  if (next == t.length) return null;
  var power = -1;
  for (final token in t.skip(next)) {
    if (!token.isMultiplier || token.index <= power) return null;
    power = token.index;
    quantity = quantity.times(_tenTo(power));
  }
  return quantity;
}

/// The tokens [from] to [to] as groups in strictly descending order, then
/// the units: the highest multiplier must be the only one of its power, its
/// quantity is everything before it (itself an expression with lower
/// multipliers only), and everything after it is less than one of it.
/// Because the highest multiplier fixes where the first group ends, there is
/// at most one reading. [below] bounds the multipliers inside a quantity;
/// [rest] is true after a group, where the remainder must start with a
/// number: a multiplier there has no number before it, so the one it would
/// imply is a guess ('5 hazar sau', and '5 crore sau hazar', which is not
/// read as 5 crore and 1 lakh). Nested quantities do not lift this.
_Q? _expression(
  List<_Token> t,
  int from,
  int to, {
  required bool rest,
  int? below,
}) {
  if (rest && t[from].isMultiplier) return null;
  var at = -1;
  var power = -1;
  var count = 0;
  for (var i = from; i < to; i++) {
    if (!t[i].isMultiplier) continue;
    if (t[i].index > power) {
      power = t[i].index;
      at = i;
      count = 1;
    } else if (t[i].index == power) {
      count++;
    }
  }
  if (at < 0) {
    // Units: one number and nothing else.
    return to == from + 1 && t[from].kind == _Kind.number
        ? t[from].value
        : null;
  }
  if (count > 1 || (below != null && power >= below)) return null;
  final _Q quantity;
  if (at == from) {
    if (t[at].kind == _Kind.plural || t[at].isAbbreviation) return null;
    quantity = _Q.one;
  } else {
    final value = _expression(t, from, at, rest: false, below: power);
    if (value == null) return null;
    quantity = value;
  }
  final group = quantity.times(_tenTo(power));
  if (at + 1 == to) return group;
  // Inside a quantity, a group with more after it is a number below a
  // thousand ('ek sau pachas crore', 'one hundred and fifty thousand');
  // 'pachas hazar do lakh' is groups out of order, not a quantity of lakhs.
  if (below != null &&
      !rest &&
      (power != 2 ||
          at != from + 1 ||
          t[from].kind != _Kind.number ||
          !t[from].value.isInteger ||
          t[from].value.compareTo(_Q.integer(9)) > 0)) {
    return null;
  }
  final _Q? remainder;
  if (t[at + 1].kind == _Kind.connector) {
    // 'and' before the last number of a group: 'one hundred and fifty'.
    remainder = at + 3 == to && t[at + 2].kind == _Kind.number
        ? t[at + 2].value
        : null;
  } else {
    remainder = _expression(t, at + 1, to, rest: true, below: power);
  }
  if (remainder == null ||
      remainder.compareTo(_Q(_tenTo(power), BigInt.one)) >= 0) {
    return null;
  }
  return group + remainder;
}

/// Joins an English tens word and the unit after it: `twenty one` is 21.
List<_Token> _mergeEnglishTens(List<_Token> tokens) {
  final out = <_Token>[];
  for (final token in tokens) {
    final previous = out.isEmpty ? null : out.last;
    if (previous != null &&
        previous.isEnglishTens &&
        token.english &&
        token.kind == _Kind.number &&
        token.index >= 1 &&
        token.index <= 9) {
      out[out.length - 1] = _Token.word(
        '${previous.text} ${token.text}',
        _Kind.number,
        previous.index + token.index,
        english: true,
        joined: previous.joined,
      );
    } else {
      out.add(token);
    }
  }
  return out;
}

// --- normalising and splitting --------------------------------------------

String _normalise(String input) {
  final buffer = StringBuffer();
  for (final rune in normalizeDigits(input).runes) {
    if (amountRemoved.any((r) => rune >= r.$1 && rune <= r.$2)) continue;
    final fold = amountFolds[rune];
    if (fold != null) {
      buffer.write(fold);
    } else if (rune >= 0x41 && rune <= 0x5A) {
      buffer.writeCharCode(rune + 0x20);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isLatin(int c) => c >= 0x61 && c <= 0x7A;

/// Arabic-script letters; the Arabic comma, semicolon, question mark, full
/// stop and per cent sign are signs, and the digits and separators are
/// handled before.
bool _isArabicLetter(int c) =>
    ((c >= 0x0600 && c <= 0x06FF) ||
        (c >= 0x0750 && c <= 0x077F) ||
        (c >= 0x08A0 && c <= 0x08FF) ||
        (c >= 0xFB50 && c <= 0xFDFF) ||
        (c >= 0xFE70 && c <= 0xFEFC)) &&
    !const {0x060C, 0x061B, 0x061F, 0x066A, 0x066B, 0x066C, 0x06D4}.contains(c);

List<_Token> _tokenize(String text) {
  final c = text.runes.toList();
  final tokens = <_Token>[];
  var i = 0;
  var joined = false;
  String slice(int from, int to) => String.fromCharCodes(c, from, to);
  while (i < c.length) {
    final rune = c[i];
    if (amountSpaces.contains(rune)) {
      i++;
      joined = false;
      continue;
    }
    final glued = joined && tokens.isNotEmpty;
    if (_isDigit(rune)) {
      final groups = <String>[];
      var j = i;
      while (true) {
        final from = j;
        while (j < c.length && _isDigit(c[j])) {
          j++;
        }
        groups.add(slice(from, j));
        if (j + 1 < c.length &&
            amountGroupingSeparators.contains(c[j]) &&
            _isDigit(c[j + 1])) {
          j++;
        } else {
          break;
        }
      }
      var fraction = '';
      if (j + 1 < c.length &&
          amountDecimalSeparators.contains(c[j]) &&
          _isDigit(c[j + 1])) {
        final from = ++j;
        while (j < c.length && _isDigit(c[j])) {
          j++;
        }
        fraction = slice(from, j);
      }
      tokens.add(_Token.digits(groups, fraction, joined: glued));
      i = j;
    } else if (_isLatin(rune)) {
      var j = i;
      while (j < c.length &&
          (_isLatin(c[j]) ||
              (c[j] == 0x2D && j + 1 < c.length && _isLatin(c[j + 1])))) {
        j++;
      }
      if (j < c.length &&
          amountDecimalSeparators.contains(c[j]) &&
          amountWords.containsKey('${slice(i, j)}.')) {
        j++;
      }
      tokens.add(_Token.lookup(slice(i, j), joined: glued));
      i = j;
    } else if (_isArabicLetter(rune)) {
      var j = i;
      while (j < c.length && _isArabicLetter(c[j])) {
        j++;
      }
      tokens.add(_Token.lookup(slice(i, j), joined: glued));
      i = j;
    } else if (rune == 0x2F &&
        i + 1 < c.length &&
        amountWords.containsKey(slice(i, i + 2))) {
      // A trailing '/-' or '/='.
      tokens.add(_Token.lookup(slice(i, i + 2), joined: glued));
      i += 2;
    } else if (rune == 0x2D || rune == 0x2212) {
      tokens.add(_Token.word('-', _Kind.minus, 0, joined: glued));
      i++;
    } else {
      tokens.add(_Token.lookup(slice(i, i + 1), joined: glued));
      i++;
    }
    joined = true;
  }
  return tokens;
}

// --- tokens -----------------------------------------------------------------

enum _Kind {
  number,
  fraction,
  multiplier,
  plural,
  currency,
  paisa,
  foreign,
  filler,
  connector,
  refused,
  unknown,
  minus,
}

const Map<AmountWordKind, _Kind> _kinds = {
  AmountWordKind.number: _Kind.number,
  AmountWordKind.fraction: _Kind.fraction,
  AmountWordKind.multiplier: _Kind.multiplier,
  AmountWordKind.plural: _Kind.plural,
  AmountWordKind.currency: _Kind.currency,
  AmountWordKind.paisa: _Kind.paisa,
  AmountWordKind.foreignCurrency: _Kind.foreign,
  AmountWordKind.filler: _Kind.filler,
  AmountWordKind.connector: _Kind.connector,
};

final class _Token {
  new word(
    this.text,
    this.kind,
    this.index, {
    required this.joined,
    this.english = false,
  }) : exact = _Q.integer(index),
       excess = null,
       decimals = 0,
       badGrouping = false,
       leadingZero = false;

  factory digits(List<String> groups, String fraction, {required bool joined}) {
    final whole = groups.join();
    final (exact, excess) = _digitValue(whole, fraction);
    return _Token._digits(
      whole,
      exact,
      excess,
      fraction.length,
      badGrouping: !_groupingOk(groups),
      leadingZero: groups.first.length > 1 && groups.first.startsWith('0'),
      joined: joined,
    );
  }

  new _digits(
    this.text,
    this.exact,
    this.excess,
    this.decimals, {
    required this.badGrouping,
    required this.leadingZero,
    required this.joined,
  }) : kind = _Kind.number,
       index = -1,
       english = false;

  factory lookup(String text, {required bool joined}) {
    if (amountRefused.contains(text)) {
      return _Token.word(text, _Kind.refused, 0, joined: joined);
    }
    final meaning = amountWords[text];
    if (meaning == null) {
      return _Token.word(text, _Kind.unknown, 0, joined: joined);
    }
    return _Token.word(
      text,
      _kinds[meaning.$1]!,
      meaning.$2,
      english: meaning.$3,
      joined: joined,
    );
  }

  /// The normalised spelling.
  final String text;
  final _Kind kind;

  /// A word number's value, a multiplier's power or a fraction's index.
  final int index;
  final bool english;

  /// Whether no space separates this token from the one before.
  final bool joined;

  /// A number's value in rupees, exact; `null` for a digit number beyond
  /// the bound in [_digitValue], which says why in [excess].
  final _Q? exact;

  /// Why a digit number has no [exact] value: above the maximum or below a
  /// paisa in every reading.
  final AmountAbsence? excess;

  /// A number's value in rupees. [parseAmount] stops at a token with an
  /// [excess] before reading any value, so this never throws.
  _Q get value => exact!;

  /// A digit number's decimal places.
  final int decimals;
  final bool badGrouping;
  final bool leadingZero;

  bool get isQuantity =>
      kind == _Kind.number || kind == _Kind.fraction || isMultiplier;

  bool get isMultiplier => kind == _Kind.multiplier || kind == _Kind.plural;

  /// A Latin spelling of one or two letters (`k`, `m`, `mn`, `cr`), which
  /// needs a number before it.
  bool get isAbbreviation => text.length <= 2 && _isLatin(text.codeUnitAt(0));

  /// A rupee marker or `only`, which may stand before or after an amount.
  bool get isMarker => kind == _Kind.currency || kind == _Kind.filler;

  bool get isEnglishTens =>
      english && kind == _Kind.number && index >= 20 && index % 10 == 0;
}

/// The longest whole part a number inside an amount can have: 15 digits
/// are at least Rs 10^14, and even as paise (10^14 paisa) that is above the
/// largest amount, `numeric(14,2)`'s 99,999,999,999,999 paisa.
const int _wholeDigits = 14;

/// The most decimal places any reading can make whole paisa: two, and the
/// powers of ten of every multiplier, because a decimal quantity takes each
/// multiplier power at most once, in rising order (`_fractionForm`), and a
/// decimal anywhere else must have at most two places. With today's lexicon
/// that is 2 + 2 + 3 + 5 + 6 + 7 + 9 + 11 = 45:
/// `0.000…01 sau hazar lakh million crore billion کھرب` with 45 places is
/// one paisa.
final int _maxDecimals = amountWords.values
    .where(
      (m) => m.$1 == AmountWordKind.multiplier || m.$1 == AmountWordKind.plural,
    )
    .map((m) => m.$2)
    .toSet()
    .fold(2, (sum, power) => sum + power);

/// The exact value of a digit number in rupees, or why it has none.
///
/// Leading zeros of the whole part and trailing zeros of the decimal part
/// are skipped without parsing, so a long run of them costs no more than a
/// scan (BigInt.parse is not linear). What is left is parsed in full, never
/// cut short or stood in for, but only within a bound that keeps it short:
///
/// * more than [_maxDecimals] decimal places: no multipliers make the
///   number whole paisa, so every reading is below a paisa
///   ([AmountAbsence.belowPaisa]);
/// * a whole part of more than [_wholeDigits] digits: every reading is
///   above the maximum ([AmountAbsence.outOfRange]).
///
/// Within the bound the number has at most 14 + 45 digits, read exactly,
/// so every comparison the grammar makes is on the real value.
(_Q?, AmountAbsence?) _digitValue(String whole, String fraction) {
  var from = 0;
  while (from < whole.length && whole.codeUnitAt(from) == 0x30) {
    from++;
  }
  var to = fraction.length;
  while (to > 0 && fraction.codeUnitAt(to - 1) == 0x30) {
    to--;
  }
  if (to > _maxDecimals) return (null, AmountAbsence.belowPaisa);
  if (whole.length - from > _wholeDigits) {
    return (null, AmountAbsence.outOfRange);
  }
  final digits = '0${whole.substring(from)}${fraction.substring(0, to)}';
  return (_Q(BigInt.parse(digits), _tenTo(to)), null);
}

/// Western (`1,234,567`) or South Asian (`12,34,567`) grouping, or none.
/// No grouping starts with a zero group: `0,500` is more likely a decimal
/// comma (0.5) than five hundred.
bool _groupingOk(List<String> groups) {
  if (groups.length == 1) return true;
  if (groups.first.startsWith('0')) return false;
  final first = groups.first.length;
  final middle = groups.sublist(1, groups.length - 1).map((g) => g.length);
  if (groups.last.length != 3 || first > 3) return false;
  if (middle.every((n) => n == 3)) return true;
  return first <= 2 && middle.every((n) => n == 2);
}

// --- exact rationals --------------------------------------------------------

final BigInt _hundred = BigInt.from(100);

BigInt _tenTo(int power) => BigInt.from(10).pow(power);

/// A non-negative rational number, numerator over denominator, exact.
@immutable
final class _Q {
  const new(this.numerator, this.denominator);

  new integer(int value) : this(BigInt.from(value), BigInt.one);

  static final _Q zero = _Q.integer(0);
  static final _Q one = _Q.integer(1);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;

  bool get isInteger => numerator % denominator == BigInt.zero;

  _Q operator +(_Q other) => _Q(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  _Q times(BigInt factor) => _Q(numerator * factor, denominator);

  int compareTo(_Q other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
}
