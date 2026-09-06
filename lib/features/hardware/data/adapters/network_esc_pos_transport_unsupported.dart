import 'dart:typed_data';

Future<void> sendNetworkEscPosBytes({
  required String address,
  required int port,
  required Uint8List bytes,
}) {
  throw UnsupportedError(
    'Direct network ESC/POS printing is not available on this platform.',
  );
}
