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
    const tabular = [FontFeature.tabularFigures()];
    return MmSemantics(
      colors: colors,
      script: script,
      highContrast: highContrast,
      amountLarge: withUrduFallback(
        MmTypeScale.latinAmount.copyWith(
          color: colors.ink,
          fontFeatures: tabular,
        ),
      ),
      amount: withUrduFallback(
        MmTypeScale.latinTitleSmall.copyWith(
          color: colors.ink,
          fontFeatures: tabular,
        ),
      ),
    );
  }

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
