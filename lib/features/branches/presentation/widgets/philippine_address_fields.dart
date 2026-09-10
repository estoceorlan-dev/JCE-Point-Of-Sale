import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/philippine_address_catalog.dart';
import '../providers/branches_providers.dart';

class PhilippineAddressFields extends ConsumerStatefulWidget {
  const PhilippineAddressFields({
    super.key,
    required this.provinceController,
    required this.cityController,
    required this.postalCodeController,
  });

  final TextEditingController provinceController;
  final TextEditingController cityController;
  final TextEditingController postalCodeController;

  @override
  ConsumerState<PhilippineAddressFields> createState() =>
      _PhilippineAddressFieldsState();
}

class _PhilippineAddressFieldsState
    extends ConsumerState<PhilippineAddressFields> {
  String? _selectedProvince;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedProvince = _nonBlank(widget.provinceController.text);
    _selectedCity = _nonBlank(widget.cityController.text);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(philippineAddressCatalogProvider);

    return catalog.when(
      data: _dropdowns,
      loading: () => _locationRow(
        province: const _LoadingLocationField(label: 'Province / area'),
        city: const _LoadingLocationField(label: 'City / municipality'),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Philippine locations could not be loaded. Enter the address manually.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _locationRow(
            province: _field(widget.provinceController, 'Province / area'),
            city: _field(widget.cityController, 'City / municipality'),
          ),
        ],
      ),
    );
  }

  Widget _dropdowns(PhilippineAddressCatalog catalog) {
    final selectedArea = catalog.areaNamed(_selectedProvince);
    final provinceNames = catalog.areas.map((area) => area.name).toSet();
    final localityNames =
        selectedArea?.localities.map((locality) => locality.name).toSet() ??
        const <String>{};
    final hasSavedProvince =
        _selectedProvince != null && !provinceNames.contains(_selectedProvince);
    final hasSavedCity =
        _selectedCity != null && !localityNames.contains(_selectedCity);

    final province = DropdownButtonFormField<String?>(
      key: ValueKey('branch-province-dropdown-$_selectedProvince'),
      initialValue: _selectedProvince,
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: const InputDecoration(labelText: 'Province / area'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Not specified'),
        ),
        for (final area in catalog.areas)
          DropdownMenuItem<String?>(
            value: area.name,
            child: Text(area.name, overflow: TextOverflow.ellipsis),
          ),
        if (hasSavedProvince)
          DropdownMenuItem<String?>(
            value: _selectedProvince,
            child: Text(
              '${_selectedProvince!} (saved value)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (province) {
        setState(() {
          _selectedProvince = province;
          _selectedCity = null;
          widget.provinceController.text = province ?? '';
          widget.cityController.clear();
        });
      },
    );

    final city = DropdownButtonFormField<String?>(
      key: ValueKey('branch-city-dropdown-$_selectedProvince-$_selectedCity'),
      initialValue: _selectedCity,
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: const InputDecoration(labelText: 'City / municipality'),
      hint: Text(
        _selectedProvince == null
            ? 'Select province first'
            : 'Select city / municipality',
        overflow: TextOverflow.ellipsis,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Not specified'),
        ),
        for (final locality
            in selectedArea?.localities ?? const <PhilippineLocality>[])
          DropdownMenuItem<String?>(
            value: locality.name,
            child: Text(locality.name, overflow: TextOverflow.ellipsis),
          ),
        if (hasSavedCity)
          DropdownMenuItem<String?>(
            value: _selectedCity,
            child: Text(
              '${_selectedCity!} (saved value)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _selectedProvince == null
          ? null
          : (city) {
              setState(() {
                _selectedCity = city;
                widget.cityController.text = city ?? '';
              });
            },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Philippine address · PSGC ${catalog.release}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _locationRow(province: province, city: city),
      ],
    );
  }

  Widget _locationRow({required Widget province, required Widget city}) {
    final postalCode = _field(widget.postalCodeController, 'Postal code');

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              province,
              const SizedBox(height: AppSpacing.md),
              city,
              const SizedBox(height: AppSpacing.md),
              postalCode,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: province),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: city),
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: 130, child: postalCode),
          ],
        );
      },
    );
  }

  TextFormField _field(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _LoadingLocationField extends StatelessWidget {
  const _LoadingLocationField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

String? _nonBlank(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
