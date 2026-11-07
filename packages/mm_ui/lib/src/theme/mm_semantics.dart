import 'package:flutter/material.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The script a theme sets text in: Latin for English, Nastaliq for Urdu.
enum MmScript {
  /// Atkinson Hyperlegible Next.
  latin,

  /// Noto Nastaliq Urdu (right to left, about twice the line height).
  urdu;

  /// The script of [locale]: Urdu for `ur`, Latin for everything else.
  static MmScript of(Locale locale) =>
      locale.languageCode == 'ur' ? MmScript.urdu : MmScript.latin;
}

/// The design system's own theme data, beyond what [ColorScheme] and
/// [TextTheme] can express: every colour role (status colours, brass), the
/// script, and the amount styles. Read it with `context.mm`.
@immutable
final class MmSemantics extends ThemeExtension<MmSemantics> {
  /// Creates the semantics of one theme.
  const new({
    required this.colors,
    required this.script,
    required this.highContrast,
    required this.amountLarge,
    required this.amount,
  });

  /// Builds the semantics for [colors] and [script].
  factory from(
    MmColorTokens colors, {
    required MmScript script,
    required bool highContrast,
  }) {
    // Amounts are always set in the Latin face with tabular figures, in both
    // languages, so columns of rupees line up and stay unambiguous. The
    // Urdu currency word (روپے) after an amount falls back to Nastaliq.
    return MmSemantics(
      colors: colors,
      script: script,
      highContrast: highContrast,
      amountLarge: withUrduFallback(
        withTabularFigures(MmTypeScale.latinAmount.copyWith(color: colors.ink)),
      ),
      amount: withUrduFallback(
        withTabularFigures(
          MmTypeScale.latinTitleSmall.copyWith(color: colors.ink),
        ),
      ),
    );
  }

  /// [style] with tabular figures: every digit as wide as the others, so
  /// figures in a column or a counting value line up and a 1 never looks
  /// narrower than a 7. Keeps the style's other font features.
  ///
  /// Amounts, counts, percentages, receipt numbers and the values of
  /// detail rows use it; [amount] and [amountLarge] already have it.
  static TextStyle withTabularFigures(TextStyle style) => style.copyWith(
    fontFeatures: [
      ...?style.fontFeatures?.where((feature) => feature.feature != 'tnum'),
      const FontFeature.tabularFigures(),
    ],
  );

  /// [style] with Noto Nastaliq Urdu as its fallback face.
  ///
  /// The Latin face has no Arabic-script letters. Without a fallback, Urdu
  /// in a Latin style (a tenant's name typed in Urdu in the English UI, the
  /// currency word after an amount) is set in whatever face the platform
  /// offers, or as empty boxes. The theme's Latin text styles and amount
  /// styles already have it; use this for a style built from
  /// [MmTypeScale] directly.
  ///
  /// [style] must be set in one of mm_ui's bundled faces (any style of the
  /// theme, `context.mm` or [MmTypeScale]): the fallback is named the way
  /// the package declares its fonts.
  static TextStyle withUrduFallback(TextStyle style) {
    assert(
      style.fontFamily?.startsWith('packages/mm_ui/') ?? false,
      "withUrduFallback needs a style in one of mm_ui's faces",
    );
    return style.copyWith(
      fontFamilyFallback: const [MmFontFamily.urdu],
      package: 'mm_ui',
    );
  }

  /// Every colour role of the current mode.
  final MmColorTokens colors;

  /// The script text is set in.
  final MmScript script;

  /// Whether a high-contrast mode is active.
  final bool highContrast;

  /// The one large figure of a screen (balance, total due).
  final TextStyle amountLarge;

  /// Amounts in lists, chips and forms.
  final TextStyle amount;

  /// [style] for showing [text] that a user wrote (a name, an address, a
  /// note). In the Urdu UI, text without any Arabic-script letter (a name
  /// typed in English, a CNIC) is set in Atkinson rather than Nastaliq's
  /// serif Latin, on the same line height so rows stay even.
  TextStyle styleFor(String text, TextStyle style) {
    if (script != MmScript.urdu || hasArabicScript(text)) return style;
    return style.copyWith(fontFamily: MmFontFamily.latin, package: 'mm_ui');
  }

  /// Whether [text] contains a letter of the Arabic script (Urdu).
  static bool hasArabicScript(String text) => text.runes.any(
    (rune) =>
        (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF),
  );

  /// The direction of [text]'s first letter: right to left for a letter of
  /// a right-to-left script (Urdu, Arabic, Hebrew), left to right for any
  /// other letter, and null when [text] has no letter (a CNIC, a phone
  /// number, an amount). Digits and punctuation take the direction of the
  /// text around them, so they do not decide it.
  static TextDirection? firstStrongDirection(String text) {
    final letter = _letter.firstMatch(text);
    if (letter == null) return null;
    return _rightToLeftLetter.hasMatch(letter[0]!)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  /// [text] as it should sit in a paragraph running in [direction]: kept
  /// apart in its own direction (a Unicode isolate) when that differs, so
  /// it reads in its own order. Unchanged when it already runs that way.
  ///
  /// The landlord's data comes in either script. Without this, an Urdu
  /// address in the English UI wraps with its words in left-to-right order,
  /// a sentence typed in English ends with its full stop on the wrong side
  /// in the Urdu UI, and the groups of a number such as "0412 3345 6789"
  /// come out reversed in the Urdu UI. Text without letters runs left to
  /// right. Show the result, but give screen readers [text] itself.
  static String isolated(String text, TextDirection direction) {
    final own = firstStrongDirection(text) ?? TextDirection.ltr;
    if (text.isEmpty || own == direction) return text;
    return own == TextDirection.rtl
        ? '$_rightToLeftIsolate$text$_popIsolate'
        : '$_leftToRightIsolate$text$_popIsolate';
  }

  /// [text], an identifier (a CNIC, a phone, account or consumer number),
  /// kept left to right and on one line wherever it sits. Inside an Urdu
  /// sentence the groups of "0412 3345 6789" would otherwise come out in
  /// reverse order, and anywhere they could be split across two lines; its
  /// spaces become no-break spaces.
  ///
  /// Use it when building a sentence around a number from the app's
  /// localisations:
  ///
  /// ```dart
  /// l10n.consumerNumber(MmSemantics.leftToRight(bill.consumerNumber))
  /// ```
  static String leftToRight(String text) =>
      '$_leftToRightIsolate${text.replaceAll(' ', _noBreakSpace)}$_popIsolate';

  static const _noBreakSpace = '\u00A0';

  static const _leftToRightIsolate = '\u2066';
  static const _rightToLeftIsolate = '\u2067';
  static const _popIsolate = '\u2069';

  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _rightToLeftLetter = RegExp(
    r'[\p{Script=Arabic}\p{Script=Hebrew}\p{Script=Syriac}'
    r'\p{Script=Thaana}\p{Script=Nko}]',
    unicode: true,
  );

  @override
  MmSemantics copyWith({
    MmColorTokens? colors,
    MmScript? script,
    bool? highContrast,
    TextStyle? amountLarge,
    TextStyle? amount,
  }) => MmSemantics(
    colors: colors ?? this.colors,
    script: script ?? this.script,
    highContrast: highContrast ?? this.highContrast,
    amountLarge: amountLarge ?? this.amountLarge,
    amount: amount ?? this.amount,
  );

  @override
  MmSemantics lerp(covariant MmSemantics? other, double t) {
    if (other == null) return this;
    final a = colors;
    final b = other.colors;
    Color mix(Color x, Color y) => Color.lerp(x, y, t)!;
    return MmSemantics(
      colors: MmColorTokens(
        bg: mix(a.bg, b.bg),
        surface: mix(a.surface, b.surface),
        surfaceSunken: mix(a.surfaceSunken, b.surfaceSunken),
        ink: mix(a.ink, b.ink),
        inkMuted: mix(a.inkMuted, b.inkMuted),
        outline: mix(a.outline, b.outline),
        rule: mix(a.rule, b.rule),
        primary: mix(a.primary, b.primary),
        onPrimary: mix(a.onPrimary, b.onPrimary),
        primaryContainer: mix(a.primaryContainer, b.primaryContainer),
        onPrimaryContainer: mix(a.onPrimaryContainer, b.onPrimaryContainer),
        brass: mix(a.brass, b.brass),
        brassText: mix(a.brassText, b.brassText),
        brassContainer: mix(a.brassContainer, b.brassContainer),
        onBrassContainer: mix(a.onBrassContainer, b.onBrassContainer),
        paid: mix(a.paid, b.paid),
        paidContainer: mix(a.paidContainer, b.paidContainer),
        onPaidContainer: mix(a.onPaidContainer, b.onPaidContainer),
        overdue: mix(a.overdue, b.overdue),
        overdueContainer: mix(a.overdueContainer, b.overdueContainer),
        onOverdueContainer: mix(a.onOverdueContainer, b.onOverdueContainer),
        dueSoon: mix(a.dueSoon, b.dueSoon),
        dueSoonContainer: mix(a.dueSoonContainer, b.dueSoonContainer),
        onDueSoonContainer: mix(a.onDueSoonContainer, b.onDueSoonContainer),
        credit: mix(a.credit, b.credit),
        creditContainer: mix(a.creditContainer, b.creditContainer),
        onCreditContainer: mix(a.onCreditContainer, b.onCreditContainer),
        focus: mix(a.focus, b.focus),
      ),
      script: t < 0.5 ? script : other.script,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      amountLarge: TextStyle.lerp(amountLarge, other.amountLarge, t)!,
      amount: TextStyle.lerp(amount, other.amount, t)!,
    );
  }
}

/// Access to the design system's semantics from any widget.
extension MmContext on BuildContext {
  /// The [MmSemantics] of the nearest theme. Throws when the app's theme was
  /// not built by `MmTheme`, which is a programming error.
  MmSemantics get mm {
    final semantics = Theme.of(this).extension<MmSemantics>();
    if (semantics == null) {
      throw FlutterError(
        'No MmSemantics in the theme: build it with MmTheme.data().',
      );
    }
    return semantics;
  }
}
