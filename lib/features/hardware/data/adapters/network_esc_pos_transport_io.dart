import 'dart:io';
import 'dart:typed_data';

Future<void> sendNetworkEscPosBytes({
  required String address,
  required int port,
  required Uint8List bytes,
}) async {
  final socket = await Socket.connect(
    address,
    port,
    timeout: const Duration(seconds: 3),
  );
  try {
    socket.add(bytes);
    await socket.flush();
  } finally {
    await socket.close();
  }
}
