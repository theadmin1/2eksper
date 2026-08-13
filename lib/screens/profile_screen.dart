import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool loading = true;
  bool saving = false;
  String? loadError;

  static const labels = <String, String>{
    'ad_soyad': 'Ad soyad',
    'kullanici_adi': 'Kullanıcı adı',
    'email': 'E-posta',
    'telefon': 'Telefon',
    'isletme_adi': 'İşletme adı',
    'vergi_dairesi': 'Vergi dairesi',
    'vergi_no': 'Vergi numarası',
    'adres': 'Adres',
  };

  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      fields[key] = TextEditingController();
    }
    load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
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
      final response = await ApiService.get('profil.php');
      final data = ApiData.map(response['data']);
      final profile = ApiData.map(data['profil']);
      if (profile.isEmpty) {
        throw const ApiException('Sunucu profil bilgisini boş gönderdi.');
      }
      for (final key in labels.keys) {
        fields[key]!.text = '${profile[key] ?? ''}';
      }
    } catch (e) {
      if (mounted) loadError = 'Profil bilgileri alınamadı.\n$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
          ],
        ),
        backgroundColor: error ? colors.error : null,
      ),
    );
  }

  Future<void> save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ApiService.put('profil.php', {
        'action': 'profile',
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      });
      _message('Profil bilgileriniz güncellendi.');
    } catch (e) {
      _message('Profil kaydedilemedi: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changePassword() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final repeat = TextEditingController();
    final dialogKey = GlobalKey<FormState>();
    bool sending = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          icon: Icon(
            Icons.lock_reset_rounded,
            color: Theme.of(dialogContext).colorScheme.secondary,
            size: 32,
          ),
          title: const Text('Şifrenizi değiştirin'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: dialogKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hesabınızı korumak için en az 8 karakterli güçlü bir şifre kullanın.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: current,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mevcut şifre',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setDialog(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Mevcut şifrenizi yazın'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Yeni şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialog(() => obscureNew = !obscureNew),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'En az 8 karakter kullanın'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: repeat,
                    obscureText: obscureNew,
                    decoration: const InputDecoration(
                      labelText: 'Yeni şifre tekrar',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    validator: (value) => value != password.text
                        ? 'Yeni şifreler eşleşmiyor'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  sending ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      if (!dialogKey.currentState!.validate()) return;
                      setDialog(() => sending = true);
                      try {
                        await ApiService.put('profil.php', {
                          'action': 'password',
                          'mevcut_sifre': current.text,
                          'yeni_sifre': password.text,
                          'yeni_sifre_tekrar': repeat.text,
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialog(() => sending = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Şifre değiştirilemedi: $e')),
                          );
                        }
                      }
                    },
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(sending ? 'Değiştiriliyor' : 'Şifreyi değiştir'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    password.dispose();
    repeat.dispose();
    if (changed == true) _message('Şifreniz güvenle güncellendi.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil'),
            Text(
              'Hesap ve işletme bilgileri',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: loading
          ? const _ProfileLoading()
          : loadError != null
              ? _ProfileError(message: loadError!, onRetry: load)
              : Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      _ProfileHero(
                        name: fields['ad_soyad']!.text,
                        username: fields['kullanici_adi']!.text,
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(
                        icon: Icons.person_outline_rounded,
                        title: 'Kişisel bilgiler',
                        subtitle: 'Size ulaşmak için kullanılan bilgiler',
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _field('ad_soyad', Icons.badge_outlined),
                              const SizedBox(height: 12),
                              _field('kullanici_adi', Icons.alternate_email),
                              const SizedBox(height: 12),
                              _field(
                                'email',
                                Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                'telefon',
                                Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(
                        icon: Icons.storefront_outlined,
                        title: 'İşletme bilgileri',
                        subtitle: 'Raporlarda ve kurumsal belgelerde görünür',
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _field('isletme_adi', Icons.business_outlined),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _field(
                                      'vergi_dairesi',
                                      Icons.account_balance_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _field(
                                      'vergi_no',
                                      Icons.numbers_rounded,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _field(
                                'adres',
                                Icons.location_on_outlined,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(
                        icon: Icons.security_rounded,
                        title: 'Güvenlik',
                        subtitle: 'Hesabınıza erişimi yönetin',
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: ListTile(
                          onTap: saving ? null : changePassword,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.secondary.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              color: colors.secondary,
                            ),
                          ),
                          title: const Text(
                            'Şifreyi değiştir',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text('Mevcut şifrenizi yenileyin'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Kaydediliyor...' : 'Değişiklikleri kaydet',
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _field(
    String key,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final required = key == 'ad_soyad' || key == 'kullanici_adi';
    return TextFormField(
      controller: fields[key],
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? 'Bu alan zorunludur'
              : null
          : null,
      decoration: InputDecoration(
        labelText: '${labels[key]}${required ? ' *' : ''}',
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name, required this.username});

  final String name;
  final String username;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.characters.first.toUpperCase())
            .join();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.secondary, .24)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              initials,
              style: TextStyle(
                color: colors.onSecondary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Profiliniz' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username.trim().isEmpty ? 'Kullanıcı hesabı' : '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                SizedBox(width: 5),
                Text(
                  'Aktif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.secondary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
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
          ),
        ),
      ],
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 98,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 5; i++) ...[
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .32),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Profil açılamadı',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
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
