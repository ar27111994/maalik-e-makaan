import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/components/display/mm_surface.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One row of a list: a tenant, a property, a payment.
///
/// A [title] (wrapped, never truncated), an optional [subtitle] in muted ink
/// that ends with an ellipsis after [subtitleMaxLines] lines (or runs as
/// long as it needs when that is null), an optional [leading] widget (an
/// `MmAvatar` or an icon), an optional [trailing] widget (an `MmAmount` or
/// an `MmStatusBadge`) and, for a row that opens another screen, an
/// optional [chevron]. The title and subtitle are the landlord's data
/// unless [userData] is false: in the Urdu UI a name typed in English is
/// set in the Latin face, and in the English UI a name typed in Urdu in
/// the Urdu face; each keeps its own direction, so an Urdu address in the
/// English UI keeps its word order when it wraps. In the Urdu UI the
/// subtitle keeps 4 dp from the title, so the dots and marks of Urdu
/// letters on the two lines stay apart.
///
/// When the trailing widget and the title do not fit side by side (a narrow
/// screen or large text), the trailing widget moves under the text, still at
/// the end edge where a list keeps its amounts, instead of squeezing the
/// title. The [chevron] never moves: it stays at the end edge beside the
/// text. The leading widget and the chevron are centred on a row of one or
/// two lines, and line up with the title's first line on a taller one. The
/// row is at least 56 dp tall and is one node for screen readers, reading
/// the title, subtitle and trailing widget together (the chevron is not
/// read: the row is already announced as a button).
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
    this.chevron = false,
    this.userData = true,
    super.key,
  }) : assert(
         !chevron || onTap != null,
         'A chevron says the row opens something: give it an onTap.',
       ),
       assert(
         subtitleMaxLines == null || subtitleMaxLines > 0,
         'subtitleMaxLines must be > 0, or null for no limit.',
       );

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

  /// The most lines the subtitle takes before it ends with an ellipsis, or
  /// null for as many as it needs (a member's role and email address).
  final int? subtitleMaxLines;

  /// Whether the row shows a chevron at its end edge: it opens another
  /// screen or a sheet about the row. Unlike [trailing], the chevron stays
  /// beside the text however long the title is. Needs [onTap].
  final bool chevron;

  /// Whether [title] and [subtitle] are the landlord's data (a name, an
  /// address), set in their own script's face and kept in their own
  /// direction. Pass false for words from the app's localisations ("PDF
  /// رسیدیں"), which run in the UI's direction whatever their first letter.
  final bool userData;

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

    final maxLines = subtitleMaxLines;
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final body = MmReflow(
      start: userData
          ? MmUserText(title, style: titleStyle)
          : MmScriptText(title, style: titleStyle),
      below: subtitle == null
          ? null
          : Padding(
              // The dots and marks of Urdu letters reach a little past
              // their lines: in Urdu the two lines keep apart.
              padding: EdgeInsetsDirectional.only(
                top: context.mm.script == MmScript.urdu ? MmSpace.s1 : 0,
              ),
              child: _OneLineShrinks(
                // A subtitle of one line ends with an ellipsis at any width,
                // so it never keeps the trailing widget off the title's
                // line; one of more lines wraps between its words, and a
                // word too long to sit beside the trailing widget sends
                // that widget under the text.
                shrinks: maxLines == 1,
                child: userData
                    ? MmUserText(
                        subtitle,
                        style: subtitleStyle,
                        maxLines: maxLines,
                        overflow: overflow,
                      )
                    : MmScriptText(
                        subtitle,
                        style: subtitleStyle,
                        maxLines: maxLines,
                        overflow: overflow,
                      ),
              ),
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
                chevron: chevron
                    ? IconTheme.merge(
                        data: IconThemeData(color: muted, size: iconSize),
                        // The row is the button: its chevron is not read.
                        child: const ExcludeSemantics(
                          child: Icon(MmIcons.chevronEnd),
                        ),
                      )
                    : null,
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

/// Reports no narrowest width for its child when [shrinks]: a line that
/// ends with an ellipsis can be cut at any width.
class _OneLineShrinks extends SingleChildRenderObjectWidget {
  const new({required this.shrinks, required super.child});

  final bool shrinks;

  @override
  _RenderOneLineShrinks createRenderObject(BuildContext context) =>
      _RenderOneLineShrinks(shrinks: shrinks);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOneLineShrinks renderObject,
  ) => renderObject.shrinks = shrinks;
}

class _RenderOneLineShrinks extends RenderProxyBox {
  new({required this._shrinks});

  bool get shrinks => _shrinks;
  bool _shrinks;
  set shrinks(bool value) {
    if (value == _shrinks) return;
    _shrinks = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      shrinks ? 0 : super.computeMinIntrinsicWidth(height);
}

/// The places [_TileLayout] lays its children out in.
enum _TileSlot { leading, body, chevron }

/// A list row's leading widget, its text and its chevron, side by side.
///
/// The leading widget and the chevron are centred on text of up to two
/// lines; beside taller text (a long title at large text sizes) they line
/// up with the first line of the title, so they stay beside the name rather
/// than drifting to the middle of a paragraph.
class _TileLayout
    extends SlottedMultiChildRenderObjectWidget<_TileSlot, RenderBox> {
  const new({
    required this.leading,
    required this.body,
    required this.chevron,
    required this.firstLine,
  });

  final Widget? leading;

  final Widget body;

  final Widget? chevron;

  /// The height of the title's first line.
  final double firstLine;

  @override
  Iterable<_TileSlot> get slots => _TileSlot.values;

  @override
  Widget? childForSlot(_TileSlot slot) => switch (slot) {
    _TileSlot.leading => leading,
    _TileSlot.body => body,
    _TileSlot.chevron => chevron,
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
  Offset chevron,
  BoxConstraints bodyConstraints,
});

class _RenderTileLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_TileSlot, RenderBox> {
  new({required this._firstLine, required this._textDirection});

  /// The space between the leading widget and the text.
  static const double _spacing = MmSpace.s4;

  /// The space between the text and the chevron, whose glyph has room of
  /// its own at its sides.
  static const double _chevronSpacing = MmSpace.s2;

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
  RenderBox? get _chevron => childForSlot(_TileSlot.chevron);

  /// The children in reading order, which is also the order they are
  /// painted, hit-tested and read out in.
  @override
  Iterable<RenderBox> get children => [
    for (final slot in _TileSlot.values) ?childForSlot(slot),
  ];

  double get _indent => _leading == null ? 0 : _spacing;

  double get _chevronGap => _chevron == null ? 0 : _chevronSpacing;

  _TileArrangement _arrange(BoxConstraints constraints, {required bool dry}) {
    final layoutChild = dry
        ? ChildLayoutHelper.dryLayoutChild
        : ChildLayoutHelper.layoutChild;
    final leading = _leading;
    final chevron = _chevron;
    final loose = BoxConstraints.loose(constraints.biggest);
    final leadingSize = leading == null
        ? Size.zero
        : layoutChild(leading, loose);
    final chevronSize = chevron == null
        ? Size.zero
        : layoutChild(chevron, loose);
    final indent = leadingSize.width + _indent;
    final outdent = chevronSize.width + _chevronGap;
    final bodyConstraints = BoxConstraints(
      maxWidth: math.max(0, constraints.maxWidth - indent - outdent),
    );
    final bodySize = layoutChild(_body, bodyConstraints);

    final tall = bodySize.height > 2 * firstLine;
    final centre = tall ? firstLine / 2 : bodySize.height / 2;
    final leadingTop = centre - leadingSize.height / 2;
    final chevronTop = centre - chevronSize.height / 2;
    // A leading widget or chevron taller than the text's middle allows
    // pushes the text down instead of sticking out above it.
    final double bodyTop = math.max(0, -math.min(leadingTop, chevronTop));
    final contentHeight = [
      bodyTop + bodySize.height,
      bodyTop + leadingTop + leadingSize.height,
      bodyTop + chevronTop + chevronSize.height,
    ].reduce(math.max);
    final width = constraints.constrainWidth(
      constraints.hasBoundedWidth
          ? constraints.maxWidth
          : indent + bodySize.width + outdent,
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
      chevron: Offset(
        rtl ? 0 : width - chevronSize.width,
        top + bodyTop + chevronTop,
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
    final chevron = _chevron;
    if (chevron != null) {
      (chevron.parentData! as BoxParentData).offset = arrangement.chevron;
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
    final chevron = _chevron;
    return (leading == null ? 0 : widthOf(leading) + _indent) +
        widthOf(_body) +
        (chevron == null ? 0 : widthOf(chevron) + _chevronGap);
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
