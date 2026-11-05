import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Builds the app's [ThemeData] from the design tokens.
///
/// Material roles are mapped from the token roles so stock widgets look
/// right, but brass is kept out of the [ColorScheme] on purpose: it marks
/// only what deserves honour (a nameplate, a receipt seal), so components
/// take it from `context.mm` deliberately. Surfaces are flat paper: no tint
/// overlays and no shadows except on true overlays (sheets, dialogs, menus).
abstract final class MmTheme {
  /// The theme for [brightness], [script] and contrast preference.
  static ThemeData data({
    required Brightness brightness,
    MmScript script = MmScript.latin,
    bool highContrast = false,
  }) {
    final colors = tokensFor(brightness, highContrast: highContrast);
    final inverse = tokensFor(
      brightness == Brightness.light ? Brightness.dark : Brightness.light,
      highContrast: highContrast,
    );
    final scheme = _scheme(colors, inverse, brightness);
    final text = textTheme(script, colors);
    final focusSide = BorderSide(color: colors.focus, width: MmSize.focusRing);

    WidgetStateProperty<BorderSide?> outlinedSide(BorderSide resting) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return resting.copyWith(color: colors.rule);
          }
          return states.contains(WidgetState.focused) ? focusSide : resting;
        });

    final buttonShape = WidgetStateProperty.all<OutlinedBorder>(
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(MmRadius.sm)),
      ),
    );
    const minimumButtonSize = WidgetStatePropertyAll<Size>(
      Size(64, MmSize.buttonHeight),
    );
    final buttonPadding = WidgetStateProperty.all<EdgeInsetsGeometry>(
      const EdgeInsetsDirectional.symmetric(horizontal: MmSpace.s4),
    );
    final labelStyle = WidgetStateProperty.all<TextStyle?>(text.labelLarge);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      dividerColor: colors.rule,
      focusColor: colors.focus.withValues(alpha: 0.12),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      extensions: [
        MmSemantics.from(colors, script: script, highContrast: highContrast),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarHeight: MmSize.appBar,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.md)),
          side: BorderSide(color: colors.rule),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          textStyle: labelStyle,
          side: outlinedSide(BorderSide.none),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        // Paper does not float: elevated buttons render like filled ones.
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          textStyle: labelStyle,
          side: outlinedSide(BorderSide.none),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.rule
                : colors.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.inkMuted
                : colors.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          textStyle: labelStyle,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.inkMuted
                : colors.primary,
          ),
          side: outlinedSide(BorderSide(color: colors.outline)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(
            Size(MmSize.minTarget, MmSize.buttonHeight),
          ),
          padding: buttonPadding,
          textStyle: labelStyle,
          side: outlinedSide(BorderSide.none),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(MmSize.minTarget),
          ),
          side: outlinedSide(BorderSide.none),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.md)),
          side: BorderSide(color: colors.primary),
        ),
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        isDense: false,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s4,
          vertical: MmSpace.s4,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: colors.inkMuted),
        helperStyle: text.bodyMedium?.copyWith(color: colors.inkMuted),
        errorStyle: text.bodyMedium?.copyWith(color: colors.overdue),
        prefixStyle: text.bodyLarge?.copyWith(color: colors.inkMuted),
        suffixStyle: text.bodyLarge?.copyWith(color: colors.inkMuted),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: _fieldBorder(colors.outline, 1),
        enabledBorder: _fieldBorder(colors.outline, 1),
        focusedBorder: _fieldBorder(colors.focus, MmSize.focusRing),
        errorBorder: _fieldBorder(colors.overdue, 1),
        focusedErrorBorder: _fieldBorder(colors.overdue, MmSize.focusRing),
        disabledBorder: _fieldBorder(colors.rule, 1),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceSunken,
        labelStyle: text.labelLarge?.copyWith(color: colors.ink),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: colors.onPrimaryContainer,
        ),
        side: BorderSide(color: colors.outline),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MmRadius.xs)),
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MmSpace.s2),
        checkmarkColor: colors.onPrimaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MmRadius.lg)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        elevation: 3,
        modalElevation: 3,
        showDragHandle: true,
        dragHandleColor: colors.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MmRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MmRadius.sm)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: MmSpace.s3,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s4,
        ),
        iconColor: colors.inkMuted,
        textColor: colors.ink,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: colors.inkMuted),
        selectedColor: colors.primary,
        selectedTileColor: colors.primaryContainer,
        minTileHeight: MmSize.fieldHeight,
      ),
      dividerTheme: DividerThemeData(
        color: colors.rule,
        thickness: MmSize.hairline,
        space: MmSize.hairline,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.ink
                : colors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: MmSize.iconLg,
            color: states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
        minWidth: MmSize.navRail,
        selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.inkMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: colors.ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.inkMuted,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryContainer,
        circularTrackColor: colors.primaryContainer,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
        ),
        textStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }

  /// The colour tokens of a mode.
  static MmColorTokens tokensFor(
    Brightness brightness, {
    bool highContrast = false,
  }) => switch ((brightness, highContrast)) {
    (Brightness.light, false) => MmColorModes.light,
    (Brightness.dark, false) => MmColorModes.dark,
    (Brightness.light, true) => MmColorModes.lightHighContrast,
    (Brightness.dark, true) => MmColorModes.darkHighContrast,
  };

  /// The [TextTheme] of [script] in [colors].
  static TextTheme textTheme(MmScript script, MmColorTokens colors) {
    final urdu = script == MmScript.urdu;
    // Urdu UI text is set in Nastaliq (with its natural word spacing); user
    // data written in Latin script goes through MmSemantics.styleFor, which
    // sets it in Atkinson instead of Nastaliq's serif Latin.
    TextStyle style(TextStyle latin, TextStyle nastaliq) =>
        (urdu ? nastaliq : latin).copyWith(color: colors.ink);
    final amount = style(MmTypeScale.latinAmount, MmTypeScale.urduAmount);
    final headline = style(MmTypeScale.latinHeadline, MmTypeScale.urduHeadline);
    final title = style(MmTypeScale.latinTitle, MmTypeScale.urduTitle);
    final titleSmall = style(
      MmTypeScale.latinTitleSmall,
      MmTypeScale.urduTitleSmall,
    );
    final body = style(MmTypeScale.latinBody, MmTypeScale.urduBody);
    final bodySmall = style(
      MmTypeScale.latinBodySmall,
      MmTypeScale.urduBodySmall,
    );
    final label = style(MmTypeScale.latinLabel, MmTypeScale.urduLabel);
    final caption = style(MmTypeScale.latinCaption, MmTypeScale.urduCaption);
    return TextTheme(
      displayLarge: amount,
      displayMedium: amount,
      displaySmall: amount,
      headlineLarge: headline,
      headlineMedium: headline,
      headlineSmall: headline,
      titleLarge: title,
      titleMedium: titleSmall,
      titleSmall: label,
      bodyLarge: body,
      bodyMedium: bodySmall,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: caption.copyWith(fontWeight: label.fontWeight),
      labelSmall: caption,
    );
  }

  static ColorScheme _scheme(
    MmColorTokens colors,
    MmColorTokens inverse,
    Brightness brightness,
  ) => ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryContainer: colors.primaryContainer,
    onPrimaryContainer: colors.onPrimaryContainer,
    // Secondary roles stay cobalt-tonal: Material paints navigation
    // indicators with them, which appear on every screen.
    secondary: colors.primary,
    onSecondary: colors.onPrimary,
    secondaryContainer: colors.primaryContainer,
    onSecondaryContainer: colors.onPrimaryContainer,
    tertiary: colors.credit,
    onTertiary: colors.surface,
    tertiaryContainer: colors.creditContainer,
    onTertiaryContainer: colors.onCreditContainer,
    error: colors.overdue,
    onError: colors.surface,
    errorContainer: colors.overdueContainer,
    onErrorContainer: colors.onOverdueContainer,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.inkMuted,
    surfaceDim: colors.surfaceSunken,
    surfaceBright: colors.surface,
    surfaceContainerLowest: colors.surface,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.surface,
    surfaceContainerHighest: colors.surfaceSunken,
    outline: colors.outline,
    outlineVariant: colors.rule,
    // Material draws shadows and scrims in black and sets their opacity.
    shadow: Colors.black, // design-lint: allow Material shadow colour
    scrim: Colors.black, // design-lint: allow Material scrim colour
    inverseSurface: inverse.surface,
    onInverseSurface: inverse.ink,
    inversePrimary: inverse.primary,
    surfaceTint: Colors.transparent,
  );

  static OutlineInputBorder _fieldBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.sm)),
        borderSide: BorderSide(color: color, width: width),
      );
}
