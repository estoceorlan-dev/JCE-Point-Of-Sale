import 'dart:convert';
import 'dart:typed_data';

abstract final class EscPosEncoder {
  static Uint8List receipt(String documentText) {
    final normalized = documentText
        .replaceAll('₱', 'PHP ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...');
    return Uint8List.fromList([
      0x1b,
      0x40,
      0x1b,
      0x61,
      0x00,
      ...latin1.encode('$normalized\n'),
      0x1b,
      0x64,
      0x04,
      0x1d,
      0x56,
      0x41,
      0x03,
    ]);
  }

  static Uint8List drawerPulse(int pin) =>
      Uint8List.fromList([0x1b, 0x70, pin == 1 ? 0x01 : 0x00, 0x19, 0xfa]);
}
