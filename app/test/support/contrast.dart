// Copied from packages/mm_ui/test/support/contrast.dart (the design system's
// deterministic text-contrast guideline), so the app's screens are checked
// the same way as its components. Keep the two in step.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text at least this big (in logical pixels, before the user's text
/// scaling) is large text: WCAG's 18 point.
const double mmLargeTextSize = 24;

/// Bold text (weight 700 or more) at least this big is large text: WCAG's
/// 14 point.
const double mmLargeBoldTextSize = 56 / 3;

/// The contrast WCAG 2.2 AA asks of normal text (success criterion 1.4.3).
const double mmMinimumTextContrast = 4.5;

/// The contrast WCAG 2.2 AA asks of large text.
const double mmMinimumLargeTextContrast = 3;

/// The contrast WCAG 2.2 AA asks of icons and other graphics (success
/// criterion 1.4.11).
const double mmMinimumIconContrast = 3;

/// The WCAG contrast ratio of two opaque colours, from 1 to 21.
double mmContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// One run of text on screen and the colours it is drawn in.
final class MmTextContrast {
  /// Records [text], drawn in [color] on [background].
  const new({
    required this.text,
    required this.color,
    required this.background,
    required this.fontSize,
    required this.fontWeight,
    required this.rect,
  });

  /// The text of the run.
  final String text;

  /// The colour the text appears in: its own colour, with its alpha and the
  /// opacity of everything above it, over [background].
  final Color color;

  /// The colour behind the text, as painted on screen.
  final Color background;

  /// The font size the text asks for, before the user's text scaling: WCAG
  /// measures large text at the size the author set.
  final double fontSize;

  /// The weight of the text.
  final FontWeight fontWeight;

  /// Where the text's paragraph is on screen, in logical pixels.
  final Rect rect;

  /// Whether WCAG counts the text as large, which needs only 3:1.
  bool get isLarge =>
      fontSize >= mmLargeTextSize ||
      (fontWeight.value >= FontWeight.w700.value &&
          fontSize >= mmLargeBoldTextSize);

  /// Whether the run is an icon: glyphs of an icon font, whose code points
  /// are all in a Unicode private use area (as every `MmIcons` and Material
  /// icon is). WCAG holds icons to the 3:1 of graphics, not to text's 4.5:1.
  bool get isIcon => text.runes.every(_isPrivateUse);

  /// The contrast the run needs.
  double get minimum => isIcon
      ? mmMinimumIconContrast
      : isLarge
      ? mmMinimumLargeTextContrast
      : mmMinimumTextContrast;

  /// The contrast the text has.
  double get ratio => mmContrastRatio(color, background);

  /// Whether the text has the contrast it needs (to a hundredth, as
  /// Flutter's own guideline allows).
  bool get passes => ratio >= minimum - 0.01;

  @override
  String toString() {
    final what = isIcon
        ? 'Icon U+${text.runes.first.toRadixString(16).toUpperCase()}'
        : '"$text"';
    return '$what (${fontSize.toStringAsFixed(1)} px, w${fontWeight.value}) at '
        '$rect: ${_hex(color)} on ${_hex(background)} is '
        '${ratio.toStringAsFixed(2)}:1, needs $minimum:1';
  }
}

/// Whether [rune] is in one of Unicode's private use areas, where icon fonts
/// put their glyphs.
bool _isPrivateUse(int rune) =>
    (rune >= 0xE000 && rune <= 0xF8FF) ||
    (rune >= 0xF0000 && rune <= 0xFFFFD) ||
    (rune >= 0x100000 && rune <= 0x10FFFD);

/// The WCAG 2.2 AA text contrast check (success criterion 1.4.3), made
/// deterministic.
///
/// Flutter's `textContrastGuideline` guesses both colours of a label from
/// the pixels around it: the lightest and darkest of its most frequent
/// colours. At one device pixel per logical pixel, thin strokes (12 to 14 px
/// regular text, Nastaliq hairlines) have few solid pixels, so it often
/// takes an anti-aliased grey for the text colour, and the result depends on
/// the wording and the sub-pixel position: muted helper text with a real
/// contrast of 6:1 measures 1.4:1. It also checks only text whose semantics
/// label equals one `Text`, so merged tiles and text excluded from
/// semantics go unchecked.
///
/// This guideline checks every run of text on screen (every [RenderParagraph]
/// and [RenderEditable], and each styled span in them) that is painted, not
/// covered by something on top (a modal barrier, a snack bar) and not part of
/// a disabled control (WCAG exempts inactive components). Text whose colour
/// stands out from the background behind it (1.5:1 or more) but leaves no
/// trace in the frame is not on screen, and is left out too. It takes the text
/// colour from the render tree: the span's colour with its alpha, times the
/// opacity of every [RenderOpacity] and animated opacity above it. It finds
/// the background in the rendered frame: of the colours that fill a
/// noticeable share of the paragraph's visible box, the one the text's
/// anti-aliased edge pixels blend into. That is the colour actually behind
/// the glyphs (a card, a chip's fill, an ink decoration, a focus overlay),
/// and it does not depend on how the strokes fall on the pixel grid.
///
/// Text is large (3:1 instead of 4.5:1) from [mmLargeTextSize], or
/// [mmLargeBoldTextSize] when bold, at the size the style sets: the user's
/// text scaling does not lower the bar. An `Icon` is a paragraph too; its
/// glyph is held to the 3:1 WCAG asks of graphics (1.4.11), except in a
/// disabled control.
///
/// Text painted by a [CustomPainter] is not a paragraph and is not checked;
/// nor is text drawn with a shader.
class MmTextContrastGuideline extends AccessibilityGuideline {
  /// The guideline; use [mmTextContrastGuideline].
  const new();

  @override
  String get description =>
      'Text contrast should meet WCAG 2.2 AA: 4.5:1, or 3:1 for large text';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final run in await measureTextContrast(tester)) {
      if (!run.passes) result += Evaluation.fail('$run');
    }
    return result;
  }
}

/// The deterministic text contrast check of the harness.
const mmTextContrastGuideline = MmTextContrastGuideline();

/// Measures every run of text [MmTextContrastGuideline] checks, in tree
/// order, in every view of [tester].
Future<List<MmTextContrast>> measureTextContrast(WidgetTester tester) async {
  final runs = <MmTextContrast>[];
  for (final view in tester.binding.renderViews) {
    final frame = await _Frame.capture(tester, view);
    void visit(RenderObject object) {
      if (object is RenderParagraph || object is RenderEditable) {
        runs.addAll(_measure(tester, view, frame, object as RenderBox));
      }
      object.visitChildren(visit);
    }

    view.visitChildren(visit);
  }
  return runs;
}

/// The runs of [box] (a paragraph or an editable), or none when it is not
/// checked.
List<MmTextContrast> _measure(
  WidgetTester tester,
  RenderView view,
  _Frame frame,
  RenderBox box,
) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return const [];
  final spans = _spansOf(box);
  if (spans.isEmpty) return const [];

  // Painted at all, how opaque, and where it can be seen.
  var opacity = 1.0;
  var visible = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  RenderObject child = box;
  for (var parent = box.parent; parent != null; parent = parent.parent) {
    if (!parent.paintsChild(child)) return const [];
    opacity *= switch (parent) {
      RenderOpacity(opacity: final value) => value,
      RenderSliverOpacity(opacity: final value) => value,
      RenderAnimatedOpacityMixin<RenderObject>(opacity: final value) =>
        value.value,
      _ => 1.0,
    };
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      visible = visible.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
    child = parent;
  }
  visible = visible.intersect(Offset.zero & frame.size);
  if (opacity <= 0 || visible.width < 1 || visible.height < 1) {
    return const [];
  }
  if (_isCovered(tester, view, box, visible.center)) return const [];
  if (_isDisabled(box)) return const [];

  final (background, :blended) = frame.backgroundBehind(visible, [
    for (final (_, style) in spans) _colorOf(style),
  ]);
  final runs = [
    for (final (text, style) in spans)
      MmTextContrast(
        text: text,
        color: _over(_colorOf(style), opacity, background),
        background: background,
        fontSize: style.fontSize ?? 14,
        fontWeight: _weightOf(style),
        rect: visible,
      ),
  ];
  // Painted text that stands out from its background leaves edge pixels
  // that blend the two. When there are none, the text is not on screen
  // (hidden by a widget that skips painting it, or under something opaque),
  // and only runs too close to the background to leave a trace are kept:
  // those fail, as they should.
  if (blended == 0) {
    return [
      for (final run in runs)
        if (run.ratio < _visibleRatio) run,
    ];
  }
  return runs;
}

/// Below this contrast, text may leave no pixel that differs from its
/// background; above it, painted text always does.
const double _visibleRatio = 1.5;

/// The non-blank runs of text of [box] with their effective styles,
/// leaving out runs drawn with a shader.
List<(String, TextStyle)> _spansOf(RenderBox box) {
  final root = switch (box) {
    RenderParagraph(:final text) => text,
    RenderEditable(:final text) => text,
    _ => null,
  };
  final spans = <(String, TextStyle)>[];
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is TextSpan) {
      final text = span.text;
      if (text != null &&
          text.trim().isNotEmpty &&
          style.foreground?.shader == null) {
        spans.add((text, style));
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  if (root != null) visit(root, const TextStyle());
  return spans;
}

/// The colour [style] paints text in; the engine's default is black.
Color _colorOf(TextStyle style) =>
    style.foreground?.color ?? style.color ?? const Color(0xFF000000);

/// The weight [style] draws text at, from a `wght` variation if it has one.
FontWeight _weightOf(TextStyle style) {
  for (final variation in style.fontVariations ?? const <FontVariation>[]) {
    if (variation.axis == 'wght') {
      return FontWeight.values.reduce(
        (a, b) =>
            (a.value - variation.value).abs() <=
                (b.value - variation.value).abs()
            ? a
            : b,
      );
    }
  }
  return style.fontWeight ?? FontWeight.w400;
}

/// Whether something on top of [box] at [point] paints over it: a modal
/// barrier, a snack bar, a tooltip or a sheet.
///
/// The hit test at [point] lists what is there from the top down. Until it
/// reaches [box] or one of [box]'s ancestors, every entry is something in
/// another branch drawn over [box]'s place. Text, an editable field (a
/// field's input over its hint) and pass-through boxes leave the text
/// visible; anything that fills an area covers it.
bool _isCovered(
  WidgetTester tester,
  RenderView view,
  RenderBox box,
  Offset point,
) {
  final ancestors = <RenderObject>{
    for (var parent = box.parent; parent != null; parent = parent.parent)
      parent,
  };
  final path = tester
      .hitTestOnBinding(point, viewId: view.flutterView.viewId)
      .path;
  for (final entry in path) {
    final target = entry.target;
    if (identical(target, box) || ancestors.contains(target)) return false;
    if (target is RenderObject && _paintsFill(target)) return true;
  }
  return false;
}

/// Whether [object] fills its area with paint, hiding what is under it.
bool _paintsFill(RenderObject object) => switch (object) {
  RenderDecoratedBox(:final decoration) => switch (decoration) {
    BoxDecoration(:final color, :final gradient, :final image) ||
    ShapeDecoration(
      :final color,
      :final gradient,
      :final image,
    ) => (color?.a ?? 0) > 0 || gradient != null || image != null,
    _ => true,
  },
  RenderPhysicalModel(:final color) ||
  RenderPhysicalShape(:final color) => color.a > 0,
  RenderCustomPaint(:final painter, :final foregroundPainter) =>
    painter != null || foregroundPainter != null,
  RenderImage() => true,
  _ => switch (object.debugCreator) {
    DebugCreator(element: Element(widget: ColoredBox(:final color))) =>
      color.a > 0,
    _ => false,
  },
};

/// Whether [box] is part of a control that semantics marks disabled: the
/// semantics node its text is read in (its own, or the node it is merged
/// into) has the enabled flag set to false.
bool _isDisabled(RenderObject box) {
  RenderObject? owner = box;
  while (owner != null && owner.debugSemantics == null) {
    owner = owner.parent;
  }
  var node = owner?.debugSemantics;
  while (node != null && node.isMergedIntoParent) {
    node = node.parent;
  }
  return node?.getSemanticsData().flagsCollection.isEnabled ==
      ui.Tristate.isFalse;
}

/// [color] with its alpha scaled by [opacity], over the opaque [background].
Color _over(Color color, double opacity, Color background) {
  final a = color.a * opacity;
  double mix(double top, double bottom) => top * a + bottom * (1 - a);
  return Color.from(
    alpha: 1,
    red: mix(color.r, background.r),
    green: mix(color.g, background.g),
    blue: mix(color.b, background.b),
  );
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A rendered frame of a view, at one pixel per logical pixel.
final class _Frame {
  const new _(this._pixels, this.size);

  /// Renders [view]'s layer tree, as Flutter's own contrast guideline does.
  static Future<_Frame> capture(WidgetTester tester, RenderView view) async {
    final layer = view.debugLayer! as OffsetLayer;
    final frame = await tester.binding.runAsync(() async {
      final image = await layer.toImage(
        view.paintBounds,
        pixelRatio: 1 / view.flutterView.devicePixelRatio,
      );
      try {
        final bytes = await image.toByteData();
        return _Frame._(
          bytes!,
          Size(image.width.toDouble(), image.height.toDouble()),
        );
      } finally {
        image.dispose();
      }
    });
    return frame!;
  }

  /// Premultiplied RGBA bytes, row by row: an opaque colour as is, a
  /// translucent one over black, as a window with nothing behind it shows.
  final ByteData _pixels;

  /// The frame's size in pixels.
  final Size size;

  /// The colour behind text drawn in [inks] inside [rect], and how many
  /// pixels of [rect] blend an ink with it.
  ///
  /// Every edge pixel of a glyph is the ink blended with the background
  /// behind it, so it lies on the straight line between the two colours. Of
  /// the colours that each fill at least 3% of [rect], the background is
  /// the one whose line to an ink holds the most other pixels. When no
  /// pixel blends (the text is the colour of what is behind it, or is not
  /// painted), it is the most frequent colour.
  (Color, {int blended}) backgroundBehind(Rect rect, List<Color> inks) {
    final width = size.width.toInt();
    final histogram = <int, int>{};
    // The whole pixels inside [rect]: a pixel the edge cuts blends what is
    // inside with what is outside, which is no glyph's edge.
    var (left, top) = (rect.left.ceil(), rect.top.ceil());
    var (right, bottom) = (rect.right.floor(), rect.bottom.floor());
    if (right <= left) (left, right) = (rect.left.floor(), rect.right.ceil());
    if (bottom <= top) (top, bottom) = (rect.top.floor(), rect.bottom.ceil());
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        final rgb =
            _pixels.getUint8(offset) << 16 |
            _pixels.getUint8(offset + 1) << 8 |
            _pixels.getUint8(offset + 2);
        histogram[rgb] = (histogram[rgb] ?? 0) + 1;
      }
    }
    final total = histogram.values.fold(0, (sum, count) => sum + count);
    final byCount = histogram.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final threshold = math.max(2, total * 0.03);
    final candidates = [
      for (final entry in byCount.take(8))
        if (entry.value >= threshold) entry.key,
    ];
    final inkRgbs = {for (final ink in inks) ink.toARGB32() & 0xFFFFFF};

    var background = byCount.first.key;
    var mostBlended = 0;
    for (final candidate in candidates) {
      var blended = 0;
      for (final MapEntry(key: pixel, value: count) in histogram.entries) {
        if (pixel == candidate) continue;
        if (inkRgbs.any((ink) => _between(pixel, ink, candidate))) {
          blended += count;
        }
      }
      if (blended > mostBlended) {
        mostBlended = blended;
        background = candidate;
      }
    }
    return (Color(0xFF000000 | background), blended: mostBlended);
  }
}

/// Whether the colour [pixel] lies on the line from [ink] to [background]
/// in RGB space, to within rounding: a blend of the two.
bool _between(int pixel, int ink, int background) {
  final p = _channels(pixel);
  final i = _channels(ink);
  final b = _channels(background);
  final d = [for (var c = 0; c < 3; c++) b[c] - i[c]];
  final length = d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
  if (length == 0) return false;
  final t =
      ((p[0] - i[0]) * d[0] + (p[1] - i[1]) * d[1] + (p[2] - i[2]) * d[2]) /
      length;
  if (t < -0.02 || t > 1.02) return false;
  var distance = 0.0;
  for (var c = 0; c < 3; c++) {
    final off = p[c] - (i[c] + t * d[c]);
    distance += off * off;
  }
  return distance <= 3 * 3;
}

List<int> _channels(int rgb) => [rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF];
