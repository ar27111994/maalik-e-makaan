import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One row of a list: a tenant, a property, a payment.
///
/// A [title] (wrapped, never truncated), an optional [subtitle] in muted ink
/// that ends with an ellipsis after [subtitleMaxLines] lines, an optional
/// [leading] widget (an `MmAvatar` or an icon) and an optional [trailing]
/// widget (an `MmAmount` or an `MmStatusBadge`). The title and subtitle are
/// the landlord's data: in the Urdu UI a name typed in English is set in the
/// Latin face, and in the English UI a name typed in Urdu in Nastaliq; each
/// keeps its own direction, so an Urdu address in the English UI keeps its
/// word order when it wraps.
///
/// When the trailing widget and the title do not fit side by side (a narrow
/// screen or large text), the trailing widget moves under the text, still at
/// the end edge where a list keeps its amounts, instead of squeezing the
/// title. The leading widget is centred on a row of one or two lines, and
/// lines up with the title's first line on a taller one. The row is at least
/// 56 dp tall and is one node for screen readers, reading the title,
/// subtitle and trailing widget together.
///
/// With [onTap] the row is a button: it shows ink when pressed, a focus ring
/// while it has keyboard focus and activates with Enter or Space. [selected]
/// tints it (in list-and-detail layouts) and sets the title in a heavier
/// weight, so the selection does not rely on colour alone.
///
/// The trailing widget shows information, not a control: a tappable row is
/// one button and reports a control inside it in debug builds, and a static
/// row is read as one node, so a button in it would be read as the whole
/// row. Put a row's own actions on the screen it opens.
///
/// Group rows inside an `MmCard` with zero padding, separated by dividers.
/// Don't use it for a label and value pair on a receipt (use
/// `MmDetailRow`) or for a setting with a switch (use `MmSwitchTile`).
///
/// ```dart
/// MmListTile(
///   leading: MmAvatar(name: tenant.name),
///   title: tenant.name,
///   subtitle: tenant.unitName,
///   trailing: MmAmount(amount: tenant.balance),
///   onTap: () => openTenant(tenant),
/// )
/// ```
class MmListTile extends StatelessWidget {
  /// Creates a list row titled [title].
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.subtitleMaxLines = 2,
    super.key,
  });

  /// The main line ("Ali Raza"). It wraps and is never truncated.
  final String title;

  /// A secondary line under the title ("Flat 3, Gulberg III, Lahore").
  final String? subtitle;

  /// A widget before the text, such as an `MmAvatar` or an [Icon]. Icons
  /// take the muted ink colour and the 24 dp size, growing with the text
  /// up to one and a half times, unless they set their own.
  final Widget? leading;

  /// A widget at the end edge, such as an `MmAmount` or an `MmStatusBadge`.
  /// It moves under the text when it does not fit beside the title.
  final Widget? trailing;

  /// Called when the row is tapped or activated from the keyboard. When
  /// null the row only shows information: not a button and not focusable.
  final VoidCallback? onTap;

  /// Whether this row is the one shown in the detail pane.
  final bool selected;

  /// The most lines the subtitle takes before it ends with an ellipsis.
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final ink = selected ? colors.onPrimaryContainer : colors.ink;
    final muted = selected ? colors.onPrimaryContainer : colors.inkMuted;
    // An icon in either slot that sets no size of its own grows with the
    // text, as icons beside words do, up to one and a half times.
    final iconSize = MmIconLabel.scaledSize(context, MmSize.iconLg);
    final titleStyle = text.bodyLarge!.copyWith(
      color: ink,
      fontWeight: selected ? FontWeight.w600 : null,
    );
    final subtitleStyle = text.bodyMedium!.copyWith(color: muted);
    final subtitle = this.subtitle;
    final leading = this.leading;
    final trailing = this.trailing;
    final titleSize = titleStyle.fontSize!;

    final body = MmReflow(
      start: MmUserText(title, style: titleStyle),
      below: subtitle == null
          ? null
          : MmUserText(
              subtitle,
              style: subtitleStyle,
              maxLines: subtitleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
      end: trailing == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: muted, size: iconSize),
              child: DefaultTextStyle(style: subtitleStyle, child: trailing),
            ),
      stackedAtEnd: true,
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        selected: selected ? true : null,
        child: MmSurface(
          owner: 'MmListTile',
          onTap: onTap,
          outlined: false,
          color: selected ? colors.primaryContainer : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MmSize.listRow),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MmSpace.s4,
                vertical: MmSpace.s3,
              ),
              child: _TileLayout(
                leading: leading == null
                    ? null
                    : IconTheme.merge(
                        data: IconThemeData(color: muted, size: iconSize),
                        child: leading,
                      ),
                body: body,
                firstLine:
                    MediaQuery.textScalerOf(context).scale(titleSize) *
                    (titleStyle.height ?? 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The places [_TileLayout] lays its children out in.
enum _TileSlot { leading, body }

/// A list row's leading widget and its text, side by side.
///
/// The leading widget is centred on text of up to two lines; beside taller
/// text (a long title at large text sizes) it lines up with the first line
/// of the title, so it stays beside the name rather than drifting to the
/// middle of a paragraph.
class _TileLayout
    extends SlottedMultiChildRenderObjectWidget<_TileSlot, RenderBox> {
  const new({
    required this.leading,
    required this.body,
    required this.firstLine,
  });

  final Widget? leading;

  final Widget body;

  /// The height of the title's first line.
  final double firstLine;

  @override
  Iterable<_TileSlot> get slots => _TileSlot.values;

  @override
  Widget? childForSlot(_TileSlot slot) => switch (slot) {
    _TileSlot.leading => leading,
    _TileSlot.body => body,
  };

  @override
  _RenderTileLayout createRenderObject(BuildContext context) =>
      _RenderTileLayout(
        firstLine: firstLine,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTileLayout renderObject,
  ) {
    renderObject
      ..firstLine = firstLine
      ..textDirection = Directionality.of(context);
  }
}

/// Where [_RenderTileLayout] places its children for some constraints.
typedef _TileArrangement = ({
  Size size,
  Offset leading,
  Offset body,
  BoxConstraints bodyConstraints,
});

class _RenderTileLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_TileSlot, RenderBox> {
  new({required this._firstLine, required this._textDirection});

  /// The space between the leading widget and the text.
  static const double _spacing = MmSpace.s4;

  double get firstLine => _firstLine;
  double _firstLine;
  set firstLine(double value) {
    if (value == _firstLine) return;
    _firstLine = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_TileSlot.leading);
  RenderBox get _body => childForSlot(_TileSlot.body)!;

  /// The children in reading order, which is also the order they are
  /// painted, hit-tested and read out in.
  @override
  Iterable<RenderBox> get children => [
    for (final slot in _TileSlot.values) ?childForSlot(slot),
  ];

  double get _indent => _leading == null ? 0 : _spacing;

  _TileArrangement _arrange(BoxConstraints constraints, {required bool dry}) {
    final layoutChild = dry
        ? ChildLayoutHelper.dryLayoutChild
        : ChildLayoutHelper.layoutChild;
    final leading = _leading;
    final leadingSize = leading == null
        ? Size.zero
        : layoutChild(leading, BoxConstraints.loose(constraints.biggest));
    final indent = leadingSize.width + _indent;
    final bodyConstraints = BoxConstraints(
      maxWidth: math.max(0, constraints.maxWidth - indent),
    );
    final bodySize = layoutChild(_body, bodyConstraints);

    final tall = bodySize.height > 2 * firstLine;
    final leadingCentre = tall ? firstLine / 2 : bodySize.height / 2;
    final leadingTop = leadingCentre - leadingSize.height / 2;
    // A leading widget taller than the text's middle allows pushes the
    // text down instead of sticking out above it.
    final double bodyTop = math.max(0, -leadingTop);
    final contentHeight = math.max(
      bodyTop + bodySize.height,
      bodyTop + leadingTop + leadingSize.height,
    );
    final width = constraints.constrainWidth(
      constraints.hasBoundedWidth
          ? constraints.maxWidth
          : indent + bodySize.width,
    );
    final height = constraints.constrainHeight(contentHeight);
    // Content shorter than the row's least height sits in its middle.
    final top = (height - contentHeight) / 2;
    final rtl = textDirection == TextDirection.rtl;
    return (
      size: Size(width, height),
      leading: Offset(
        rtl ? width - leadingSize.width : 0,
        top + bodyTop + leadingTop,
      ),
      body: Offset(
        rtl ? width - indent - bodySize.width : indent,
        top + bodyTop,
      ),
      bodyConstraints: bodyConstraints,
    );
  }

  @override
  void performLayout() {
    final arrangement = _arrange(constraints, dry: false);
    size = arrangement.size;
    final leading = _leading;
    if (leading != null) {
      (leading.parentData! as BoxParentData).offset = arrangement.leading;
    }
    (_body.parentData! as BoxParentData).offset = arrangement.body;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, dry: true).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final arrangement = _arrange(constraints, dry: true);
    return (BaselineOffset(
              _body.getDryBaseline(arrangement.bodyConstraints, baseline),
            ) +
            arrangement.body.dy)
        .offset;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final body = _body;
    final offset = (body.parentData! as BoxParentData).offset;
    return (BaselineOffset(body.getDistanceToActualBaseline(baseline)) +
            offset.dy)
        .offset;
  }

  double _width(double Function(RenderBox child) widthOf) {
    final leading = _leading;
    return (leading == null ? 0 : widthOf(leading) + _indent) + widthOf(_body);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _width((child) => child.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _width((child) => child.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, offset + parentData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
