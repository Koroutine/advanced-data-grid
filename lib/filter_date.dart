import 'package:intl/intl.dart';

import 'datasource.dart';
import 'types.dart';
import 'advanced_data_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FilterDate extends StatefulWidget {
  const FilterDate({
    super.key,
    required this.filterType,
    required this.source,
    required this.data,
    required this.primaryColor,
  });

  final DataSource source;
  final DataGridColumn data;
  final DataFilterType filterType;
  final Color primaryColor;

  @override
  State<FilterDate> createState() => _FilterDateState();
}

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

class _FilterDateState extends State<FilterDate> {
  List<DataFilter> _filters = [];
  DateTimeRange? _dateTimeRange;
  bool _filterRange = false;

  @override
  void initState() {
    super.initState();

    var loadedFilters = widget.source.getFilters(widget.data.filterColumnName ?? widget.data.column);
    var filters = loadedFilters == null || loadedFilters.isEmpty ? <DataFilter>[] : loadedFilters;

    if (filters.isNotEmpty) {
      DateTime? startDate = DateTime.tryParse(filters[0].value!);
      DateTime? endDate = DateTime.tryParse(filters[1].value!);

      if (startDate != null && endDate != null) {
        setState(() {
          _dateTimeRange = DateTimeRange(start: startDate, end: endDate);
        });

        if (!startDate.isSameDate(endDate)) {
          setState(() {
            _filterRange = true;
          });
        }
      }
    }

    setState(() {
      _filters = filters;
    });
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(0000, 01, 01),
      lastDate: DateTime(9999, 12, 31),
    ).then((pickedDate) {
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _dateTimeRange = DateTimeRange(
            start: DateTime(pickedDate.year, pickedDate.month, pickedDate.day),
            end: DateTime(pickedDate.year, pickedDate.month, pickedDate.day + 1).subtract(const Duration(microseconds: 1)));
      });
    });
  }

  void _presentDateRangePicker() {
    showDateRangePicker(
      context: context,
      initialDateRange: _dateTimeRange,
      firstDate: DateTime(0000, 01, 01),
      lastDate: DateTime(9999, 12, 31),
    ).then((pickedRange) {
      if (pickedRange == null) {
        return;
      }
      setState(() {
        _dateTimeRange = DateTimeRange(
            start: DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day),
            end: DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day + 1).subtract(const Duration(microseconds: 1)));
      });
    });
  }

  void save() {
    List<DataFilter> filters = [];

    if (_dateTimeRange != null) {
      filters.add(DataFilter(operator: DataFilterOperator.GTE, value: _dateTimeRange!.start.toIso8601String()));
      filters.add(DataFilter(operator: DataFilterOperator.LTE, value: _dateTimeRange!.end.toIso8601String()));
    }

    if (filters.isNotEmpty) {
      widget.source.setFilters(widget.data.filterColumnName ?? widget.data.column, filters);
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      clear();
    }
  }

  void clear() {
    widget.source.removefilters(
      widget.data.filterColumnName ?? widget.data.column,
    );

    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    var hasFilters = _filters.where((e) => e.value != null).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Filter ${widget.data.title}",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              const Expanded(
                child: Text("Filter Range?"),
              ),
              const SizedBox(width: 10),
              CupertinoSwitch(
                value: _filterRange,
                onChanged: (bool v) {
                  setState(() {
                    _filterRange = v;
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  width: 240,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dateTimeRange != null
                                      ? DateFormat('dd/MM/yyyy').format(_dateTimeRange!.start)
                                      : _filterRange
                                          ? "Select Start Date"
                                          : "Select Date",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              _filterRange ? Container(padding: const EdgeInsets.symmetric(horizontal: 10), child: const Text(" - ")) : Container(),
                              _filterRange
                                  ? Expanded(
                                      child: Text(
                                        _dateTimeRange != null ? DateFormat('dd/MM/yyyy').format(_dateTimeRange!.end) : "Select End Date",
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                          onPressed: () => _filterRange ? _presentDateRangePicker : _presentDatePicker,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => clear(),
              child: Text(
                hasFilters ? "Clear" : "Cancel",
                style: TextStyle(
                  color: widget.primaryColor,
                ),
              ),
            ),
            Expanded(
              child: Container(),
            ),
            TextButton(
              onPressed: () => save(),
              child: Text(
                "OK",
                style: TextStyle(
                  color: widget.primaryColor,
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
