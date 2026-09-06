import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/barcode_scan.dart';
import '../../domain/services/barcode_scanner.dart';

class KeyboardWedgeBarcodeScanner implements BarcodeScanner {
  KeyboardWedgeBarcodeScanner({
    required this.interCharacterTimeout,
    required this.duplicateSuppression,
    this.minimumLength = 3,
  });

  final Duration interCharacterTimeout;
  final Duration duplicateSuppression;
  final int minimumLength;
  final StreamController<BarcodeScan> _controller =
      StreamController<BarcodeScan>.broadcast();

  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyAt;
  DateTime? _lastEmittedAt;
  String? _lastEmittedValue;
  bool _started = false;

  @override
  Stream<BarcodeScan> get scans => _controller.stream;

  @override
  Future<Result<void, Failure>> start() async {
    _started = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> stop() async {
    _started = false;
    _clear();
    return const Result.success(null);
  }

  void acceptKey(String key, {DateTime? occurredAt}) {
    if (!_started || _controller.isClosed) return;
    final now = (occurredAt ?? DateTime.now()).toUtc();
    if (_lastKeyAt case final last?
        when now.difference(last) > interCharacterTimeout) {
      _clear();
    }
    _lastKeyAt = now;
    if (_isTerminator(key)) {
      _emit(now);
      return;
    }
    if (key == 'Backspace') {
      final current = _buffer.toString();
      _clear();
      if (current.isNotEmpty) {
        _buffer.write(current.substring(0, current.length - 1));
      }
      return;
    }
    if (key.length == 1 && key.codeUnitAt(0) >= 32) {
      _buffer.write(key);
    }
  }

  Future<void> dispose() => _controller.close();

  bool _isTerminator(String key) =>
      key == 'Enter' || key == 'Numpad Enter' || key == 'Tab';

  void _emit(DateTime now) {
    final value = _buffer.toString().trim();
    _clear();
    if (value.length < minimumLength) return;
    final lastEmittedAt = _lastEmittedAt;
    if (_lastEmittedValue == value &&
        lastEmittedAt != null &&
        now.difference(lastEmittedAt) <= duplicateSuppression) {
      return;
    }
    _lastEmittedValue = value;
    _lastEmittedAt = now;
    _controller.add(BarcodeScan(value: value, scannedAt: now));
  }

  void _clear() {
    _buffer.clear();
    _lastKeyAt = null;
  }
}
