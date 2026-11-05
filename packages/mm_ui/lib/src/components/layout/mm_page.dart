import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One screen of the app: an app bar with the screen's title and actions,
/// the content in a readable column, and an optional bar of actions pinned
/// at the bottom.
///
/// The content is padded 16 dp from the window's sides and stops at
/// `MmSize.contentMax` (720 dp), centred, so lines stay readable on a
/// tablet or a desktop browser. By default it scrolls (with 16 dp above and
/// below it), and with [onRefresh] it can be pulled down to refresh. Pass
/// `scrollable: false` when [body] scrolls by itself or fills the screen
/// (a `ListView`, tabs with their views): it then gets the whole height.
///
/// The app bar's back button appears when the screen can go back, shows
/// the design system's back arrow and points the other way in Urdu. Its
/// height grows with the text size, so a large title is never clipped.
///
/// [bottomBar] (usually an `MmActionBar`) sits below
/// the content, never covering it; it pads itself for the device's safe
/// area and the on-screen keyboard.
///
/// Use it for every screen inside the app's frame (`MmAdaptiveScaffold`)
/// and for screens pushed on top of it. Don't use it inside a sheet or a
/// dialog.
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
class MmPage extends StatelessWidget {
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
  });

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
  /// until the returned future completes. Only used while [scrollable].
  final Future<void> Function()? onRefresh;

  /// Whether the page scrolls [body]. Turn it off when [body] scrolls by
  /// itself or must fill the screen's height.
  final bool scrollable;

  /// The widget at the start of the app bar. When null, the app bar shows a
  /// back (or close) button whenever the screen can go back.
  final Widget? leading;

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
      child: Scaffold(
        appBar: AppBar(
          leading: leading,
          title: Text(title),
          actions: actions,
          toolbarHeight: _toolbarHeight(context),
          // Lines the last action's glyph up 16 dp from the edge, like the
          // title at the start.
          actionsPadding: const EdgeInsetsDirectional.only(end: MmSpace.s1),
        ),
        body: scrollable ? _scrolling(context) : _filling(),
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
      ),
    );
  }

  /// The app bar's height: the standard 64 dp, or more when the title's
  /// line (large text, Nastaliq) needs it.
  double _toolbarHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style:
            AppBarTheme.of(context).titleTextStyle ??
            Theme.of(context).textTheme.titleLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return math.max(MmSize.appBar, line + 2 * MmSpace.s2);
  }

  /// [body] in the readable column, scrolling.
  Widget _scrolling(BuildContext context) {
    final onRefresh = this.onRefresh;
    final scrollView = SingleChildScrollView(
      // A short page must still be pullable to refresh.
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(MmSpace.s4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MmSize.contentMax),
          child: SizedBox(width: double.infinity, child: body),
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

  /// [body] in the readable column, filling the height.
  Widget _filling() => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: MmSpace.s4),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MmSize.contentMax),
        child: SizedBox.expand(child: body),
      ),
    ),
  );
}
