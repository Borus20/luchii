import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/transfer.dart';
import '../../widgets/dots_loader.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_background.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  _SendStep _step = _SendStep.idle;
  List<PlatformFile> _selectedFiles = [];
  int _currentFileIndex = 0;

  // Animated QR state
  List<String>? _qrFrames;
  int _qrFrameIndex = 0;
  Timer? _qrTimer;

  // P2P state
  SendSession? _sendSession;
  double _p2pProgress = 0;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _qrTimer?.cancel();
    _progressSub?.cancel();
    _sendSession?.cancel();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedFiles = result.files;
      _currentFileIndex = 0;
      _step = _SendStep.ready;
    });
  }

  Future<void> _startSending() async {
    if (_selectedFiles.isEmpty) return;
    final file = _selectedFiles[_currentFileIndex];
    final path = file.path;
    if (path == null) return;

    final fileObj = File(path);
    final size = await fileObj.length();

    HapticsService.medium();

    if (Transfer.useAnimatedQr(size)) {
      final bytes = await fileObj.readAsBytes();
      final frames = Transfer.encodeToFrames(bytes, file.name);
      setState(() {
        _qrFrames = frames;
        _qrFrameIndex = 0;
        _step = _SendStep.animatedQr;
      });
      _startQrAnimation();
    } else {
      setState(() => _step = _SendStep.p2pWaiting);
      try {
        final session = await Transfer.startSending(fileObj);
        _sendSession = session;
        _progressSub = session.progress.listen((p) {
          setState(() => _p2pProgress = p);
        });
        setState(() => _step = _SendStep.p2pSending);
        session.done.then((_) => _onTransferComplete()).catchError(_onError);
      } catch (e) {
        _onError(e);
      }
    }
  }

  void _startQrAnimation() {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _qrFrames == null) return;
      setState(() {
        _qrFrameIndex = (_qrFrameIndex + 1) % _qrFrames!.length;
      });
    });
  }

  void _onTransferComplete() {
    if (!mounted) return;
    HapticsService.success();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Файл отправлен')),
    );
    _nextFile();
  }

  void _onError(dynamic e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка: $e')),
    );
    setState(() => _step = _SendStep.ready);
  }

  void _nextFile() {
    _qrTimer?.cancel();
    _progressSub?.cancel();
    if (_currentFileIndex < _selectedFiles.length - 1) {
      setState(() {
        _currentFileIndex++;
        _step = _SendStep.ready;
        _p2pProgress = 0;
      });
    } else {
      setState(() {
        _step = _SendStep.done;
        _p2pProgress = 0;
      });
    }
  }

  void _reset() {
    _qrTimer?.cancel();
    _progressSub?.cancel();
    _sendSession?.cancel();
    setState(() {
      _step = _SendStep.idle;
      _selectedFiles = [];
      _currentFileIndex = 0;
      _qrFrames = null;
      _p2pProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Отправить'),
        leading: _step != _SendStep.idle
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _reset,
              )
            : null,
      ),
      body: NeonBackground(
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _SendStep.idle => _buildIdle(),
      _SendStep.ready => _buildReady(),
      _SendStep.animatedQr => _buildAnimatedQr(),
      _SendStep.p2pWaiting => _buildP2PWaiting(),
      _SendStep.p2pSending => _buildP2PSending(),
      _SendStep.done => _buildDone(),
    };
  }

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: LuchiiColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: LuchiiColors.cardBorder),
              ),
              child: const Icon(Icons.upload_file_rounded,
                  size: 48, color: LuchiiColors.gold),
            ),
            const SizedBox(height: 24),
            Text(
              'Выберите файл для отправки',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'До 10 КБ — через QR-анимацию\nБольше — через Wi-Fi (P2P)',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Выбрать файлы'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady() {
    final file = _selectedFiles[_currentFileIndex];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_selectedFiles.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Файл ${_currentFileIndex + 1} из ${_selectedFiles.length}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: LuchiiColors.goldLight),
              ),
            ),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded,
                    color: LuchiiColors.gold, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_formatSize(file.size),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _startSending,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Начать передачу'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _pickFiles,
            child: const Text('Выбрать другой файл'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedQr() {
    final frames = _qrFrames;
    if (frames == null || frames.isEmpty) return const SizedBox();
    final frame = frames[_qrFrameIndex];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Наведите камеру получателя\nна QR-код',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                QrImageView(
                  data: frame,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
                const SizedBox(height: 12),
                Text(
                  'Кадр ${_qrFrameIndex + 1} / ${frames.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: LuchiiColors.goldLight),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Приложение автоматически переключает кадры.\nНе убирайте экран до завершения.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _nextFile,
            child: const Text('Готово, следующий файл'),
          ),
        ],
      ),
    );
  }

  Widget _buildP2PWaiting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DotsLoader(),
          SizedBox(height: 16),
          Text('Запуск сервера…'),
        ],
      ),
    );
  }

  Widget _buildP2PSending() {
    final session = _sendSession;
    if (session == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Получатель сканирует QR\nдля подключения',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: session.qrData,
              version: QrVersions.auto,
              size: 260,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
            ),
          ),
          const SizedBox(height: 24),
          if (_p2pProgress > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _p2pProgress,
                backgroundColor: LuchiiColors.card,
                color: LuchiiColors.gold,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_p2pProgress * 100).toInt()}%',
              style: const TextStyle(color: LuchiiColors.goldLight),
            ),
          ] else ...[
            const DotsLoader(),
            const SizedBox(height: 8),
            const Text('Ожидание подключения…',
                style: TextStyle(color: LuchiiColors.textMuted)),
          ],
        ],
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
            const Icon(Icons.check_circle_rounded,
                color: LuchiiColors.gold, size: 72),
            const SizedBox(height: 16),
            Text(
              'Все файлы отправлены',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _reset,
              child: const Text('Отправить ещё'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

enum _SendStep { idle, ready, animatedQr, p2pWaiting, p2pSending, done }
