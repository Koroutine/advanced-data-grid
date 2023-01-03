import 'dart:collection';
import 'dart:convert';

import 'types.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;
typedef DataSourceLoader = Future<DataSourceResponse?> Function(int page, int limit);

class DataSourceResponse {
  List<Json> items = [];
  num page = 0;
  num pageSize = 0;
  num total = 0;
  Map<String, dynamic> json;

  DataSourceResponse(
    this.items,
    this.page,
    this.pageSize,
    this.total,
    this.json,
  );

  factory DataSourceResponse.fromJson(String body, String? responseListKey, num currentPage) {
    try {
      return DataSourceResponse.fromMap(
        jsonDecode(body),
        responseListKey,
        currentPage,
      );
    } catch (err) {
      print("DataSourceResponse.fromBody: $err: $body");
      rethrow;
    }
  }

  factory DataSourceResponse.fromMap(Map<String, dynamic> json, String? responseListKey, num currentPage) {
    var items;
    if (responseListKey != null) {
      items = ((json[responseListKey] as List).map((e) => e as Map<String, dynamic>).toList());
    } else {
      items = ((json as List).map((e) => e as Map<String, dynamic>).toList());
    }

    return DataSourceResponse(items, currentPage, json['pageSize'] as num? ?? 15, json['rows'] as num? ?? 0, json);
  }
}

enum DataFilterOperator { EQ, GT, GTE, LT, LTE }

class DataFilter {
  DataFilterOperator? operator;
  String? value;

  DataFilter({this.operator, this.value});
}

abstract class DataSource extends ChangeNotifier {
  final List<Json> _items = [];
  num _currentPageSize = 0;
  num _currentTotal = 0;

  // Inputs
  bool _isLoading = false;
  num _page;
  num _pageLimit;
  Map<String, String> _sort;
  Map<String, List<DataFilter>> _filter;

  DataSource(this._page, this._pageLimit, this._sort, this._filter);

  UnmodifiableListView<Json> get items => UnmodifiableListView(_items);
  bool get isLoading => _isLoading;

  String? getSort(String column) {
    return _sort[column];
  }

  bool hasFilters(String column) {
    return _filter[column] != null && _filter[column]!.isNotEmpty;
  }

  List<DataFilter>? getFilters(String column) {
    return _filter[column];
  }

  num get currentPage => _page;
  num get lastPage => (_currentTotal / _pageLimit).ceil();
  num get pageSize => _pageLimit;
  num get totalCount => _currentTotal;
  Map<String, String> get columnSorts => _sort;

  List<num> get pagination {
    List<num> values = [];

    if (currentPage > 50) {
      values.add(currentPage - 50);
    }

    if (currentPage > 25) {
      values.add(currentPage - 25);
    }

    values.add(currentPage);

    if (currentPage < lastPage - 25) {
      values.add(currentPage + 25);
    }

    if (currentPage < lastPage - 50) {
      values.add(currentPage + 50);
    }

    return values;
  }

  Future<void> setFilters(String column, List<DataFilter> filters) async {
    _filter[column] = filters;

    notifyListeners();

    return refresh();
  }

  Future<void> setPageLimit(num limit) {
    _pageLimit = limit;

    notifyListeners();
    return refresh();
  }

  Future<void> removefilters(String column) async {
    if (_filter[column] == null) {
      return;
    }

    _filter[column] = [];

    notifyListeners();

    return refresh();
  }

  Future<void> removefilter(int index, String column) async {
    if (_filter[column] == null || _filter.length <= index) {
      return;
    }

    _filter[column]!.removeAt(index);

    notifyListeners();

    return refresh();
  }

  Future<void> addSort(String column, direction) async {
    _sort[column] = direction;

    return refresh();
  }

  Future<void> removeSort(String column) async {
    _sort.remove(column);

    return refresh();
  }

  Future<void> replaceAllSorts(String column, direction) async {
    _sort.clear();
    _sort[column] = direction;

    return refresh();
  }

  Future<void> loadPage(num page) async {
    _page = page;
    return refresh();
  }

  Future<DataSourceResponse?> exportAllRows(DataGridExportType exportType) async {
    var res = await loader(exportType);

    return res;
  }

  Future<void> refresh() async {
    _isLoading = true;

    // Notifiy of any state changes
    notifyListeners();

    var res = await loader(null);

    if (res == null) {
      _items.clear();
      _isLoading = false;
      _currentTotal = 0;
      _page = 1;

      notifyListeners();
      return;
    }

    _items.clear();
    _items.addAll(res.items);
    _isLoading = false;
    _currentPageSize = res.pageSize;
    _currentTotal = res.total;
    _page = res.page;

    notifyListeners();
  }

  Future<DataSourceResponse?> loader(DataGridExportType? exportType) async {
    throw UnimplementedError();
  }

  @override
  String toString() {
    return "page: $currentPage, lastPage: $lastPage, currentTotal: $_currentTotal, currentPageSize: $_currentPageSize, pagination: $pagination";
  }
}

class DataSourceApi extends DataSource {
  DataSourceApi({
    required this.domain,
    required this.path,
    this.responseListKey,
    required this.defaultSortOrder,
    this.query,
    this.tokenSharedPref,
    this.onInvalidToken,
    this.exportQueryParameter,
  }) : super(0, 15, defaultSortOrder, {});

  /// Domain Name of the API to call including http/https.
  final String domain;

  /// Path of API to call.
  final String path;

  /// Key Name in response JSON that holds the Rows.
  final String? responseListKey;

  /// Sort Order to apply to the API Call by default.
  final Map<String, String> defaultSortOrder;

  /// List of Query Parameters to add to each API Call.
  final Map<String, List<String>>? query;

  /// Shared Prefs name where Bearer Auth token is stored.
  final String? tokenSharedPref;

  /// Function to call if token has expired/is invalid.
  final Function? onInvalidToken;

  /// Extra Parameter to add when exporting using DataGridExportType.asyncEmail.
  final Map<String, List<String>>? exportQueryParameter;

  @override
  Future<DataSourceResponse?> loader(DataGridExportType? exportType) async {
    late SharedPreferences prefs;
    String? token;
    if (tokenSharedPref != null) {
      prefs = await SharedPreferences.getInstance();
      token = prefs.getString(tokenSharedPref!);
    }

    print("Getting: $path");

    var urlQuery;

    switch (exportType) {
      case DataGridExportType.allPages:
        urlQuery = {
          'page': ["1"],
          'limit': ["$_currentTotal"],
          'sort': _sort.entries.map((e) => "${e.key}:${e.value}").toList(),
        };
        break;
      case DataGridExportType.asyncEmail:
        urlQuery = {
          'sort': _sort.entries.map((e) => "${e.key}:${e.value}").toList(),
        };

        if (exportQueryParameter != null) {
          urlQuery.addAll(exportQueryParameter);
        }
        break;
      default:
        urlQuery = {
          'page': ["$_page"],
          'limit': ["$_pageLimit"],
          'sort': _sort.entries.map((e) => "${e.key}:${e.value}").toList(),
        };
        break;
    }

    if (query != null) {
      urlQuery.addAll(query!);
    }

    // add filters
    for (var e in _filter.entries) {
      var key = e.key;
      var values = e.value;

      if (values.isNotEmpty) {
        urlQuery[key] = values
            .where((e) => e.value != null)
            .map((e) => e.operator == null ? e.value! : "${e.operator.toString().split(".").last.toLowerCase()}:${e.value}")
            .toList();
      }
    }

    print(query);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers.addAll({
        'Authorization': 'Bearer $token',
      });
    }

    Response r = await get(Uri.parse(domain + path).replace(queryParameters: urlQuery), headers: headers);

    if (r.statusCode == 200) {
      if (exportType == DataGridExportType.asyncEmail) {
        return DataSourceResponse([], 1, 1, 1, {});
      }

      var data = DataSourceResponse.fromJson(r.body, responseListKey, _page);
      return data;
    }

    if (r.statusCode == 401) {
      if (onInvalidToken != null) {
        onInvalidToken!();
      }
    }

    return null;
  }
}
