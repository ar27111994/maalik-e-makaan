import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_focus_ring.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Builds the app's [ThemeData] from the design tokens.
///
/// Material roles are mapped from the token roles so stock widgets look
/// right, but brass is kept out of the [ColorScheme] on purpose: it marks
/// only what deserves honour (a nameplate, a receipt seal), so components
/// take it from `context.mm` deliberately. Surfaces are flat paper: no tint
/// overlays and no shadows except on true overlays (sheets, dialogs, menus).
///
/// Keyboard focus is a [MmSize.focusRing] ring in the focus colour: on the
/// edge of outlined and text buttons, segmented buttons, chips and fields,
/// and outside filled, elevated and icon buttons and the floating action
/// button, past a [MmSize.focusGap] gap ([MmFocusRingBorder]), because a
/// ring on a filled control's edge would be the colour of its fill.
/// Disabled buttons are muted ink; filled ones sit on sunken paper inside
/// the rule border of a disabled outlined button.
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

    // Colours a button style only while disabled, leaving each kind of
    // button its own enabled colours.
    WidgetStateProperty<Color?> whileDisabled(Color color) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? color : null,
        );

    const buttonOutline = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(MmRadius.sm)),
    );
    const buttonShape = WidgetStatePropertyAll<OutlinedBorder>(buttonOutline);
    // Filled buttons: the focus ring goes outside, past a gap; their only
    // border is the rule around a disabled one.
    final filledShape = MmFocusRingBorder.whenFocused(
      buttonOutline,
      color: colors.focus,
    );
    final filledSide = WidgetStateProperty.resolveWith<BorderSide?>(
      (states) => states.contains(WidgetState.disabled)
          ? BorderSide(color: colors.rule)
          : BorderSide.none,
    );
    final disabledFill = whileDisabled(colors.surfaceSunken);
    final disabledInk = whileDisabled(colors.inkMuted);
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
          shape: filledShape,
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          textStyle: labelStyle,
          side: filledSide,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: disabledFill,
          foregroundColor: disabledInk,
          iconColor: disabledInk,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        // Paper does not float: elevated buttons render like filled ones.
        style: ButtonStyle(
          shape: filledShape,
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          textStyle: labelStyle,
          side: filledSide,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.surfaceSunken
                : colors.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.inkMuted
                : colors.onPrimary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
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
          iconColor: disabledInk,
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
          foregroundColor: disabledInk,
          iconColor: disabledInk,
          side: outlinedSide(BorderSide.none),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(MmSize.minTarget),
          ),
          // Any icon button may be filled, so all draw the ring outside
          // themselves. No side here: an outlined icon button keeps the
          // outline of its own variant.
          shape: MmFocusRingBorder.whenFocused(
            const StadiumBorder(),
            color: colors.focus,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        // State layers in the colour of the icon, which shows on the fill.
        focusColor: colors.onPrimary.withValues(alpha: 0.1),
        hoverColor: colors.onPrimary.withValues(alpha: 0.08),
        splashColor: colors.onPrimary.withValues(alpha: 0.1),
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 3,
        shape: MmFocusRingBorder.whenFocused(
          RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(MmRadius.md)),
            side: BorderSide(color: colors.primary),
          ),
          color: colors.focus,
        ),
        extendedTextStyle: text.labelLarge,
      ),
      segmentedButtonTheme: _segmentedButtonTheme(colors, text, focusSide),
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
        // Muted ink rather than the field outline: a chip's border runs as
        // close to its label as the label's own strokes, and the thin
        // strokes of Nastaliq must not read fainter than the frame around
        // them. Selected chips are framed in cobalt.
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: colors.rule);
          }
          if (states.contains(WidgetState.focused)) return focusSide;
          return BorderSide(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.inkMuted,
          );
        }),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MmRadius.xs)),
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MmSpace.s2),
        // Room above and below the label for the tall strokes of Nastaliq;
        // the avatar and check mark keep an icon's size however tall the
        // label is.
        labelPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s2,
          vertical: MmSpace.s1,
        ),
        avatarBoxConstraints: const BoxConstraints.tightFor(
          width: MmSize.iconMd,
          height: MmSize.iconMd,
        ),
        checkmarkColor: colors.onPrimaryContainer,
      ),
      // Counts are set like amounts: the Latin face with tabular figures, in
      // both languages (a Nastaliq line would make the badge taller than
      // the icon it sits on).
      badgeTheme: BadgeThemeData(
        backgroundColor: colors.overdue,
        textColor: scheme.onError,
        textStyle: MmTypeScale.latinCaption.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.inkMuted,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: colors.primary,
            width: MmSize.tabIndicator,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MmSize.tabIndicator),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colors.rule,
        dividerHeight: MmSize.hairline,
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
    // sets it in Atkinson instead of Nastaliq's serif Latin. Styles in the
    // Latin face (all of English, and Urdu amounts) fall back to Nastaliq
    // for Arabic-script letters, such as a name typed in Urdu.
    TextStyle style(TextStyle latin, TextStyle nastaliq) {
      final chosen = (urdu ? nastaliq : latin).copyWith(color: colors.ink);
      return chosen.fontFamily == _latinFamily
          ? MmSemantics.withUrduFallback(chosen)
          : chosen;
    }

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

  /// The Latin face as mm_ui's text styles name it.
  static const _latinFamily = 'packages/mm_ui/${MmFontFamily.latin}';

  /// Segmented buttons as `MmSegmentedControl` draws them: paper segments,
  /// the selected one cobalt-tonal with a check, the field outline (a focus
  /// ring around the whole control while a segment has focus) and segments
  /// 48 dp tall at the standard text size.
  static SegmentedButtonThemeData _segmentedButtonTheme(
    MmColorTokens colors,
    TextTheme text,
    BorderSide focusSide,
  ) {
    WidgetStateProperty<Color> byState({
      required Color selected,
      required Color resting,
      required Color disabledSelected,
      required Color disabled,
    }) => WidgetStateProperty.resolveWith((states) {
      final isSelected = states.contains(WidgetState.selected);
      if (states.contains(WidgetState.disabled)) {
        return isSelected ? disabledSelected : disabled;
      }
      return isSelected ? selected : resting;
    });
    final ink = byState(
      selected: colors.onPrimaryContainer,
      resting: colors.ink,
      disabledSelected: colors.inkMuted,
      disabled: colors.inkMuted,
    );
    // Material sizes a segment by its padding around one line of the label,
    // so the padding makes up the rest of the button height.
    final label = text.labelLarge!;
    final line = label.fontSize! * label.height!;
    final vertical = ((MmSize.buttonHeight - line) / 2).ceilToDouble();
    return SegmentedButtonThemeData(
      selectedIcon: const Icon(MmIcons.check),
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(label),
        backgroundColor: byState(
          selected: colors.primaryContainer,
          resting: colors.surface,
          disabledSelected: colors.surfaceSunken,
          disabled: colors.surface,
        ),
        foregroundColor: ink,
        iconColor: ink,
        iconSize: const WidgetStatePropertyAll(MmSize.iconMd),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: colors.rule);
          }
          if (states.contains(WidgetState.focused)) return focusSide;
          return BorderSide(color: colors.outline);
        }),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(MmRadius.sm)),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsetsDirectional.symmetric(
            horizontal: MmSpace.s3,
            vertical: vertical,
          ),
        ),
        // The segments are 48 dp targets themselves.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
