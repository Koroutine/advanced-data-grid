import 'datasource.dart';
import 'types.dart';
import 'advanced_data_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FilterText extends StatefulWidget {
  const FilterText({
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
  State<FilterText> createState() => _FilterTextState();
}

class _FilterTextState extends State<FilterText> {
  List<TextEditingController> _valueControllers = [];
  List<DataFilterOperator?> _operators = [];
  List<DataFilter> _filters = [];
  dynamic _dropDownSelection;

  @override
  void initState() {
    super.initState();

    var loadedFilters = widget.source.getFilters(widget.data.filterColumnName ?? widget.data.column);
    var filters = loadedFilters == null || loadedFilters.isEmpty ? [DataFilter(operator: DataFilterOperator.EQ)] : loadedFilters;

    if (widget.filterType == DataFilterType.DROPDOWN) {
      setState(() {
        _dropDownSelection = filters[0].value;
      });
    }

    setState(() {
      _valueControllers = filters.map((e) => TextEditingController(text: e.value ?? "")).toList();
      _operators = filters.map((e) => e.operator).toList();
      _filters = filters;
    });
  }

  void save() {
    List<DataFilter> filters = [];

    switch (widget.filterType) {
      case DataFilterType.DROPDOWN:
        if (_dropDownSelection != null) {
          filters.add(DataFilter(operator: null, value: _dropDownSelection));
        }
        break;
      default:
        for (var i = 0; i < _valueControllers.length; i++) {
          if (_valueControllers[i].text != "") {
            filters.add(DataFilter(operator: widget.filterType != DataFilterType.STRING ? _operators[i] : null, value: _valueControllers[i].text));
          } else {
            widget.source.removefilter(i, widget.data.filterColumnName ?? widget.data.column);
          }
        }
        break;
    }

    if (filters.isNotEmpty) {
      widget.source.setFilters(widget.data.filterColumnName ?? widget.data.column, filters);
    }

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
        for (var i = 0; i < _valueControllers.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: widget.filterType == DataFilterType.DROPDOWN
                ? Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Object>(
                            alignment: Alignment.center,
                            items: widget.data.filterDropDownOptions!
                                .map((e) => DropdownMenuItem(
                                      value: e.values.first,
                                      child: Text(e.keys.first),
                                    ))
                                .toList(),
                            value: _dropDownSelection,
                            onChanged: (v) => setState(() {
                              _dropDownSelection = v;
                            }),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      widget.filterType != DataFilterType.STRING
                          ? Container(
                              padding: const EdgeInsets.only(right: 5),
                              width: 56,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<DataFilterOperator>(
                                  alignment: Alignment.center,
                                  items: DataFilterOperator.values
                                      .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e == DataFilterOperator.EQ
                                                  ? "="
                                                  : e == DataFilterOperator.GT
                                                      ? ">"
                                                      : e == DataFilterOperator.GTE
                                                          ? ">="
                                                          : e == DataFilterOperator.LT
                                                              ? "<"
                                                              : "<=",
                                              textAlign: TextAlign.center,
                                            ),
                                          ))
                                      .toList(),
                                  value: _operators[i],
                                  onChanged: (v) => setState(() {
                                    _operators[i] = v;
                                  }),
                                ),
                              ),
                            )
                          : Container(),
                      Expanded(
                        child: SizedBox(
                          width: 240,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _valueControllers[i],
                                  textAlignVertical: TextAlignVertical.center,
                                  onFieldSubmitted: (val) {
                                    save();
                                  },
                                  inputFormatters:
                                      widget.filterType == DataFilterType.NUMBER ? [FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))] : null,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                                    isDense: true,
                                    border: const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(141, 141, 141, 1), width: 0.5)),
                                    enabledBorder:
                                        const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(141, 141, 141, 1), width: 0.5)),
                                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.primaryColor)),
                                    errorMaxLines: 3,
                                    errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color.fromRGBO(226, 106, 103, 1))),
                                    focusColor: widget.primaryColor,
                                    fillColor: const Color.fromRGBO(249, 249, 249, 1),
                                    filled: true,
                                    hintText: "Search ${widget.data.title}...",
                                    hintStyle: const TextStyle(color: Color.fromRGBO(141, 141, 141, 1)),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: widget.primaryColor,
                                    ),
                                    constraints: const BoxConstraints(maxHeight: 240),
                                    disabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: const Color.fromRGBO(141, 141, 141, 1).withOpacity(0.5), width: 0.5)),
                                  ),
                                  textInputAction: TextInputAction.none,
                                ),
                              ),
                              widget.data.unitName != null
                                  ? Container(
                                      padding: const EdgeInsets.only(left: 10),
                                      child: Text(widget.data.unitName!),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
          ),
        /*widget.filterType == DataFilterType.NUMBER
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _valueControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add_circle_outline_rounded))
            : Container(),*/
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
