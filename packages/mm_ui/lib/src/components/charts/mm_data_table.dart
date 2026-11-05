import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A column of an [MmDataTable]: its header [label] and whether it holds
/// figures.
@immutable
final class MmDataColumn {
  /// A column headed [label]; [numeric] columns hold figures.
  const new({required this.label, this.numeric = false});

  /// The column's header ("Tenant", "Rent"), from the app's localisations.
  final String label;

  /// Whether the column holds figures (amounts, counts, percentages). Its
  /// cells and header align to the end edge and are set in the Latin face
  /// with tabular figures, so the digits of every row line up.
  final bool numeric;

  @override
  bool operator ==(Object other) =>
      other is MmDataColumn && other.label == label && other.numeric == numeric;

  @override
  int get hashCode => Object.hash(label, numeric);

  @override
  String toString() => 'MmDataColumn("$label"${numeric ? ', numeric' : ''})';
}

/// A plain table of text: a header row of [columns] over [rows] of cells,
/// separated by hairline rules like the lines of a ledger, with no zebra
/// stripes.
///
/// Numeric columns align to the end edge in the Latin face with tabular
/// figures, so columns of rupees line up in both languages. Columns take
/// the width of their widest cell and the first column takes any width to
/// spare; when the table is wider than its space it scrolls sideways (with
/// a scrollbar, and with the arrow keys once focused). Columns run from the
/// start edge, so in Urdu the first column is on the right.
///
/// Each cell keeps its own text's direction, so Latin-script data and plain
/// figures (a phone number, a CNIC) read left to right in the Urdu table
/// as well.
///
/// Screen readers read it as a table: the header cells are column headers,
/// then each cell is its own node, row by row. Figures in numeric cells are
/// read without their grouping commas ("Rs 125000"), since grouped figures
/// such as 1,25,000 are read out unreliably.
///
/// Use it for a short list of records compared across a few columns (a
/// rent roll) and as the accessible twin of a chart (`MmBarChart` shows its
/// data in one). Don't use it for records the landlord opens or acts on
/// (use list tiles), or for one record's details (use detail rows).
///
/// ```dart
/// MmDataTable(
///   caption: l10n.rentRollOctober,
///   columns: [
///     MmDataColumn(label: l10n.tenant),
///     MmDataColumn(label: l10n.rent, numeric: true),
///   ],
///   rows: [
///     for (final lease in leases)
///       [lease.tenantName, format.format(lease.rent)],
///   ],
/// )
/// ```
class MmDataTable extends StatefulWidget {
  /// A table of [rows] under the headers of [columns].
  const new({
    required this.columns,
    required this.rows,
    this.caption,
    super.key,
  });

  /// The columns, in reading order from the start edge.
  final List<MmDataColumn> columns;

  /// The cells, row by row; each row has one cell per column, in the order
  /// of [columns]. Text is shown in full, on one line.
  final List<List<String>> rows;

  /// What the table shows ("Rent roll, October"), set above it as its
  /// heading, from the app's localisations. Leave it out when a heading
  /// above the table already says it.
  final String? caption;

  @override
  State<MmDataTable> createState() => _MmDataTableState();
}

class _MmDataTableState extends State<MmDataTable> {
  final ScrollController _scroll = ScrollController();
  bool _overflows = false;
  bool _focusShown = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.arrowLeft): ScrollIntent(
      direction: AxisDirection.left,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight): ScrollIntent(
      direction: AxisDirection.right,
    ),
  };

  final Map<Type, Action<Intent>> _actions = {ScrollIntent: ScrollAction()};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    return false;
  }

  void _handleFocusHighlight(bool shown) {
    if (shown != _focusShown) setState(() => _focusShown = shown);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.rows.every((row) => row.length == widget.columns.length),
      'Every row of an MmDataTable needs one cell per column.',
    );
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final caption = widget.caption;
    final rule = BorderSide(color: colors.rule);
    final table = Table(
      columnWidths: const {0: IntrinsicColumnWidth(flex: 1)},
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      border: TableBorder(horizontalInside: rule, bottom: rule),
      children: [
        TableRow(
          children: [
            for (final (index, column) in widget.columns.indexed)
              _header(context, column, index),
          ],
        ),
        for (final row in widget.rows)
          TableRow(
            children: [
              for (final (index, column) in widget.columns.indexed)
                _cell(context, row.elementAtOrNull(index) ?? '', column, index),
            ],
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                caption,
                style: context.mm.styleFor(caption, text.titleMedium!),
              ),
            ),
          ),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: _focusShown
              ? BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(MmRadius.xs),
                  ),
                  border: Border.all(
                    color: colors.focus,
                    width: MmSize.focusRing,
                  ),
                )
              : const BoxDecoration(),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                NotificationListener<ScrollMetricsNotification>(
                  onNotification: _handleMetrics,
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: _overflows,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: FocusableActionDetector(
                        enabled: _overflows,
                        includeFocusSemantics: false,
                        shortcuts: _shortcuts,
                        actions: _actions,
                        onShowFocusHighlight: _handleFocusHighlight,
                        child: Padding(
                          // Room for the scrollbar under the last rule.
                          padding: EdgeInsetsDirectional.only(
                            bottom: _overflows ? MmSpace.s3 : 0,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: table,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  /// Where a cell's text sits in its column: figures at the end edge, so
  /// their digits line up, words at the start.
  static AlignmentGeometry _alignment(MmDataColumn column) => column.numeric
      ? AlignmentDirectional.centerEnd
      : AlignmentDirectional.centerStart;

  /// The padding of a cell in column [index]: a gap from the previous
  /// column, none at the table's outer edges.
  EdgeInsetsGeometry _padding(int index) => EdgeInsetsDirectional.only(
    start: index == 0 ? 0 : MmSpace.s4,
    top: MmSpace.s3,
    bottom: MmSpace.s3,
  );

  Widget _header(BuildContext context, MmDataColumn column, int index) {
    final colors = context.mm.colors;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: colors.inkMuted);
    return Semantics(
      container: true,
      header: true,
      role: SemanticsRole.columnHeader,
      label: column.label,
      excludeSemantics: true,
      child: Padding(
        padding: _padding(index),
        child: Align(
          alignment: _alignment(column),
          child: Text(
            column.label,
            style: context.mm.styleFor(column.label, style),
            softWrap: false,
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String value,
    MmDataColumn column,
    int index,
  ) {
    final mm = context.mm;
    final style = column.numeric
        ? mm.figures(MmTypeScale.latinBodySmall, mm.colors.ink)
        : mm.styleFor(value, Theme.of(context).textTheme.bodyMedium!);
    return Semantics(
      container: true,
      role: SemanticsRole.cell,
      label: column.numeric ? mmUngrouped(value) : value,
      excludeSemantics: true,
      child: Padding(
        padding: _padding(index),
        child: Align(
          alignment: _alignment(column),
          child: Text(
            value,
            style: style,
            softWrap: false,
            textDirection: mmDirectionOf(value),
          ),
        ),
      ),
    );
  }
}
