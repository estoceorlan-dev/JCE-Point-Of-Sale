import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/barcode_scan.dart';

abstract interface class BarcodeScanner {
  Stream<BarcodeScan> get scans;

  Future<Result<void, Failure>> start();

  Future<Result<void, Failure>> stop();
}
