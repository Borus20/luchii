import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/haptics.dart';
import '../../core/native.dart';
import '../../core/theme.dart';
import '../../core/transfer.dart';
import '../../widgets/dots_loader.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_background.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  _ReceiveStep _step = _ReceiveStep.scanning;

  // Animated QR assembly
  int _totalFrames = 0;
  final Map<int, String> _collectedChunks = {};
  String? _animFilename;

  // Transfer state
  double _progress = 0;
  String? _savedPath;
  String? _filename;

  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_step != _ReceiveStep.scanning &&
        _step != _ReceiveStep.collectingFrames) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final mode = json['m'] as String?;

        if (mode == 'animated') {
          _handleAnimatedFrame(json, raw);
        } else if (mode == 'p2p') {
          _handleP2P(raw, json);
        }
      } catch (_) {
        // Not our QR format
      }
    }
  }

  void _handleAnimatedFrame(Map<String, dynamic> json, String raw) {
    final i = json['i'] as int;
    final n = json['n'] as int;
    final d = json['d'] as String;
    final f = json['f'] as String;

    _animFilename = f;
    _totalFrames = n;
    _collectedChunks[i] = d;

    HapticsService.light();

    setState(() => _step = _ReceiveStep.collectingFrames);

    if (_collectedChunks.length == n) {
      _assembleAnimatedFile(f, n);
    }
  }

  Future<void> _assembleAnimatedFile(String filename, int total) async {
    final frames =
        List.generate(total, (i) => _collectedChunks[i]);
    final bytes = Transfer.tryAssembleFrames(frames, total);
    if (bytes == null) return;

    HapticsService.success();
    final dir = await NativeHelper.getDownloadsDir();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);

    if (mounted) {
      setState(() {
        _savedPath = file.path;
        _filename = filename;
        _step = _ReceiveStep.done;
      });
    }
  }

  Future<void> _handleP2P(String raw, Map<String, dynamic> json) async {
    if (_step == _ReceiveStep.p2pReceiving) return;

    setState(() {
      _step = _ReceiveStep.p2pReceiving;
      _progress = 0;
      _filename = json['f'] as String?;
    });

    _scannerCtrl.stop();

    try {
      final dir = await NativeHelper.getDownloadsDir();
      final savedPath = await Transfer.receiveFile(
        raw,
        dir,
        (prog) {
          if (mounted) setState(() => _progress = prog);
        },
      );

      HapticsService.success();
      if (mounted) {
        setState(() {
          _savedPath = savedPath;
          _step = _ReceiveStep.done;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка приёма: $e')),
        );
        setState(() => _step = _ReceiveStep.scanning);
        _scannerCtrl.start();
      }
    }
  }

  void _reset() {
    _collectedChunks.clear();
    setState(() {
      _step = _ReceiveStep.scanning;
      _progress = 0;
      _savedPath = null;
      _filename = null;
      _totalFrames = 0;
      _animFilename = null;
    });
    _scannerCtrl.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Получить'),
        leading: _step != _ReceiveStep.scanning
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _reset,
              )
            : null,
      ),
      body: NeonBackground(child: SafeArea(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _ReceiveStep.scanning => _buildScanner(),
      _ReceiveStep.collectingFrames => _buildCollecting(),
      _ReceiveStep.p2pReceiving => _buildP2PReceiving(),
      _ReceiveStep.done => _buildDone(),
    };
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerCtrl,
          onDetect: _onQrDetected,
        ),
        // Overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: LuchiiColors.gold, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Bottom hint
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Наведите на QR-код отправителя',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: LuchiiColors.text),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollecting() {
    final collected = _collectedChunks.length;
    final total = _totalFrames;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DotsLoader(size: 14),
            const SizedBox(height: 24),
            Text(
              'Сбор QR-кадров',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Получено $collected / $total',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: LuchiiColors.goldLight, fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total > 0 ? collected / total : 0,
                  backgroundColor: LuchiiColors.card,
                  color: LuchiiColors.gold,
                  minHeight: 8,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Держите экран отправителя в кадре',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildP2PReceiving() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DotsLoader(size: 14),
            const SizedBox(height: 24),
            Text(
              'Получение файла',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (_filename != null) ...[
              const SizedBox(height: 8),
              Text(
                _filename!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: LuchiiColors.card,
                color: LuchiiColors.gold,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            if (_progress > 0)
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(color: LuchiiColors.goldLight),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_done_rounded,
                color: LuchiiColors.gold, size: 72),
            const SizedBox(height: 16),
            Text(
              'Файл получен',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 22),
            ),
            if (_filename != null) ...[
              const SizedBox(height: 8),
              Text(
                _filename!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                if (_savedPath != null) OpenFilex.open(_savedPath!);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Открыть файл'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                if (_savedPath != null) {
                  Share.shareXFiles([XFile(_savedPath!)]);
                }
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Поделиться'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _reset,
              child: const Text('Принять ещё один файл'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReceiveStep { scanning, collectingFrames, p2pReceiving, done }
