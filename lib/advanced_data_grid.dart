library advanced_data_grid;

import 'dart:async';

import 'package:advanced_data_grid/filter_bool.dart';
import 'package:advanced_data_grid/filter_country.dart';
import 'package:advanced_data_grid/filter_date.dart';
import 'package:data_table_2/data_table_2.dart';
import 'datasource.dart';
import 'export_data.dart';
import 'filter_text.dart';
import 'types.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GridSearchDebouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  GridSearchDebouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (null != _timer) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class DataGridColumn {
  const DataGridColumn({
    required this.column,
    required this.builder,
    required this.title,
    this.filter,
    this.filterDropDownOptions,
    this.noSorting,
    this.isEdge,
    this.columnSize = ColumnSize.M,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
    this.unitName,
    this.includeInExport = false,
    this.exportReplacementString,
    this.filterColumnName,
  });

  /// Column's key name returned in the DataSource.
  final String column;

  /// Disables sorting on this Column.
  final bool? noSorting;

  /// When true, searches for the Column's value inside of an "Edges" object.
  final bool? isEdge;

  /// Enable Filtering on the Column.
  final DataFilterType? filter;

  /// Populates Drop Down options to filter the column when filter is set to DataFilterType.DROPDOWN.
  final List<Map<String, dynamic>>? filterDropDownOptions;

  /// Builder for the Column's cells.
  final DataGridColumnBuilder builder;

  /// Column Title to be displayed in the Grid.
  final String title;

  /// Unit name displayed when filtering the column, for example: Filter Items by 2 "items".
  final String? unitName;

  /// Include Column inside of Table Exports.
  final bool includeInExport;

  /// Replace the Value of the Column in the export with this value.
  final DataGridExportString? exportReplacementString;

  /// Resize the Column relative to others, takes ColumnSize.S, ColumnSize.M and ColumnSize.L from DataTable2.
  final ColumnSize columnSize;

  /// Size the Column to a Fixed Width value in pixels.
  final double? fixedWidth;

  /// Align Data inside of the Column's Title and Cells.
  final Alignment alignment;

  /// Override column name when filtering or sorting via the DataSource.
  final String? filterColumnName;
}

class DataGrid extends StatefulWidget {
  const DataGrid({
    super.key,
    required this.source,
    required this.builders,
    this.title,
    this.subTitle,
    this.actions,
    this.wrapWithCard = false,
    this.minWidth,
    required this.titleBuilder,
    this.enableTextSelection = false,
    this.enableMultiSort = false,
    this.mainSearchColumn,
    this.showCheckboxColumn = false,
    this.identifierColumnName,
    this.selectedRows,
    this.onSelectionChange,
    this.onRowTap,
    this.exportTypes = const [],
    this.primaryColor,
    this.overrideElevatedButtonStyle,
    this.overrideTextButtonStyle,
    this.fixedPageLimit,
    this.hidePageSelection = false,
  });

  /// Data Source for the Table.
  final DataSource source;

  /// List of Columns for the Table.
  final List<DataGridColumn> builders;

  /// Title for the DataGrid, displayed above the Grid.
  final String? title;

  /// Sub Title for the DataGrid, displayed beside the Title.
  final String? subTitle;

  /// Actions (Widgets) displayed in the heading.
  final List<Widget>? actions;

  /// Wrap DataGrid with a Card.
  final bool wrapWithCard;

  /// Minimum width for the Data Table. Will scroll if minWidth exceeds the DataGrid's parent's width.
  final double? minWidth;

  /// Builder for Column Titles, title is taken from each DataGridColumn.
  final DataGridTitleBuilder titleBuilder;

  /// Enable Text Highlighting for the Grid.
  final bool enableTextSelection;

  /// Allow Multiple Columns to be sorted at once.
  final bool enableMultiSort;

  /// When provided, will add a Search Box to the top right of the Grid.
  final DataGridColumn? mainSearchColumn;

  /// Display Checkboxes beside each row for Row Selection.
  final bool showCheckboxColumn;

  /// Identifier used for Row Selection.
  final String? identifierColumnName;

  /// List of currently selected Rows by their Column Identifiers.
  final List<String>? selectedRows;

  /// Function called when a Row is selected/unselected.
  final Function? onSelectionChange;

  /// Function called when tapping on a Row.
  final Function? onRowTap;

  /// If provided, will enable Export functionality from the Grid via the specified types.
  final List<DataGridExportType> exportTypes;

  /// Override the Primary Colour of the Grid. By default will use Theme Primary Colour.
  final Color? primaryColor;

  /// Override all Elevated Buttons on the Grid. By default will use Theme Elevated Button Style.
  final ButtonStyle? overrideElevatedButtonStyle;

  /// Override all Text Buttons on the Grid. By default will use Theme Text Button Style.
  final ButtonStyle? overrideTextButtonStyle;

  /// Disables adjustment of Page Size on the Grid.
  final int? fixedPageLimit;

  /// Hides the Specific Page selection buttons, leaving just Previous and Next buttons.
  final bool hidePageSelection;

  @override
  State<DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<DataGrid> {
  final GridSearchDebouncer _searchDebouncer = GridSearchDebouncer(milliseconds: 500);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final double _mobileWidth = 1024;

  @override
  void initState() {
    super.initState();

    widget.source.loadPage(1);
  }

  List<DataColumn2> get _headers {
    var titleCells = widget.builders.asMap().entries.map((entry) {
      var sortDirection = widget.source.getSort(entry.value.filterColumnName ?? entry.value.column);
      var hasFilter = widget.source.hasFilters(entry.value.filterColumnName ?? entry.value.column);

      Widget titleContent = Row(
        children: [
          Expanded(
            child: Align(
              alignment: entry.value.alignment,
              child: widget.titleBuilder(entry.key, entry.value.title),
            ),
          ),
          entry.value.filter == null
              ? Container()
              : Container(
                  padding: EdgeInsets.only(right: sortDirection == "asc" || sortDirection == "desc" ? 10 : 0),
                  child: PopupMenuButton(
                    enableFeedback: false,
                    enabled: true,
                    padding: const EdgeInsets.all(0),
                    child: hasFilter
                        ? Icon(Icons.filter_alt_off_rounded, color: widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.filter_alt_rounded, color: Colors.grey),
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          enabled: false,
                          child: entry.value.filter == DataFilterType.DATETIME
                              ? FilterDate(
                                  data: entry.value,
                                  filterType: entry.value.filter!,
                                  source: widget.source,
                                  primaryColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                )
                              : entry.value.filter == DataFilterType.BOOLEAN
                                  ? FilterBool(
                                      data: entry.value,
                                      filterType: entry.value.filter!,
                                      source: widget.source,
                                      primaryColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                    )
                                  : entry.value.filter == DataFilterType.COUNTRY_CODE
                                      ? FilterCountry(
                                          data: entry.value,
                                          filterType: entry.value.filter!,
                                          source: widget.source,
                                          primaryColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                        )
                                      : FilterText(
                                          data: entry.value,
                                          filterType: entry.value.filter!,
                                          source: widget.source,
                                          primaryColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                        ),
                        )
                      ];
                    },
                  ),
                ),
          sortDirection == "asc" || sortDirection == "desc"
              ? SizedBox(
                  width: 26,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: sortDirection == "asc"
                            ? Icon(Icons.arrow_upward_rounded, color: widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                            : sortDirection == "desc"
                                ? Icon(Icons.arrow_downward_rounded, color: widget.primaryColor ?? Theme.of(context).colorScheme.primary)
                                : Container(),
                      ),
                      widget.source.columnSorts.length > 1
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                height: 12,
                                width: 12,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    (widget.source.columnSorts.keys.toList().indexOf(entry.value.filterColumnName ?? entry.value.column) + 1)
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ],
                  ),
                )
              : Container(),
        ],
      );

      return DataColumn2(
        size: entry.value.columnSize,
        fixedWidth: entry.value.fixedWidth,
        label: Row(
          children: [
            Expanded(
              child: entry.value.noSorting ?? false
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: titleContent,
                    )
                  : TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        if (sortDirection == "asc") {
                          widget.source.removeSort(entry.value.filterColumnName ?? entry.value.column);
                          return;
                        }

                        if (widget.enableMultiSort) {
                          widget.source.addSort(entry.value.filterColumnName ?? entry.value.column, sortDirection == "desc" ? "asc" : "desc");
                        } else {
                          widget.source.replaceAllSorts(entry.value.filterColumnName ?? entry.value.column, sortDirection == "desc" ? "asc" : "desc");
                        }
                      },
                      child: titleContent,
                    ),
            ),
          ],
        ),
      );
    }).toList();

    return titleCells;
  }

  Widget _getSearchField() {
    return SizedBox(
      width: 240,
      child: TextFormField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          _searchDebouncer.run(() {
            if (_searchController.text != "") {
              widget.source.setFilters(
                widget.mainSearchColumn!.filterColumnName ?? widget.mainSearchColumn!.column,
                [DataFilter(operator: null, value: _searchController.text)],
              );
            } else {
              widget.source.removefilters(widget.mainSearchColumn!.filterColumnName ?? widget.mainSearchColumn!.column);
            }
          });
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          isDense: true,
          border: const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(141, 141, 141, 1), width: 0.5)),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(141, 141, 141, 1), width: 0.5)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.primaryColor ?? Theme.of(context).colorScheme.primary)),
          errorMaxLines: 3,
          errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(226, 106, 103, 1))),
          focusColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
          fillColor: const Color.fromRGBO(249, 249, 249, 1),
          filled: true,
          hintText: "Search ${widget.mainSearchColumn!.title}...",
          hintStyle: const TextStyle(color: Color.fromRGBO(141, 141, 141, 1)),
          prefixIcon: Icon(
            Icons.search,
            color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          constraints: const BoxConstraints(maxHeight: 240),
          disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color.fromRGBO(141, 141, 141, 1).withOpacity(0.5), width: 0.5)),
        ),
        textInputAction: TextInputAction.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => widget.source,
      child: Consumer<DataSource>(
        builder: (context, value, child) {
          // Default to loader
          List<DataRow> rows = [];

          if (!value.isLoading) {
            rows = value.items
                .map((data) => DataRow2(
                    onSelectChanged: widget.onSelectionChange != null && widget.identifierColumnName != null
                        ? (bool? sel) {
                            bool isSelected = sel == true;
                            widget.onSelectionChange!(data, isSelected);
                          }
                        : null,
                    selected: widget.selectedRows != null &&
                            widget.identifierColumnName != null &&
                            widget.selectedRows!.contains(data[widget.identifierColumnName])
                        ? true
                        : false,
                    onTap: widget.onRowTap != null
                        ? () {
                            widget.onRowTap!(data);
                          }
                        : null,
                    cells: widget.builders.asMap().entries.map((entry) {
                      dynamic cellData;

                      if (entry.value.isEdge ?? false) {
                        cellData = data["edges"][entry.value.column];
                      } else {
                        cellData = data[entry.value.column];
                      }

                      return DataCell(Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Align(alignment: entry.value.alignment, child: entry.value.builder(data, cellData, entry.key))));
                    }).toList()))
                .toList();
          }

          Widget table = DataTable2(
            minWidth: widget.minWidth,
            headingRowHeight: 48,
            horizontalMargin: 16,
            checkboxHorizontalMargin: 12,
            columnSpacing: 0,
            showCheckboxColumn: widget.showCheckboxColumn,
            onSelectAll: (bool? sel) {
              bool isSelected = sel == true;

              for (Map<String, dynamic> row in value.items) {
                widget.onSelectionChange!(row, isSelected);
              }
            },
            columns: _headers,
            rows: [
              for (var row in rows) row,
            ],
            empty: widget.source.isLoading
                ? Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text("Loading ${widget.title ?? ""}...")],
                    ),
                  )
                : Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.grey[300],
                      ),
                      child: Text(
                        "No ${widget.title} found matching your search criteria.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          );

          return Container(
            decoration: widget.wrapWithCard
                ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.grey)],
                  )
                : null,
            child: Column(
              children: [
                widget.title != null || widget.mainSearchColumn != null || widget.actions != null
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.title ?? "",
                                      style: const TextStyle(
                                        color: Color.fromRGBO(54, 54, 54, 1),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: "  "),
                                    MediaQuery.of(context).size.width >= _mobileWidth
                                        ? TextSpan(
                                            text: widget.subTitle ?? "",
                                            style: const TextStyle(
                                              color: Color.fromRGBO(105, 105, 105, 1),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : const TextSpan(text: ""),
                                  ],
                                  style: const TextStyle(
                                    fontFamily: "Montserrat",
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            widget.actions != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Row(
                                      children: widget.actions!,
                                    ),
                                  )
                                : Container(),
                            widget.exportTypes.isNotEmpty && !widget.source.isLoading && widget.source.items.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: TextButton(
                                      onPressed: () {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return ExportDataGridModal(
                                                title: widget.title ?? "Data",
                                                columns: widget.builders.where((column) => column.includeInExport == true).toList(),
                                                source: widget.source,
                                                exportTypes: widget.exportTypes,
                                                overrideButtonStyle: widget.overrideElevatedButtonStyle,
                                                primaryColor: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                              );
                                            });
                                      },
                                      style: widget.overrideTextButtonStyle != null
                                          ? widget.overrideTextButtonStyle!.copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero))
                                          : Theme.of(context).textButtonTheme.style != null
                                              ? Theme.of(context).textButtonTheme.style!.copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero))
                                              : TextButton.styleFrom().copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero)),
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                                        height: 36,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.download,
                                              color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                              size: 24,
                                            ),
                                            Container(
                                              padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width >= _mobileWidth ? 10 : 0, 0,
                                                  MediaQuery.of(context).size.width >= _mobileWidth ? 6 : 0, 0),
                                              child: MediaQuery.of(context).size.width >= _mobileWidth
                                                  ? const Text(
                                                      "EXPORT",
                                                      style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 14),
                                                    )
                                                  : Container(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(),
                            Row(
                              children: [
                                widget.mainSearchColumn != null
                                    ? MediaQuery.of(context).size.width > _mobileWidth
                                        ? _getSearchField()
                                        : TextButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return Dialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    child: ConstrainedBox(
                                                      constraints: BoxConstraints(
                                                          maxWidth:
                                                              MediaQuery.of(context).size.width > 364 ? 332 : MediaQuery.of(context).size.width - 32),
                                                      child: Container(
                                                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Expanded(
                                                                  child: Text(
                                                                    "Search",
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.w700,
                                                                      color: Color.fromRGBO(54, 54, 54, 1),
                                                                      fontSize: 16,
                                                                    ),
                                                                  ),
                                                                ),
                                                                IconButton(
                                                                  onPressed: () {
                                                                    Navigator.of(context).pop();
                                                                  },
                                                                  icon: const Icon(Icons.close_rounded),
                                                                  color: const Color.fromRGBO(54, 54, 54, 1),
                                                                  splashRadius: 30,
                                                                  padding: const EdgeInsets.all(5),
                                                                ),
                                                              ],
                                                            ),
                                                            _getSearchField(),
                                                            const SizedBox(height: 10),
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                ElevatedButton(
                                                                  onPressed: () {
                                                                    Navigator.of(context).pop();
                                                                  },
                                                                  child: const Text("SEARCH"),
                                                                  style: widget.overrideElevatedButtonStyle ??
                                                                      (Theme.of(context).elevatedButtonTheme.style ?? ElevatedButton.styleFrom()),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            style: widget.overrideTextButtonStyle != null
                                                ? widget.overrideTextButtonStyle!.copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero))
                                                : Theme.of(context).textButtonTheme.style != null
                                                    ? Theme.of(context)
                                                        .textButtonTheme
                                                        .style!
                                                        .copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero))
                                                    : TextButton.styleFrom().copyWith(padding: MaterialStateProperty.all(EdgeInsets.zero)),
                                            child: Container(
                                              padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                                              height: 36,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.search,
                                                    color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                                    size: 24,
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width >= _mobileWidth ? 10 : 0, 0,
                                                        MediaQuery.of(context).size.width >= _mobileWidth ? 6 : 0, 0),
                                                    child: MediaQuery.of(context).size.width >= _mobileWidth
                                                        ? const Text(
                                                            "SEARCH",
                                                            style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 14),
                                                          )
                                                        : Container(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                    : Container(),
                              ],
                            )
                          ],
                        ),
                      )
                    : Container(),
                Expanded(
                  child: widget.enableTextSelection ? SelectionArea(child: table) : table,
                ),
                const Divider(
                  height: 2,
                  thickness: 2,
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
                  height: 48,
                  child: !widget.source.isLoading
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MediaQuery.of(context).size.width > _mobileWidth ? MainAxisAlignment.end : MainAxisAlignment.center,
                          children: [
                            widget.fixedPageLimit == null && MediaQuery.of(context).size.width > _mobileWidth
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text("Rows per page:", style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 12)),
                                      Container(
                                        width: 50,
                                        margin: const EdgeInsets.only(left: 10, right: 16),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<num>(
                                            isDense: true,
                                            isExpanded: true,
                                            borderRadius: BorderRadius.circular(6),
                                            items: const [
                                              DropdownMenuItem<num>(
                                                  value: 15,
                                                  child: Text("15", style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 12))),
                                              DropdownMenuItem<num>(
                                                  value: 30,
                                                  child: Text("30", style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 12))),
                                              DropdownMenuItem<num>(
                                                  value: 60,
                                                  child: Text("60", style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 12))),
                                              DropdownMenuItem<num>(
                                                  value: 100,
                                                  child: Text("100", style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1), fontSize: 12))),
                                            ],
                                            value: widget.source.pageSize,
                                            onChanged: (limit) {
                                              widget.source.setPageLimit(limit ?? 15);
                                            },
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                                : Container(),
                            Text(
                              widget.hidePageSelection
                                  ? "${widget.source.totalCount} rows"
                                  : "${MediaQuery.of(context).size.width > _mobileWidth ? "Showing " : ""}${(widget.source.currentPage * widget.source.pageSize) - (widget.source.pageSize - 1)}-${((widget.source.currentPage * widget.source.pageSize) - widget.source.pageSize) + widget.source.items.length} of ${widget.source.totalCount}",
                              style: const TextStyle(
                                color: Color.fromRGBO(105, 105, 105, 1),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            !widget.hidePageSelection
                                ? IconButton(
                                    onPressed: widget.source.currentPage > 1
                                        ? () {
                                            widget.source.loadPage(1);
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                    ),
                                    color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                  )
                                : Container(),
                            IconButton(
                              onPressed: widget.source.currentPage > 1
                                  ? () {
                                      widget.source.loadPage(widget.source.currentPage - 1);
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_left_rounded,
                              ),
                              color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                            ),
                            for (var p in widget.source.pagination)
                              !widget.hidePageSelection
                                  ? TextButton(
                                      onPressed: () => widget.source.loadPage(p),
                                      child: Text(
                                        "$p",
                                        style: TextStyle(
                                          fontWeight: p == widget.source.currentPage ? FontWeight.bold : FontWeight.normal,
                                          color: p == widget.source.currentPage
                                              ? widget.primaryColor ?? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ))
                                  : Container(),
                            IconButton(
                              onPressed: widget.source.currentPage < widget.source.lastPage
                                  ? () {
                                      widget.source.loadPage(widget.source.currentPage + 1);
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.keyboard_arrow_right_rounded,
                              ),
                              color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                            ),
                            !widget.hidePageSelection
                                ? IconButton(
                                    onPressed: widget.source.currentPage < widget.source.lastPage
                                        ? () {
                                            widget.source.loadPage(widget.source.lastPage);
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                    ),
                                    color: widget.primaryColor ?? Theme.of(context).colorScheme.primary,
                                  )
                                : Container(),
                          ],
                        )
                      : Container(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
