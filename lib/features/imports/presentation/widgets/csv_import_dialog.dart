import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/csv_import.dart';
import '../providers/csv_import_providers.dart';

class CsvImportDialog extends ConsumerStatefulWidget {
  const CsvImportDialog({super.key, required this.kind});
  final CsvImportKind kind;
  @override
  ConsumerState<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  final _source = TextEditingController();
  CsvImportPreview? _preview;
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Import ${widget.kind.label.toLowerCase()}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close import',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.kind == CsvImportKind.catalog
                  ? 'Match products by SKU. Prices are organization-wide; existing branch prices are preserved. Separate barcodes with |.'
                  : 'Use opening stock only before a product/location has ledger history. Quantities use up to three decimal places.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose UTF-8 CSV'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _template,
                  icon: const Icon(Icons.download),
                  label: const Text('Download template'),
                ),
                if (_preview != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _preview = null),
                    child: const Text('Edit input'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_message!),
              ),
            Expanded(
              child: _preview == null
                  ? TextField(
                      controller: _source,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'CSV contents',
                        alignLabelWithHint: true,
                        hintText:
                            'Choose a file or paste CSV with its header row.',
                      ),
                    )
                  : _rows(_preview!),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_busy) const LinearProgressIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : _preview == null
                      ? _previewInput
                      : _preview!.canConfirm
                      ? _confirm
                      : null,
                  child: Text(
                    _preview == null
                        ? 'Preview import'
                        : 'Confirm ${_preview!.rows.length} rows',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _rows(CsvImportPreview preview) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${preview.rows.length} rows · ${preview.rows.where((row) => row.errors.isNotEmpty).length} rows need correction',
      ),
      const SizedBox(height: AppSpacing.sm),
      Expanded(
        child: ListView.builder(
          itemCount: preview.rows.length,
          itemBuilder: (_, index) {
            final row = preview.rows[index];
            return ListTile(
              leading: Icon(
                row.errors.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: row.errors.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text('Row ${row.number} · ${row.sku} · ${row.action}'),
              subtitle: row.errors.isEmpty ? null : Text(row.errors.join('\n')),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _openFile() async {
    setState(() => _busy = true);
    final result = await ref.read(csvFileServiceProvider).open();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.failureOrNull?.message;
    });
    final source = result.valueOrNull;
    if (source == null) return;
    _source.text = source;
    await _previewInput();
  }

  Future<void> _template() async {
    final result = await ref
        .read(csvFileServiceProvider)
        .saveTemplate('${widget.kind.name}_template.csv', widget.kind.template);
    if (!mounted) return;
    setState(
      () => _message =
          result.failureOrNull?.message ??
          (result.valueOrNull == null
              ? null
              : 'Template saved: ${result.valueOrNull}'),
    );
  }

  Future<void> _previewInput() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref
        .read(importCsvUseCaseProvider)
        .preview(
          session: ref.read(authControllerProvider).value,
          kind: widget.kind,
          source: _source.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = result.valueOrNull;
      _message = result.failureOrNull?.message;
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref
        .read(importCsvUseCaseProvider)
        .confirm(
          session: ref.read(authControllerProvider).value,
          preview: _preview!,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.failureOrNull?.message;
    });
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.valueOrNull == 0
                ? 'This file was already imported.'
                : '${result.valueOrNull} rows imported and queued for sync.',
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
