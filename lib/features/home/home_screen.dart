import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/neon_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 12),
              Text(
                'Передача файлов без следов',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _buildButtons(context),
              const Spacer(),
              _buildHint(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (bounds) =>
          wordmarkGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'ЛучII',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          letterSpacing: -2,
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () {
            HapticsService.medium();
            context.go('/send');
          },
          icon: const Icon(Icons.upload_rounded, size: 22),
          label: const Text('Отправить файл'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            HapticsService.medium();
            context.go('/receive');
          },
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
          label: const Text('Получить файл'),
        ),
      ],
    );
  }

  Widget _buildHint(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: LuchiiColors.textMuted),
        const SizedBox(width: 6),
        Text(
          'Без интернета · Без регистрации · Без серверов',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: LuchiiColors.textMuted,
              ),
        ),
      ],
    );
  }
}
