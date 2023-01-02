import 'package:country_code_picker/country_code_picker.dart';

import 'datasource.dart';
import 'types.dart';
import 'advanced_data_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FilterBool extends StatefulWidget {
  const FilterBool({
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
  State<FilterBool> createState() => _FilterBoolState();
}

class _FilterBoolState extends State<FilterBool> {
  List<DataFilter> _filters = [];
  bool _boolSelection = false;

  @override
  void initState() {
    super.initState();

    var loadedFilters = widget.source.getFilters(widget.data.filterColumnName ?? widget.data.column);
    var filters = loadedFilters == null || loadedFilters.isEmpty ? <DataFilter>[] : loadedFilters;

    if (filters.isNotEmpty) {
      setState(() {
        _boolSelection = filters.first.value == "true" ? true : false;
      });
    }

    setState(() {
      _filters = filters;
    });
  }

  void save() {
    List<DataFilter> filters = [];
    filters.add(DataFilter(operator: null, value: _boolSelection.toString()));

    widget.source.setFilters(widget.data.filterColumnName ?? widget.data.column, filters);
    Navigator.of(context, rootNavigator: true).pop();
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
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.data.title,
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Transform.scale(
                scale: 0.8,
                child: CupertinoSwitch(
                  value: _boolSelection,
                  onChanged: (bool v) {
                    setState(() {
                      _boolSelection = v;
                    });
                  },
                ),
              ),
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
