import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_window.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A list and the details of its selected item: one at a time on phones
/// and small tablets, side by side from `MmWindowSize.expanded` (840 dp) up.
///
/// * Below expanded, it shows [detail] when there is one, else [list]. The
///   list keeps its state (scroll position, search text) while the detail
///   covers it, so going back returns to the same place; it is hidden from
///   screen readers and keyboard focus meanwhile.
/// * From expanded up, [list] takes a fixed [listWidth] column at the start
///   edge, a hairline rule follows, and [detail] (or [emptyDetail] when
///   nothing is selected) fills the rest. Keyboard focus moves through the
///   whole list before the detail.
///
/// It mirrors in right-to-left layouts (the list sits on the right in
/// Urdu), and both panes keep their state when the window changes size
/// class.
///
/// The app owns the selection: it passes the selected item's [detail], or
/// null to show the list again. On a phone the detail stands in for a
/// screen, so clear the selection from the detail's back button and from
/// the system back gesture too (a `PopScope` that cannot pop while a detail
/// is shown). Use it for tenants and their ledgers, properties and their
/// units. Don't use it for a list whose items open full screens on every
/// window size.
///
/// ```dart
/// MmListDetail(
///   list: TenantList(onSelect: (id) => setState(() => selected = id)),
///   detail: selected == null ? null : TenantLedger(id: selected),
///   emptyDetail: const Center(child: Text('Choose a tenant')),
/// )
/// ```
class MmListDetail extends StatefulWidget {
  /// Creates a list-detail layout of [list] and [detail].
  const new({
    required this.list,
    required this.emptyDetail,
    this.detail,
    super.key,
  });

  /// The width of the list column when the panes sit side by side.
  static const double listWidth = 360;

  /// The list of items, usually scrolling by itself.
  final Widget list;

  /// The details of the selected item, or null when nothing is selected.
  final Widget? detail;

  /// What the detail pane shows beside the list when nothing is selected,
  /// such as a short line asking the landlord to choose an item.
  final Widget emptyDetail;

  @override
  State<MmListDetail> createState() => _MmListDetailState();
}

class _MmListDetailState extends State<MmListDetail> {
  /// Keep the panes' state when they move between the layouts.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'MmListDetail.list');
  final GlobalKey _detailKey = GlobalKey(debugLabel: 'MmListDetail.detail');

  @override
  Widget build(BuildContext context) {
    final list = FocusTraversalGroup(
      child: KeyedSubtree(key: _listKey, child: widget.list),
    );
    final detail = widget.detail;
    final detailPane = detail == null
        ? null
        : FocusTraversalGroup(
            child: KeyedSubtree(key: _detailKey, child: detail),
          );

    if (!MmWindowSize.of(context).atLeast(MmWindowSize.expanded)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Visibility(
            visible: detailPane == null,
            maintainState: true,
            child: list,
          ),
          ?detailPane,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: MmListDetail.listWidth, child: list),
        const VerticalDivider(
          width: MmSize.hairline,
          thickness: MmSize.hairline,
        ),
        Expanded(
          child: detailPane ?? FocusTraversalGroup(child: widget.emptyDetail),
        ),
      ],
    );
  }
}
