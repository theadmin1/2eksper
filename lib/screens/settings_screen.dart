import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'theme_screen.dart';
import 'web_panel_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool loading = true;
  bool saving = false;
  bool importing = false;
  String? loadError;
  final c = <String, TextEditingController>{};

  static const fields = <String, String>{
    'firma_adi_renkli': 'Marka adı — renkli bölüm',
    'firma_adi_duz': 'Marka adı — düz bölüm',
    'slogan': 'Slogan',
    'telefon': 'Telefon',
    'web_site': 'Web sitesi',
    'alt_slogan': 'Alt slogan',
    'belge_no': 'Belge numarası',
  };

  @override
  void initState() {
    super.initState();
    for (final key in fields.keys) {
      c[key] = TextEditingController();
    }
    load();
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final response = await ApiService.get('ayarlar.php');
      final data = ApiData.map(response['data']);
      final settings = ApiData.map(data['ayarlar']);
      if (settings.isEmpty) {
        throw const ApiException('Sunucu ayar bilgisini boş gönderdi.');
      }
      for (final key in fields.keys) {
        c[key]!.text = '${settings[key] ?? ''}';
      }
    } catch (e) {
      if (mounted) loadError = 'Kurumsal ayarlar alınamadı.\n$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => saving = true);
    try {
      await ApiService.put('ayarlar.php', {
        for (final entry in c.entries) entry.key: entry.value.text.trim(),
      });
      _message('Kurumsal ayarlar kaydedildi.');
    } catch (e) {
      _message('Ayarlar kaydedilemedi: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> importArchive() async {
    if (importing) return;
    setState(() => importing = true);
    try {
      final preview = await ApiService.get('arsiv_raporlar.php');
      if (!mounted) return;
      final data = ApiData.map(preview['data']);
      final toAdd = data['eklenecek'] ?? 0;
      final existing = data['zaten_mevcut'] ?? 0;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(dialogContext).colorScheme.secondary,
            size: 34,
          ),
          title: const Text('Arşiv raporlarını aktar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImportMetric(
                label: 'Eklenecek',
                value: '$toAdd',
                icon: Icons.add_circle_outline_rounded,
              ),
              const SizedBox(height: 8),
              _ImportMetric(
                label: 'Zaten mevcut',
                value: '$existing',
                icon: Icons.task_alt_rounded,
              ),
              const SizedBox(height: 14),
              Text(
                'Mevcut raporlar değiştirilmez; yalnızca eksik kayıtlar admin hesabına eklenir.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.file_download_done_rounded),
              label: const Text('Aktarımı başlat'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await ApiService.post('arsiv_raporlar.php', {});
      if (!mounted) return;
      final resultData = ApiData.map(result['data']);
      final imported = resultData['eklendi'] ?? 0;
      final skipped = resultData['atlandi'] ?? 0;
      _message('$imported rapor eklendi, $skipped kayıt atlandı.');
    } catch (e) {
      _message('Rapor arşivi aktarılamadı: $e', error: true);
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.logout_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('Oturumu kapat'),
        content: const Text(
          'Bu cihazdaki oturumunuz kapatılacak. Devam etmek istiyor musunuz?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ayarlar'),
            Text(
              'Uygulama ve kurumsal kimlik',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: loading
          ? const _SettingsLoading()
          : loadError != null
              ? _SettingsError(message: loadError!, onRetry: load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
                  children: [
                    _SettingsHero(
                      company: c['firma_adi_renkli']!.text.trim().isEmpty
                          ? '2Eksper çalışma alanı'
                          : '${c['firma_adi_renkli']!.text} ${c['firma_adi_duz']!.text}'
                              .trim(),
                    ),
                    const SizedBox(height: 24),
                    const _SettingsTitle(
                      title: 'Uygulama',
                      subtitle: 'Görünüm ve gelişmiş yönetim araçları',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _SettingsAction(
                            icon: Icons.palette_outlined,
                            title: 'Görünüm ve tema',
                            subtitle: 'Açık/koyu mod, renkler ve PDF şablonu',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ThemeScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 72),
                          _SettingsAction(
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Gelişmiş web paneli',
                            subtitle: 'Ekip yönetimi ve özel işlemler',
                            trailingIcon: Icons.open_in_new_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WebPanelScreen(
                                  initialPath: 'ayarlar.php',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SettingsTitle(
                      title: 'Kurumsal kimlik',
                      subtitle: 'PDF raporlarında kullanılan firma bilgileri',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _field(
                              'firma_adi_renkli',
                              Icons.format_color_fill_rounded,
                            ),
                            const SizedBox(height: 12),
                            _field(
                              'firma_adi_duz',
                              Icons.text_fields_rounded,
                            ),
                            const SizedBox(height: 12),
                            _field('slogan', Icons.campaign_outlined),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field(
                                    'telefon',
                                    Icons.phone_outlined,
                                    keyboard: TextInputType.phone,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    'belge_no',
                                    Icons.workspace_premium_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _field(
                              'web_site',
                              Icons.language_rounded,
                              keyboard: TextInputType.url,
                            ),
                            const SizedBox(height: 12),
                            _field('alt_slogan', Icons.notes_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        saving ? 'Kaydediliyor...' : 'Kurumsal ayarları kaydet',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SettingsTitle(
                      title: 'Veri araçları',
                      subtitle: 'Arşiv ve sistem verilerini yönetin',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: _SettingsAction(
                        icon: Icons.inventory_2_outlined,
                        title: 'Arşiv raporlarını ekle',
                        subtitle: 'Eksik SQL arşiv kayıtlarını admin hesabına aktar',
                        busy: importing,
                        onTap: importing ? null : importArchive,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Oturumu kapat'),
                    ),
                  ],
                ),
    );
  }

  Widget _field(
    String key,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c[key],
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: fields[key],
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.company});

  final String company;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.secondary, .22)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: colors.onSecondary,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Çalışma alanınızı yönetin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTitle extends StatelessWidget {
  const _SettingsTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData trailingIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colors.secondary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Icon(trailingIcon),
    );
  }
}

class _ImportMetric extends StatelessWidget {
  const _ImportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.secondary, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final height in [98.0, 132.0, 330.0]) ...[
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.settings_backup_restore_rounded,
              color: Theme.of(context).colorScheme.secondary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text('Ayarlar açılamadı',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
