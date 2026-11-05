import 'package:flutter/widgets.dart';

/// Tells a [State] whether keyboard focus should be drawn: only while the
/// user drives the app from a keyboard (Flutter's traditional focus
/// highlight mode), as Material does for its own focus highlights, so a
/// tap never leaves a ring behind on a phone.
///
/// A component that draws its own focus ring (a tile, a card, a field-like
/// box) mixes this into its state and draws the ring only while
/// [showsFocusHighlights] is true and it has focus. Stock Material buttons,
/// chips and fields need nothing: the theme draws their rings.
///
/// Internal to mm_ui: any component family may use it.
mixin MmFocusHighlight<T extends StatefulWidget> on State<T> {
  late bool _keyboard;

  /// Whether focus is currently drawn: the last input came from a keyboard.
  bool get showsFocusHighlights => _keyboard;

  @override
  void initState() {
    super.initState();
    _keyboard = _isKeyboard(FocusManager.instance.highlightMode);
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    final keyboard = _isKeyboard(mode);
    if (keyboard != _keyboard) setState(() => _keyboard = keyboard);
  }

  static bool _isKeyboard(FocusHighlightMode mode) =>
      mode == FocusHighlightMode.traditional;
}
