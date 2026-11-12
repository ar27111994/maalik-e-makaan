import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One screen of the app: an app bar with the screen's title and actions,
/// the content in a readable column, and an optional bar of actions pinned
/// at the bottom.
///
/// The content is padded 16 dp from the window's sides (and from a display
/// cut-out or rounded corner there) and stops at `MmSize.contentMax`
/// (720 dp), centred, so lines stay readable on a tablet or a desktop
/// browser. By default it scrolls, with 16 dp above it and 16 dp below it
/// clear of the system's gesture bar, and with [onRefresh] it can be pulled
/// down to refresh. Pass `scrollable: false` when [body] scrolls by itself
/// or fills the screen (a `ListView`, tabs with their views): it then gets
/// the whole height, and keeps the bottom safe area to pad for itself, as
/// a `ListView` does.
///
/// The app bar's back button appears when the screen can go back, shows
/// the design system's back arrow and points the other way in Urdu. The
/// title grows with the text size like the rest of the screen and is never
/// cut: when it does not fit on one line beside the back button and the
/// actions (a long name, large text), it moves under them, onto as many
/// full-width lines as it needs. A title that is user data (a tenant's
/// name typed in English) keeps its own script's face in the Urdu UI. A
/// title that is the app's name standing alone ([wordmark]) is set as the
/// wordmark: مالکِ مکان in Nastaliq in the Urdu UI.
///
/// [bottomBar] (usually an `MmActionBar`) sits below
/// the content, never covering it; it pads itself for the device's safe
/// area and the on-screen keyboard. A [floatingActionButton] floats over
/// the content, so the page leaves room for it at the end: scrolled to the
/// end, the last content stops 16 dp above the button, however tall the
/// button grows with its label (a body that scrolls by itself gets that
/// room as bottom padding, which a `ListView` keeps clear by itself).
///
/// Use it for every screen inside the app's frame (`MmAdaptiveScaffold`)
/// and for screens pushed on top of it. Don't use it inside a sheet or a
/// dialog. Pulling to refresh needs a touch screen: give a screen with
/// [onRefresh] a refresh action in [actions] too, for keyboard and switch
/// users.
///
/// ```dart
/// MmPage(
///   title: 'Ayesha Khan',
///   actions: [
///     IconButton(
///       onPressed: editTenant,
///       tooltip: 'Edit tenant',
///       icon: const Icon(MmIcons.edit),
///     ),
///   ],
///   onRefresh: reloadTenant,
///   body: TenantSummary(tenant),
///   bottomBar: MmActionBar(
///     primary: FilledButton(
///       onPressed: recordPayment,
///       child: const Text('Record payment'),
///     ),
///   ),
/// )
/// ```
class MmPage extends StatefulWidget {
  /// Creates a screen titled [title] showing [body].
  const new({
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottomBar,
    this.floatingActionButton,
    this.onRefresh,
    this.scrollable = true,
    this.leading,
    this.wordmark = false,
    super.key,
  }) : assert(
         onRefresh == null || scrollable,
         'onRefresh needs a scrollable page; a body that scrolls by itself '
         'refreshes with its own RefreshIndicator',
       );

  /// The screen's title, shown in the app bar and read as its heading.
  final String title;

  /// The screen's content.
  final Widget body;

  /// Icon buttons (each with a tooltip) or text buttons at the end of the
  /// app bar, for actions on the whole screen.
  final List<Widget> actions;

  /// A bar pinned below the content, usually an `MmActionBar` holding the
  /// screen's main action. It pads itself for the safe area.
  final Widget? bottomBar;

  /// The screen's main action as a floating button (usually an `MmFab`),
  /// when it has no [bottomBar]. It floats at the end edge above the
  /// content's end, and the page leaves room for it there.
  final Widget? floatingActionButton;

  /// Called when the content is pulled down to refresh; the indicator spins
  /// until the returned future completes. Needs [scrollable].
  final Future<void> Function()? onRefresh;

  /// Whether the page scrolls [body]. Turn it off when [body] scrolls by
  /// itself or must fill the screen's height.
  final bool scrollable;

  /// The widget at the start of the app bar. When null, the app bar shows a
  /// back (or close) button whenever the screen can go back.
  final Widget? leading;

  /// Whether [title] is the app's name standing alone, as on a screen that
  /// shows nothing but the brand while it waits (signing in, loading the
  /// portfolios). A title in Urdu letters is then set in
  /// `MmSemantics.wordmark`: in the Urdu UI, Noto Nastaliq Urdu, the one
  /// place Nastaliq is used. A title in Latin letters keeps its own face.
  /// Leave it false for every other title, and for the name inside a
  /// longer title.
  final bool wordmark;

  @override
  State<MmPage> createState() => _MmPageState();
}

/// Where a title found too wide for the app bar's toolbar was laid out.
typedef _TitleLayout = ({String title, double width, double textScale});

class _MmPageState extends State<MmPage> {
  /// The layout in which the title, put beside the toolbar's buttons, was
  /// found wider than the room they left it (an action wider than an icon
  /// button), so it goes under them instead.
  _TitleLayout? _tooWide;

  /// The height of [MmPage.floatingActionButton] as last laid out; until
  /// then, the standard button's.
  double _fabHeight = MmSize.fab;

  /// How much of the content's end [MmPage.floatingActionButton] covers,
  /// with the page's gap above it: the button, the scaffold's margin under
  /// it and [MmSpace.s4]. Zero without a button.
  double get _fabRoom => widget.floatingActionButton == null
      ? 0
      : _fabHeight + kFloatingActionButtonMargin + MmSpace.s4;

  /// Keeps [_fabRoom] in step with the button's laid-out [height].
  void _fabLaidOut(double height) {
    if (mounted && height != _fabHeight) setState(() => _fabHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final outer = ActionIconTheme.of(context);
    return ActionIconTheme(
      data: ActionIconThemeData(
        backButtonIconBuilder:
            outer?.backButtonIconBuilder ??
            (context) => const Icon(MmIcons.back),
        closeButtonIconBuilder:
            outer?.closeButtonIconBuilder ??
            (context) => const Icon(MmIcons.close),
        drawerButtonIconBuilder: outer?.drawerButtonIconBuilder,
        endDrawerButtonIconBuilder: outer?.endDrawerButtonIconBuilder,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Scaffold(
          appBar: _appBar(context, constraints.maxWidth),
          body: Builder(
            builder: (context) =>
                widget.scrollable ? _scrolling(context) : _filling(context),
          ),
          bottomNavigationBar: widget.bottomBar,
          floatingActionButton: switch (widget.floatingActionButton) {
            final fab? => _MeasuredHeight(onHeight: _fabLaidOut, child: fab),
            null => null,
          },
        ),
      ),
    );
  }

  /// The app bar of a page [pageWidth] wide.
  ///
  /// The title is set at the ambient text scale (an app bar would cap it at
  /// 134%, below the body text at 200%), in its own script's face. It sits
  /// in the toolbar when it fits there on one line, else under the toolbar
  /// on full-width lines; with nothing else in the toolbar, it wraps in the
  /// toolbar itself. Either way the bar is measured to hold it.
  ///
  /// The title starts where the content column does: 16 dp in on a phone,
  /// and on a window wide enough to cap the column at `MmSize.contentMax`,
  /// at the centred column's start edge, so the title and the content share
  /// an edge however wide the window.
  PreferredSizeWidget _appBar(BuildContext context, double pageWidth) {
    final title = widget.title;
    final appBarTheme = AppBarTheme.of(context);
    final style = widget.wordmark && MmSemantics.hasArabicScript(title)
        ? context.mm.wordmark
        : context.mm.styleFor(
            title,
            appBarTheme.titleTextStyle ??
                Theme.of(context).textTheme.titleLarge!,
          );
    final scaler = MediaQuery.textScalerOf(context);
    final safeArea = MediaQuery.paddingOf(context);
    final width = pageWidth - safeArea.horizontal;
    final leads =
        widget.leading != null ||
        (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final leadingWidth = leads ? appBarTheme.leadingWidth ?? kToolbarHeight : 0;
    // Where the content column starts, from the toolbar's start edge: the
    // page's padding, and half of what the column's cap leaves over.
    final columnStart =
        MmSpace.s4 +
        math.max(0, (width - 2 * MmSpace.s4 - MmSize.contentMax) / 2);
    final spacing = math.max(
      appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing,
      columnStart - leadingWidth,
    );
    final actions = widget.actions;
    // Each action is taken for an icon button, a 48 dp target; a wider one
    // is found out when the title is laid out beside it (see
    // _ToolbarTitle).
    final besideTitle =
        leadingWidth +
        (actions.isEmpty ? 0 : actions.length * MmSize.minTarget + MmSpace.s1);
    final double toolbarRoom = math.max(0, width - besideTitle - 2 * spacing);
    final layout = (title: title, width: width, textScale: scaler.scale(1));
    final line = MmTextMetrics.of(context, title, style, textScaler: scaler);

    Widget text({int? maxLines}) => _AmbientTextScale(
      scaler: scaler,
      child: Text(
        title,
        style: style,
        maxLines: maxLines,
        softWrap: maxLines != 1,
        overflow: maxLines == 1 ? TextOverflow.ellipsis : TextOverflow.clip,
      ),
    );

    AppBar appBar({
      required double toolbarHeight,
      Widget? title,
      PreferredSizeWidget? bottom,
    }) => AppBar(
      leading: widget.leading,
      title: title,
      titleSpacing: spacing,
      actions: actions,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      // Lines the last action's glyph up 16 dp from the edge, like the
      // title at the start.
      actionsPadding: const EdgeInsetsDirectional.only(end: MmSpace.s1),
    );

    if (line.size.width <= toolbarRoom && _tooWide != layout) {
      return appBar(
        toolbarHeight: math.max(
          MmSize.appBar,
          line.size.height + 2 * MmSpace.s2,
        ),
        title: _ToolbarTitle(
          fits: (room) => line.size.width <= room,
          onTooWide: () => _titleTooWide(layout),
          child: text(maxLines: 1),
        ),
      );
    }
    final lines = MmTextMetrics.of(
      context,
      title,
      style,
      textScaler: scaler,
      maxWidth: math.max(0, width - 2 * columnStart),
    );
    if (!leads && actions.isEmpty) {
      return appBar(
        toolbarHeight: math.max(
          MmSize.appBar,
          lines.size.height + 2 * MmSpace.s2,
        ),
        title: text(),
      );
    }
    return appBar(
      toolbarHeight: MmSize.appBar,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(lines.size.height + MmSpace.s3),
        child: Semantics(
          header: true,
          namesRoute: true,
          child: Padding(
            // Under the toolbar the title spans the content column.
            padding: EdgeInsetsDirectional.only(
              start: columnStart,
              end: columnStart,
              bottom: MmSpace.s3,
            ),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: text(),
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the title of [layout] under the toolbar from the next frame.
  void _titleTooWide(_TitleLayout layout) {
    if (_tooWide == layout) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tooWide = layout);
    });
  }

  /// [MmPage.body] in the readable column, scrolling, inside a scaffold's body
  /// ([context]).
  Widget _scrolling(BuildContext context) {
    final onRefresh = widget.onRefresh;
    // The scaffold has taken the app bar's and the bottom bar's share of
    // the safe area; the sides and, without a bottom bar, the gesture bar
    // are left for the page. The floating button stands on that bottom
    // edge, so its room comes on top of it.
    final safeArea = MediaQuery.paddingOf(context);
    final end = safeArea.bottom + math.max(MmSpace.s4, _fabRoom);
    final scrollView = SingleChildScrollView(
      // A short page must still be pullable to refresh.
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      // Safe-area insets are physical (the device's own left and right).
      // design-lint: allow-next-line physical safe-area insets
      padding: EdgeInsets.fromLTRB(
        safeArea.left + MmSpace.s4,
        MmSpace.s4,
        safeArea.right + MmSpace.s4,
        end,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MmSize.contentMax),
          child: SizedBox(
            width: double.infinity,
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              removeBottom: true,
              child: widget.body,
            ),
          ),
        ),
      ),
    );
    if (onRefresh == null) return scrollView;
    final colors = context.mm.colors;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: scrollView,
    );
  }

  /// [MmPage.body] in the readable column, filling the height of a scaffold's
  /// body ([context]). The bottom safe area stays with [MmPage.body], with
  /// the floating button's room added to it.
  Widget _filling(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);
    final inside = MediaQuery.of(context)
        .removePadding(removeLeft: true, removeRight: true);
    return Padding(
      // Safe-area insets are physical (the device's own left and right).
      // design-lint: allow-next-line physical safe-area insets
      padding: EdgeInsets.fromLTRB(
        safeArea.left + MmSpace.s4,
        0,
        safeArea.right + MmSpace.s4,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MmSize.contentMax),
          child: SizedBox.expand(
            child: MediaQuery(
              data: inside.copyWith(
                padding: inside.padding.copyWith(
                  bottom: inside.padding.bottom + _fabRoom,
                ),
              ),
              child: widget.body,
            ),
          ),
        ),
      ),
    );
  }
}

/// The title in the toolbar, reporting when it turns out wider than the
/// room the toolbar's buttons leave it.
class _ToolbarTitle extends StatelessWidget {
  const new({required this.fits, required this.onTooWide, required this.child});

  /// Whether the title fits on one line in a room this wide.
  final bool Function(double room) fits;

  final VoidCallback onTooWide;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!fits(constraints.maxWidth)) onTooWide();
      return child;
    },
  );
}

/// Sets [child]'s text at [scaler], undoing the cap an app bar puts on its
/// title's text scale.
class _AmbientTextScale extends StatelessWidget {
  const new({required this.scaler, required this.child});

  final TextScaler scaler;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: child,
  );
}

/// Reports its child's height to [onHeight] after each layout that changes
/// it, from the end of that frame.
class _MeasuredHeight extends SingleChildRenderObjectWidget {
  const new({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderMeasuredHeight createRenderObject(BuildContext context) =>
      _RenderMeasuredHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderMeasuredHeight extends RenderProxyBox {
  new(this.onHeight);

  ValueChanged<double> onHeight;

  /// The height last reported.
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
