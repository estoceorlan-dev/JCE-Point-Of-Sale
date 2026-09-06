enum BarcodeScannerType {
  disabled('disabled', 'Disabled'),
  keyboardWedge('keyboard_wedge', 'Keyboard wedge'),
  camera('camera', 'Camera');

  const BarcodeScannerType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static BarcodeScannerType fromDatabase(String value) => values.firstWhere(
    (candidate) => candidate.databaseValue == value,
    orElse: () => BarcodeScannerType.keyboardWedge,
  );
}

enum ReceiptPrinterType {
  screen('screen', 'Screen / PDF only'),
  networkEscPos('network_esc_pos', 'Network ESC/POS');

  const ReceiptPrinterType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ReceiptPrinterType fromDatabase(String value) => values.firstWhere(
    (candidate) => candidate.databaseValue == value,
    orElse: () => ReceiptPrinterType.screen,
  );
}

class RegisterHardwareProfile {
  const RegisterHardwareProfile({
    required this.registerId,
    required this.scannerType,
    required this.scannerInterCharacterTimeoutMs,
    required this.scannerDuplicateSuppressionMs,
    required this.printerType,
    required this.printerPort,
    required this.printerPaperWidthMm,
    required this.cashDrawerEnabled,
    required this.cashDrawerPin,
    required this.version,
    this.printerAddress,
  });

  factory RegisterHardwareProfile.defaults(String registerId) =>
      RegisterHardwareProfile(
        registerId: registerId,
        scannerType: BarcodeScannerType.keyboardWedge,
        scannerInterCharacterTimeoutMs: 80,
        scannerDuplicateSuppressionMs: 350,
        printerType: ReceiptPrinterType.screen,
        printerPort: 9100,
        printerPaperWidthMm: 80,
        cashDrawerEnabled: false,
        cashDrawerPin: 0,
        version: 0,
      );

  final String registerId;
  final BarcodeScannerType scannerType;
  final int scannerInterCharacterTimeoutMs;
  final int scannerDuplicateSuppressionMs;
  final ReceiptPrinterType printerType;
  final String? printerAddress;
  final int printerPort;
  final int printerPaperWidthMm;
  final bool cashDrawerEnabled;
  final int cashDrawerPin;
  final int version;

  bool get hasPhysicalPrinter =>
      printerType == ReceiptPrinterType.networkEscPos;
}

class RegisterHardwareProfileDraft {
  const RegisterHardwareProfileDraft({
    required this.registerId,
    required this.scannerType,
    required this.scannerInterCharacterTimeoutMs,
    required this.scannerDuplicateSuppressionMs,
    required this.printerType,
    required this.printerPort,
    required this.printerPaperWidthMm,
    required this.cashDrawerEnabled,
    required this.cashDrawerPin,
    required this.expectedVersion,
    this.printerAddress,
  });

  final String registerId;
  final BarcodeScannerType scannerType;
  final int scannerInterCharacterTimeoutMs;
  final int scannerDuplicateSuppressionMs;
  final ReceiptPrinterType printerType;
  final String? printerAddress;
  final int printerPort;
  final int printerPaperWidthMm;
  final bool cashDrawerEnabled;
  final int cashDrawerPin;
  final int expectedVersion;
}
