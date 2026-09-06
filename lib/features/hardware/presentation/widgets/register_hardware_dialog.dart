import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../shifts/domain/entities/register.dart';
import '../../domain/entities/register_hardware_profile.dart';
import '../providers/hardware_providers.dart';

class RegisterHardwareDialog extends ConsumerStatefulWidget {
  const RegisterHardwareDialog({required this.register, super.key});

  final Register register;

  @override
  ConsumerState<RegisterHardwareDialog> createState() =>
      _RegisterHardwareDialogState();
}

class _RegisterHardwareDialogState
    extends ConsumerState<RegisterHardwareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _timeoutController = TextEditingController();
  final _suppressionController = TextEditingController();
  BarcodeScannerType _scannerType = BarcodeScannerType.keyboardWedge;
  ReceiptPrinterType _printerType = ReceiptPrinterType.screen;
  int _paperWidth = 80;
  bool _drawerEnabled = false;
  int _drawerPin = 0;
  int _expectedVersion = 0;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _suppressionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(
      registerHardwareProfileProvider(widget.register.id),
    );
    return AlertDialog(
      title: Text('${widget.register.name} hardware'),
      content: SizedBox(
        width: 560,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Configuration unavailable: $error'),
          data: (profile) {
            _initialize(
              profile ?? RegisterHardwareProfile.defaults(widget.register.id),
            );
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Barcode scanner',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BarcodeScannerType>(
                      initialValue: _scannerType,
                      decoration: const InputDecoration(labelText: 'Scanner'),
                      items: BarcodeScannerType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _scannerType = value!),
                    ),
                    if (_scannerType == BarcodeScannerType.camera) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Camera scanning is reserved for mobile workflows and is not enabled for checkout.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _timeoutController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Character timeout (ms)',
                            ),
                            validator: (value) => _integerRange(
                              value,
                              20,
                              1000,
                              'Enter 20–1000.',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _suppressionController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duplicate guard (ms)',
                            ),
                            validator: (value) =>
                                _integerRange(value, 0, 5000, 'Enter 0–5000.'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Receipt printer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<ReceiptPrinterType>(
                      initialValue: _printerType,
                      decoration: const InputDecoration(labelText: 'Output'),
                      items: ReceiptPrinterType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _printerType = value!;
                              if (value == ReceiptPrinterType.screen) {
                                _drawerEnabled = false;
                              }
                            }),
                    ),
                    if (_printerType == ReceiptPrinterType.networkEscPos) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Printer host or IP',
                                hintText: '192.168.1.50',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a printer address.'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextFormField(
                              controller: _portController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                              ),
                              validator: (value) => _integerRange(
                                value,
                                1,
                                65535,
                                'Invalid port.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 58, label: Text('58 mm')),
                          ButtonSegment(value: 80, label: Text('80 mm')),
                        ],
                        selected: {_paperWidth},
                        onSelectionChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _paperWidth = value.single),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Printer-connected cash drawer'),
                        subtitle: const Text(
                          'Opens only after an authorized completed cash sale.',
                        ),
                        value: _drawerEnabled,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _drawerEnabled = value),
                      ),
                      if (_drawerEnabled)
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('Pin 2')),
                            ButtonSegment(value: 1, label: Text('Pin 5')),
                          ],
                          selected: {_drawerPin},
                          onSelectionChanged: _saving
                              ? null
                              : (value) =>
                                    setState(() => _drawerPin = value.single),
                        ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || profileAsync.value == null ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save hardware'),
        ),
      ],
    );
  }

  void _initialize(RegisterHardwareProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _scannerType = profile.scannerType;
    _printerType = profile.printerType;
    _addressController.text = profile.printerAddress ?? '';
    _portController.text = profile.printerPort.toString();
    _timeoutController.text = profile.scannerInterCharacterTimeoutMs.toString();
    _suppressionController.text = profile.scannerDuplicateSuppressionMs
        .toString();
    _paperWidth = profile.printerPaperWidthMm;
    _drawerEnabled = profile.cashDrawerEnabled;
    _drawerPin = profile.cashDrawerPin;
    _expectedVersion = profile.version;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(configureRegisterHardwareUseCaseProvider)(
      session: ref.read(authControllerProvider).asData?.value,
      draft: RegisterHardwareProfileDraft(
        registerId: widget.register.id,
        scannerType: _scannerType,
        scannerInterCharacterTimeoutMs: int.parse(_timeoutController.text),
        scannerDuplicateSuppressionMs: int.parse(_suppressionController.text),
        printerType: _printerType,
        printerAddress: _addressController.text,
        printerPort: int.parse(_portController.text),
        printerPaperWidthMm: _paperWidth,
        cashDrawerEnabled: _drawerEnabled,
        cashDrawerPin: _drawerPin,
        expectedVersion: _expectedVersion,
      ),
    );
    if (!mounted) return;
    if (result case FailureResult(:final failure)) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.pop(context, true);
  }
}

String? _integerRange(String? value, int min, int max, String message) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < min || parsed > max ? message : null;
}
