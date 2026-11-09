import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_ui/mm_ui.dart';

/// What a screen shows of a query read stale-while-revalidate: the value
/// (with a notice when it may be stale), else why it could not be read
/// with a retry, else a skeleton while it loads.
class SnapshotView<T> extends StatelessWidget {
  const new({
    required this.state,
    required this.onRetry,
    required this.loadingLabel,
    required this.failedTitle,
    required this.builder,
    this.skeleton = const MmSkeletonList(itemCount: 4),
    super.key,
  });

  final AsyncValue<Snapshot<T>> state;
  final VoidCallback onRetry;

  /// What screen readers hear while it loads.
  final String loadingLabel;

  /// The heading when it could not be read.
  final String failedTitle;
  final Widget Function(T value) builder;
  final Widget skeleton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = state.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefreshNotice(state: state, onRetry: onRetry),
        if (snapshot != null)
          builder(snapshot.value)
        else if (state.error case final error?)
          MmErrorState(
            title: failedTitle,
            message: failureMessage(l10n, AppFailure.from(error)),
            onRetry: onRetry,
          )
        else
          Semantics(container: true, label: loadingLabel, child: skeleton),
      ],
    );
  }
}

/// "Show more" under a list read a page at a time; a failure to read the
/// next page is said above the button, which tries again.
class LoadMoreButton extends StatefulWidget {
  const new({required this.onLoad, super.key});

  final Future<void> Function() onLoad;

  @override
  State<LoadMoreButton> createState() => _LoadMoreButtonState();
}

class _LoadMoreButtonState extends State<LoadMoreButton> with CommandState {
  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: MmSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          MmButton(
            label: AppLocalizations.of(context).loadMoreAction,
            icon: MmIcons.expand,
            variant: MmButtonVariant.secondary,
            busy: busy,
            onPressed: () => runCommand(widget.onLoad),
          ),
        ],
      ),
    );
  }
}

/// [children] in one card, divided by hairlines: a list group.
class ListCard extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MmCard(
    padding: EdgeInsetsDirectional.zero,
    child: Column(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: MmSize.hairline),
          child,
        ],
      ],
    ),
  );
}
