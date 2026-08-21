import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kAnimatedQrThreshold = 10 * 1024; // 10 KB
const _kChunkSize = 500; // bytes per frame (base64 chars)
const _kBlockSize = 64 * 1024; // 64 KB encrypt block

// ---------------------------------------------------------------------------
// Animated QR mode (files ≤ 10 KB)
// ---------------------------------------------------------------------------

class AnimatedQrTransfer {
  /// Encode [data] into a list of JSON strings, one per QR frame.
  static List<String> encodeToFrames(Uint8List data, String filename) {
    final b64 = base64Encode(data);
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += _kChunkSize) {
      chunks.add(b64.substring(i, min(i + _kChunkSize, b64.length)));
    }
    return List.generate(chunks.length, (i) {
      return jsonEncode({
        'm': 'animated',
        'i': i,
        'n': chunks.length,
        'd': chunks[i],
        'f': filename,
      });
    });
  }

  /// Try to assemble [frames] into file bytes.
  /// Returns null if not all [total] frames have been collected yet.
  static Uint8List? tryAssembleFrames(List<String?> frames, int total) {
    if (frames.length < total) return null;
    if (frames.any((f) => f == null)) return null;
    final combined = frames.join('');
    return base64Decode(combined);
  }
}

// ---------------------------------------------------------------------------
// P2P WiFi mode (files > 10 KB)
// ---------------------------------------------------------------------------

class SendSession {
  final String qrData;
  final Stream<double> progress;
  final Future<void> done;
  final void Function() cancel;

  const SendSession({
    required this.qrData,
    required this.progress,
    required this.done,
    required this.cancel,
  });
}

class Transfer {
  // ---- Animated QR helpers (delegates) ----

  static List<String> encodeToFrames(Uint8List data, String filename) =>
      AnimatedQrTransfer.encodeToFrames(data, filename);

  static Uint8List? tryAssembleFrames(List<String?> frames, int total) =>
      AnimatedQrTransfer.tryAssembleFrames(frames, total);

  // ---- Mode selector ----

  static bool useAnimatedQr(int fileSize) => fileSize <= _kAnimatedQrThreshold;

  // ---- P2P send ----

  static Future<SendSession> startSending(File file) async {
    final fileSize = await file.length();
    final filename = p.basename(file.path);

    // Generate AES-256 key (32 random bytes)
    final rng = Random.secure();
    final keyBytes = Uint8List.fromList(
        List.generate(32, (_) => rng.nextInt(256)));
    final keyHex = _bytesToHex(keyBytes);

    // Bind server socket on a random port
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;

    // Get device IP
    final ip = await _getLocalIp();

    final qrData = jsonEncode({
      'm': 'p2p',
      'ip': ip,
      'port': port,
      'key': keyHex,
      'f': filename,
      's': fileSize,
    });

    final progressController = StreamController<double>.broadcast();
    final completer = Completer<void>();
    bool cancelled = false;

    // Accept one connection and stream the file
    () async {
      try {
        final socket = await server.first;
        if (cancelled) {
          socket.destroy();
          return;
        }

        final aesKey = enc.Key(keyBytes);
        // Send IV (16 bytes) first
        final ivBytes = Uint8List.fromList(
            List.generate(16, (_) => rng.nextInt(256)));
        socket.add(ivBytes);

        final iv = enc.IV(ivBytes);
        final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));

        int sent = 0;
        final fileStream = file.openRead();
        await for (final chunk in fileStream) {
          if (cancelled) break;
          // Pad chunk to block size multiple
          final padded = _padPkcs7(Uint8List.fromList(chunk));
          final encrypted = encrypter.encryptBytes(padded, iv: iv);
          // Send 4-byte length prefix + encrypted data
          final encBytes = encrypted.bytes;
          final lenBytes = ByteData(4)..setUint32(0, encBytes.length, Endian.big);
          socket.add(lenBytes.buffer.asUint8List());
          socket.add(encBytes);
          sent += chunk.length;
          progressController.add(sent / fileSize);
        }

        await socket.flush();
        socket.destroy();
        progressController.add(1.0);
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      } finally {
        progressController.close();
        server.close();
      }
    }();

    return SendSession(
      qrData: qrData,
      progress: progressController.stream,
      done: completer.future,
      cancel: () {
        cancelled = true;
        server.close();
      },
    );
  }

  // ---- P2P receive ----

  static Future<String> receiveFile(
    String qrPayload,
    Directory saveDir,
    void Function(double) onProgress,
  ) async {
    final json = jsonDecode(qrPayload) as Map<String, dynamic>;
    final ip = json['ip'] as String;
    final port = json['port'] as int;
    final keyHex = json['key'] as String;
    final filename = json['f'] as String;
    final totalSize = (json['s'] as num).toInt();

    final keyBytes = _hexToBytes(keyHex);
    final aesKey = enc.Key(keyBytes);

    final socket = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 10));

    try {
      final saveFile = File(p.join(saveDir.path, filename));
      final sink = saveFile.openWrite();
      int received = 0;

      // Read IV (16 bytes)
      final ivBytes = await _readExact(socket, 16);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));

      // Read length-prefixed encrypted blocks
      while (received < totalSize) {
        final lenBytes = await _readExact(socket, 4);
        final blockLen = ByteData.sublistView(lenBytes).getUint32(0, Endian.big);
        final encBlock = await _readExact(socket, blockLen);
        final decrypted = encrypter.decryptBytes(
          enc.Encrypted(encBlock),
          iv: iv,
        );
        final unpadded = _unpadPkcs7(Uint8List.fromList(decrypted));
        sink.add(unpadded);
        received += unpadded.length;
        onProgress(received / totalSize);
      }

      await sink.flush();
      await sink.close();
      return saveFile.path;
    } finally {
      socket.destroy();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
      return '127.0.0.1';
    } catch (_) {
      return '127.0.0.1';
    }
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static Uint8List _padPkcs7(Uint8List data) {
    final padLen = 16 - (data.length % 16);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    return padded;
  }

  static Uint8List _unpadPkcs7(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen > 16 || padLen == 0) return data;
    return Uint8List.sublistView(data, 0, data.length - padLen);
  }

  static Future<Uint8List> _readExact(Socket socket, int length) async {
    final buf = BytesBuilder();
    await for (final chunk in socket) {
      buf.add(chunk);
      if (buf.length >= length) break;
    }
    final all = buf.toBytes();
    return Uint8List.sublistView(all, 0, length);
  }
}
