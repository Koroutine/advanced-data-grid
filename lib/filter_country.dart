import 'package:country_code_picker/country_code_picker.dart';

import 'datasource.dart';
import 'types.dart';
import 'advanced_data_grid.dart';
import 'package:flutter/material.dart';

class FilterCountry extends StatefulWidget {
  const FilterCountry({
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
  State<FilterCountry> createState() => _FilterCountryState();
}

class _FilterCountryState extends State<FilterCountry> {
  List<DataFilter> _filters = [];
  late CountryCode _selectedCountry;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    var loadedFilters = widget.source.getFilters(widget.data.filterColumnName ?? widget.data.column);
    var filters = loadedFilters == null || loadedFilters.isEmpty ? [DataFilter(operator: DataFilterOperator.EQ)] : loadedFilters;

    if (filters.isNotEmpty) {
      setState(() {
        _selectedCountry = CountryCode.fromCountryCode(filters[0].value ?? "GB");
      });
    } else {
      _selectedCountry = CountryCode.fromCountryCode("GB");
    }

    setState(() {
      _filters = filters;
      _loading = false;
    });
  }

  void save() {
    List<DataFilter> filters = [];
    filters.add(DataFilter(operator: null, value: _selectedCountry.code));

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

    return _loading
        ? Container()
        : Column(
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
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(249, 249, 249, 1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color.fromRGBO(141, 141, 141, 1), width: 0.5),
                  ),
                  child: CountryCodePicker(
                    searchDecoration: const InputDecoration(hintText: "Search Countries"),
                    showCountryOnly: true,
                    showOnlyCountryWhenClosed: true,
                    initialSelection: _selectedCountry.code ?? "GB",
                    favorite: const ['+44', '+353'],
                    alignLeft: true,
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    flagWidth: 24,
                    showDropDownButton: true,
                    onChanged: (country) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    },
                    closeIcon: const Icon(Icons.close_rounded, size: 30, color: Colors.black87),
                    dialogSize: Size(
                      MediaQuery.of(context).size.width > 500 ? 500 : MediaQuery.of(context).size.width * 0.9,
                      MediaQuery.of(context).size.height * 0.8,
                    ),
                    dialogTextStyle: const TextStyle(
                      fontSize: 16,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontFamily: "Montserrat",
                    ),
                    searchStyle: const TextStyle(
                      fontSize: 15,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
