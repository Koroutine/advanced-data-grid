import 'package:flutter/material.dart';

enum DataFilterType { STRING, DATETIME, NUMBER, DROPDOWN, BOOLEAN, COUNTRY_CODE, COUNTRY_NAME }

typedef DataGridTitleBuilder = Widget Function(int index, String title);
typedef DataGridColumnBuilder = Widget Function(dynamic data, dynamic value, int index);
typedef DataGridExportString = String Function(dynamic data, dynamic value);

enum DataGridExportType { currentPage, allPages, asyncEmail }
