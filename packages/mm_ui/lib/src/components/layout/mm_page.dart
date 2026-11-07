import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/layout/mm_text_metrics.dart';
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
/// name typed in English) keeps its own script's face in the Urdu UI.
///
/// [bottomBar] (usually an `MmActionBar`) sits below
/// the content, never covering it; it pads itself for the device's safe
/// area and the on-screen keyboard.
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

  /// The screen's main action as a floating button, when it has no
  /// [bottomBar].
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
          floatingActionButton: widget.floatingActionButton,
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
  PreferredSizeWidget _appBar(BuildContext context, double pageWidth) {
    final title = widget.title;
    final appBarTheme = AppBarTheme.of(context);
    final style = context.mm.styleFor(
      title,
      appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge!,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final safeArea = MediaQuery.paddingOf(context);
    final width = pageWidth - safeArea.horizontal;
    final spacing =
        appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
    final leads =
        widget.leading != null ||
        (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final actions = widget.actions;
    // Each action is taken for an icon button, a 48 dp target; a wider one
    // is found out when the title is laid out beside it (see
    // _ToolbarTitle).
    final besideTitle =
        (leads ? appBarTheme.leadingWidth ?? kToolbarHeight : 0) +
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
      maxWidth: math.max(0, width - 2 * spacing),
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
            padding: EdgeInsetsDirectional.only(
              start: spacing,
              end: spacing,
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
    // are left for the page.
    final safeArea = MediaQuery.paddingOf(context);
    final scrollView = SingleChildScrollView(
      // A short page must still be pullable to refresh.
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      // Safe-area insets are physical (the device's own left and right).
      // design-lint: allow-next-line physical safe-area insets
      padding: EdgeInsets.fromLTRB(
        safeArea.left + MmSpace.s4,
        MmSpace.s4,
        safeArea.right + MmSpace.s4,
        safeArea.bottom + MmSpace.s4,
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
  /// body ([context]). The bottom safe area stays with [MmPage.body].
  Widget _filling(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);
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
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
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
