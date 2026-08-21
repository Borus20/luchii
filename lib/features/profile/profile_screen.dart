import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_background.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Профиль')),
      body: NeonBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildLogoHeader(context),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: 'Настройки',
                children: [
                  _buildHapticsToggle(context),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'Наши приложения BorusLab',
                children: [
                  _buildAppRow(context, 'КалорII', 'assets/apps/kalorii.png',
                      'https://kalorii.ru'),
                  const Divider(height: 1, color: LuchiiColors.cardBorder),
                  _buildAppRow(context, 'ШагII', 'assets/apps/shagii.png',
                      'https://rustore.ru/catalog/app/ru.shagii.shagii'),
                  const Divider(height: 1, color: LuchiiColors.cardBorder),
                  _buildAppRow(context, 'ЧекII', 'assets/apps/chekii.png',
                      'https://rustore.ru'),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'О приложении ЛучII',
                children: [
                  _buildLinkRow(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Политика конфиденциальности',
                    url: 'https://boruslab.com/privacy',
                  ),
                  const Divider(height: 1, color: LuchiiColors.cardBorder),
                  _buildLinkRow(
                    context,
                    icon: Icons.support_agent_outlined,
                    title: 'Поддержка',
                    url: 'mailto:support@boruslab.com',
                  ),
                  const Divider(height: 1, color: LuchiiColors.cardBorder),
                  _buildLinkRow(
                    context,
                    icon: Icons.star_outline_rounded,
                    title: 'Оценить в RuStore',
                    url: 'https://rustore.ru',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'ЛучII v0.1.0 · Сделано в России',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: LuchiiColors.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => wordmarkGradient.createShader(
              Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'ЛучII',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Передача файлов без следов',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: LuchiiColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LuchiiColors.textMuted,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildHapticsToggle(BuildContext context) {
    final state = context.watch<AppState>();
    return SwitchListTile(
      value: state.hapticsEnabled,
      onChanged: (v) {
        HapticsService.light();
        state.setHapticsEnabled(v);
      },
      title: const Text('Вибрация'),
      secondary: const Icon(Icons.vibration_rounded,
          color: LuchiiColors.gold, size: 22),
      activeColor: LuchiiColors.gold,
    );
  }

  Widget _buildAppRow(
      BuildContext context, String name, String asset, String url) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(asset, width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  color: LuchiiColors.card,
                  child: const Icon(Icons.apps_rounded,
                      color: LuchiiColors.gold, size: 20),
                )),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.open_in_new_rounded,
          color: LuchiiColors.textMuted, size: 16),
      onTap: () => _launchUrl(url),
    );
  }

  Widget _buildLinkRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
  }) {
    return ListTile(
      leading: Icon(icon, color: LuchiiColors.gold, size: 22),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: LuchiiColors.textMuted, size: 20),
      onTap: () => _launchUrl(url),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
