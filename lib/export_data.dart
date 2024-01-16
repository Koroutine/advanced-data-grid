import 'dart:convert';
import 'dart:html' as html;

import 'datasource.dart';
import 'types.dart';
import 'advanced_data_grid.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

class ExportDataGridModal extends StatefulWidget {
  const ExportDataGridModal({
    super.key,
    required this.title,
    required this.columns,
    required this.source,
    required this.exportTypes,
    this.overrideButtonStyle,
    required this.primaryColor,
  });

  final String title;
  final List<DataGridColumn> columns;

  /// The source for data received
  final DataSource source;

  final List<DataGridExportType> exportTypes;
  final ButtonStyle? overrideButtonStyle;
  final Color primaryColor;

  @override
  State<ExportDataGridModal> createState() => _ExportDataGridModalState();
}

class _ExportDataGridModalState extends State<ExportDataGridModal> {
  List<DataGridColumn> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  DataGridExportType _exportType = DataGridExportType.currentPage;
  bool _loading = true;
  bool _exporting = false;
  bool _emailSuccess = false;

  @override
  void initState() {
    _columns = widget.columns;
    _rows = widget.source.items;
    _loading = false;

    super.initState();
  }

  /// Export all source data for a grid as a .csv, sent to the email address of the logged in user
  ///
  /// NOTE: This function does not appear to package any retrieved data into
  /// a .csv file, or contain any email logic. This is because the email functionality
  /// is called within the eSIMs Go API, rather than here.
  _asyncEmailDataExport() async {
    DataSourceResponse? res = await widget.source.exportAllRows(_exportType);

    if (res != null) {
      setState(() {
        _emailSuccess = true;
        _exporting = false;
      });
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Error exporting data. Please try again later."),
        backgroundColor: Color.fromRGBO(226, 106, 103, 1),
      ));
    }
  }

  /// Export all source data for a grid as a .csv, to be downloaded immediately by the user
  _allPageDataExport() async {
    DataSourceResponse? allRows = await widget.source.exportAllRows(_exportType);

    if (allRows != null) {
      setState(() {
        _rows = allRows.items;
      });
    } else {
      setState(() {
        _rows = [];
      });
    }

    _exportDataToCsv();
  }

  /// Export the data currently displayed in the grid as a .csv, to be downloaded immediately by the user
  _exportDataToCsv() {
    List<String> headings = [];
    List<List<dynamic>> rowsToExport = [];

    for (DataGridColumn column in _columns) {
      // If the column has a custom export title, then use that as the .csv
      // heading
      if (column.exportTitleReplacementString != null) {
        headings.add(column.exportTitleReplacementString!.replaceAll('"', '""'));
      } else {
        headings.add(column.title.replaceAll('"', '""'));
      }
    }

    rowsToExport.add(headings);

    for (Map<String, dynamic> row in _rows) {
      List<String> rowValues = [];

      for (DataGridColumn column in _columns) {
        // If the column has a custom function to convert its data into a
        // String for export, then call it here instead of using default methods
        if (column.exportReplacementString != null) {
          rowValues.add(column.exportReplacementString!(row, row[column.column]).replaceAll('"', '""'));
          continue;
        }

        Widget cell = column.builder(row, row[column.column], 0);

        if (cell.runtimeType == Text) {
          rowValues.add((cell as Text).data!.replaceAll('"', '""'));
        } else {
          rowValues.add(row[column.column].replaceAll('"', '""'));
        }
      }

      rowsToExport.add(rowValues);
    }

    String exportCsv = const ListToCsvConverter(fieldDelimiter: ',', textDelimiter: '"', textEndDelimiter: '"', eol: '\r\n').convert(rowsToExport);

    final bytes = utf8.encode(exportCsv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = '${widget.title}.csv';
    html.document.body!.children.add(anchor);

    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _loading ? Colors.transparent : null,
      elevation: _loading ? 0 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: _loading || _exporting
          ? Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: widget.primaryColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _loading ? "Loading Export Details..." : "Exporting ${widget.title != "" ? widget.title : "Grid Data"}...",
                      style: TextStyle(color: widget.primaryColor, fontSize: 14),
                    ),
                  )
                ],
              ),
            )
          : _emailSuccess
              ? Container(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 600,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: const [
                          Expanded(
                            child: Text(
                              "Export Successful",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(54, 54, 54, 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: widget.primaryColor,
                        size: 48,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Export of ${widget.title} was successful.",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          color: Color.fromRGBO(54, 54, 54, 1),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: const Text(
                          "You will receive an email to your account's email address with the results of the Export.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            child: const Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: widget.overrideButtonStyle ?? (Theme.of(context).elevatedButtonTheme.style ?? ElevatedButton.styleFrom()),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 600,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MediaQuery.of(context).size.width > 450 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
                        children: [
                          if (MediaQuery.of(context).size.width > 450) ...[
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.download, color: widget.primaryColor),
                                  const SizedBox(width: 10),
                                  SelectableText(
                                    "Export ${widget.title}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color.fromRGBO(54, 54, 54, 1),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close_rounded),
                            color: const Color.fromRGBO(54, 54, 54, 1),
                            padding: const EdgeInsets.all(5),
                            splashRadius: 20,
                          ),
                        ],
                      ),

                      if (MediaQuery.of(context).size.width <= 450) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.download, color: widget.primaryColor),
                            const SizedBox(width: 10),
                            SelectableText(
                              "Export ${widget.title}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color.fromRGBO(54, 54, 54, 1),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: MediaQuery.of(context).size.width <= 450 ? 15 : 10),

                      // Column widget containing different export options available
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Current page data export
                          widget.exportTypes.contains(DataGridExportType.currentPage)
                              ? RadioListTile<DataGridExportType>(
                                  title: const Text('Current Page'),
                                  activeColor: widget.primaryColor,
                                  tileColor: _exportType == DataGridExportType.currentPage ? widget.primaryColor.withOpacity(0.1) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  groupValue: _exportType,
                                  value: DataGridExportType.currentPage,
                                  onChanged: (DataGridExportType? value) {
                                    setState(() {
                                      _exportType = value!;
                                    });
                                  },
                                )
                              : Container(),
                          // Add a small box for spacing if DataGridExportType.currentPage is active
                          SizedBox(height: widget.exportTypes.contains(DataGridExportType.currentPage) ? 5 : 0),

                          // All pages data export
                          widget.exportTypes.contains(DataGridExportType.allPages)
                              ? RadioListTile<DataGridExportType>(
                                  title: const Text('All Pages'),
                                  activeColor: widget.primaryColor,
                                  tileColor: _exportType == DataGridExportType.allPages ? widget.primaryColor.withOpacity(0.1) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  groupValue: _exportType,
                                  value: DataGridExportType.allPages,
                                  onChanged: (DataGridExportType? value) {
                                    setState(() {
                                      _exportType = value!;
                                    });
                                  },
                                )
                              : Container(),

                          // All pages data export to email
                          widget.exportTypes.contains(DataGridExportType.asyncEmail)
                              ? RadioListTile<DataGridExportType>(
                                  title: const Text("Email All Pages (Sent to your Account's Email)"),
                                  activeColor: widget.primaryColor,
                                  tileColor: _exportType == DataGridExportType.allPages ? widget.primaryColor.withOpacity(0.1) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  groupValue: _exportType,
                                  value: DataGridExportType.asyncEmail,
                                  onChanged: (DataGridExportType? value) {
                                    setState(() {
                                      _exportType = value!;
                                    });
                                  },
                                )
                              : Container(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row Widget with buttons to either 1. cancel export 2. export data
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                            },
                            style: widget.overrideButtonStyle != null
                                ? widget.overrideButtonStyle!
                                    .copyWith(backgroundColor: MaterialStateProperty.all(const Color.fromRGBO(243, 243, 243, 1.0)))
                                : Theme.of(context).elevatedButtonTheme.style != null
                                    ? Theme.of(context)
                                        .elevatedButtonTheme
                                        .style!
                                        .copyWith(backgroundColor: MaterialStateProperty.all(const Color.fromRGBO(243, 243, 243, 1.0)))
                                    : ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(243, 243, 243, 1.0)),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(color: Color.fromRGBO(105, 105, 105, 1)),
                            ),
                          ),
                          if (MediaQuery.of(context).size.width > 450) ...[
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _exporting = true;
                                });

                                switch (_exportType) {
                                  case DataGridExportType.currentPage:
                                    _exportDataToCsv();
                                    break;
                                  case DataGridExportType.allPages:
                                    _allPageDataExport();
                                    break;
                                  case DataGridExportType.asyncEmail:
                                    _asyncEmailDataExport();
                                    break;
                                }
                              },
                              style: widget.overrideButtonStyle != null
                                  ? widget.overrideButtonStyle!.copyWith(backgroundColor: MaterialStateProperty.all(widget.primaryColor))
                                  : Theme.of(context).elevatedButtonTheme.style != null
                                      ? Theme.of(context)
                                          .elevatedButtonTheme
                                          .style!
                                          .copyWith(backgroundColor: MaterialStateProperty.all(widget.primaryColor))
                                      : ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
                              child: const Text(
                                "EXPORT DATA",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ]
                        ],
                      ),
                      if (MediaQuery.of(context).size.width <= 450) ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _exporting = true;
                            });

                            switch (_exportType) {
                              case DataGridExportType.currentPage:
                                _exportDataToCsv();
                                break;
                              case DataGridExportType.allPages:
                                _allPageDataExport();
                                break;
                              case DataGridExportType.asyncEmail:
                                _asyncEmailDataExport();
                                break;
                            }
                          },
                          style: widget.overrideButtonStyle != null
                              ? widget.overrideButtonStyle!.copyWith(backgroundColor: MaterialStateProperty.all(widget.primaryColor))
                              : Theme.of(context).elevatedButtonTheme.style != null
                                  ? Theme.of(context)
                                      .elevatedButtonTheme
                                      .style!
                                      .copyWith(backgroundColor: MaterialStateProperty.all(widget.primaryColor))
                                  : ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
                          child: const Text(
                            "EXPORT DATA",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
    );
  }
}
