import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// One column of an [AdminTable].
///
/// Provide [sortValue] to make the column's header clickable for sorting.
class AdminColumn<T> {
  const AdminColumn({
    required this.label,
    required this.cell,
    this.flex = 2,
    this.sortValue,
    this.numeric = false,
    this.tooltip,
  });

  final String label;
  final Widget Function(BuildContext context, T item) cell;
  final int flex;

  /// Value the rows are compared on when this column is sorted.
  final Comparable<Object>? Function(T item)? sortValue;

  /// Right-aligns the column, for counts and amounts.
  final bool numeric;

  final String? tooltip;

  bool get isSortable => sortValue != null;
}

/// The dashboard's list surface: sortable sticky header, lazily built rows,
/// hover feedback, horizontal scrolling on narrow windows, and paging so a
/// few thousand records stay responsive.
class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.items,
    this.rowKey,
    this.onRowTap,
    this.minWidth = 900,
    this.rowsPerPage = 25,
    this.rowsPerPageOptions = const [10, 25, 50, 100],
    this.itemLabel = 'rows',
    this.initialSortColumn,
    this.initialSortAscending = true,
    this.rowHeight,
  });

  final List<AdminColumn<T>> columns;
  final List<T> items;

  /// Stable identity per row, so hover state survives list updates.
  final Object Function(T item)? rowKey;

  final void Function(T item)? onRowTap;

  /// Below this the table scrolls sideways instead of squeezing columns.
  final double minWidth;

  final int rowsPerPage;
  final List<int> rowsPerPageOptions;

  /// Plural noun used in the "1–25 of 128 owners" summary.
  final String itemLabel;

  final int? initialSortColumn;
  final bool initialSortAscending;

  /// Fixed row height. Leave null to let rows size to their content.
  final double? rowHeight;

  @override
  State<AdminTable<T>> createState() => _AdminTableState<T>();
}

class _AdminTableState<T> extends State<AdminTable<T>> {
  final _verticalController = ScrollController();

  int? _sortColumn;
  late bool _ascending;
  late int _rowsPerPage;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _sortColumn = widget.initialSortColumn;
    _ascending = widget.initialSortAscending;
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(AdminTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The filtered list can shrink under us; never leave the view parked on a
    // page that no longer exists.
    if (widget.items.length != oldWidget.items.length) {
      final maxPage = math.max(0, (widget.items.length - 1) ~/ _rowsPerPage);
      if (_page > maxPage) _page = maxPage;
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  List<T> get _sortedItems {
    final column = _sortColumn;
    if (column == null || column >= widget.columns.length) return widget.items;
    final sortValue = widget.columns[column].sortValue;
    if (sortValue == null) return widget.items;

    final sorted = List<T>.of(widget.items);
    sorted.sort((a, b) {
      final valueA = sortValue(a);
      final valueB = sortValue(b);
      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return 1;
      if (valueB == null) return -1;
      final comparison = valueA.compareTo(valueB);
      return _ascending ? comparison : -comparison;
    });
    return sorted;
  }

  void _onHeaderTap(int index) {
    if (!widget.columns[index].isSortable) return;
    setState(() {
      if (_sortColumn == index) {
        _ascending = !_ascending;
      } else {
        _sortColumn = index;
        _ascending = true;
      }
      _page = 0;
    });
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_verticalController.hasClients) _verticalController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedItems;
    final totalPages = math.max(1, (sorted.length / _rowsPerPage).ceil());
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _rowsPerPage;
    final end = math.min(start + _rowsPerPage, sorted.length);
    final visible = sorted.sublist(start, end);
    final needsPaging = sorted.length > widget.rowsPerPageOptions.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, widget.minWidth);

        return Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _verticalController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        _buildHeaderRow(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            controller: _verticalController,
                            padding: const EdgeInsets.only(bottom: 4),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              return _AdminTableRow<T>(
                                key: widget.rowKey == null
                                    ? null
                                    : ValueKey(widget.rowKey!(item)),
                                item: item,
                                columns: widget.columns,
                                height: widget.rowHeight,
                                onTap: widget.onRowTap == null
                                    ? null
                                    : () => widget.onRowTap!(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (needsPaging)
              PaginationBar(
                page: page,
                totalPages: totalPages,
                rangeStart: start + 1,
                rangeEnd: end,
                totalItems: sorted.length,
                rowsPerPage: _rowsPerPage,
                rowsPerPageOptions: widget.rowsPerPageOptions,
                itemLabel: widget.itemLabel,
                onPageChanged: _goToPage,
                onRowsPerPageChanged: (value) {
                  setState(() {
                    _rowsPerPage = value;
                    _page = 0;
                  });
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: widget.columns[i].flex,
              child: _HeaderCell(
                column: widget.columns[i],
                isSorted: _sortColumn == i,
                ascending: _ascending,
                onTap: () => _onHeaderTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.isSorted,
    required this.ascending,
    required this.onTap,
  });

  final AdminColumn<T> column;
  final bool isSorted;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisAlignment: column.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            column.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSorted ? AppTheme.primaryColor : AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        if (column.isSortable)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              isSorted
                  ? (ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isSorted
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary.withOpacity(0.5),
            ),
          ),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: label,
    );

    if (!column.isSortable) {
      return column.tooltip == null
          ? content
          : Tooltip(message: column.tooltip!, child: content);
    }

    return Tooltip(
      message: column.tooltip ?? 'Sort by ${column.label}',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: content,
      ),
    );
  }
}

class _AdminTableRow<T> extends StatefulWidget {
  const _AdminTableRow({
    super.key,
    required this.item,
    required this.columns,
    this.onTap,
    this.height,
  });

  final T item;
  final List<AdminColumn<T>> columns;
  final VoidCallback? onTap;
  final double? height;

  @override
  State<_AdminTableRow<T>> createState() => _AdminTableRowState<T>();
}

class _AdminTableRowState<T> extends State<_AdminTableRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _hovered
            ? AppTheme.primaryColor.withOpacity(0.06)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hovered ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: widget.columns[i].flex,
              child: Align(
                alignment: widget.columns[i].numeric
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: widget.columns[i].cell(context, widget.item),
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? row
          : GestureDetector(onTap: widget.onTap, child: row),
    );
  }
}

/// Range summary, page-size selector and page stepper shown under a table.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalItems,
    required this.rowsPerPage,
    required this.rowsPerPageOptions,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    this.itemLabel = 'rows',
  });

  final int page;
  final int totalPages;
  final int rangeStart;
  final int rangeEnd;
  final int totalItems;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Text(
            '$rangeStart–$rangeEnd of $totalItems $itemLabel',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          ),
          const Spacer(),
          const Text(
            'Rows',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: const Color(0xFF0F1B25)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: rowsPerPage,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.expand_more_rounded, size: 16, color: AppTheme.primaryColor),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                items: rowsPerPageOptions
                    .map((option) => DropdownMenuItem(value: option, child: Text('$option')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onRowsPerPageChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 20),
          _PageButton(
            icon: Icons.first_page_rounded,
            tooltip: 'First page',
            onPressed: page > 0 ? () => onPageChanged(0) : null,
          ),
          _PageButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${page + 1} / $totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next page',
            onPressed: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
          ),
          _PageButton(
            icon: Icons.last_page_rounded,
            tooltip: 'Last page',
            onPressed: page < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null,
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: AppTheme.primaryColor,
        disabledColor: AppTheme.textTertiary.withOpacity(0.35),
        splashRadius: 18,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: enabled ? AppTheme.primaryColor.withOpacity(0.08) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}
