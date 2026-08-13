import 'package:flutter/material.dart';

import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> users = [];
  int currentUserId = 0;
  bool loading = true;
  String? loadError;
  final searchController = TextEditingController();
  final Set<int> busyUsers = <int>{};

  @override
  void initState() {
    super.initState();
    searchController.addListener(_refreshSearch);
    load();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final response = await ApiService.get('kullanicilar.php');
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      setState(() {
        users = ApiData.list(data['kullanicilar']);
        currentUserId = int.tryParse('${data['aktif_kullanici_id']}') ?? 0;
      });
    } catch (e) {
      if (mounted) {
        loadError =
            'Ekip yönetimi yalnızca yetkili yöneticiler tarafından açılabilir.\n$e';
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value, {bool error = false}) {
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
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }

  Future<void> addUser() async {
    final name = TextEditingController();
    final username = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = 'personel';
    bool sending = false;
    bool obscure = true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .secondary
                              .withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Theme.of(sheetContext).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yeni ekip üyesi',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge,
                            ),
                            Text(
                              'Hesap ve erişim bilgilerini oluşturun',
                              style:
                                  Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Ad soyad *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ad soyad zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı *',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Kullanıcı adı zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Yetki rolü',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'personel',
                        child: Text('Personel'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Yönetici'),
                      ),
                    ],
                    onChanged: sending
                        ? null
                        : (value) =>
                            setModal(() => role = value ?? 'personel'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Başlangıç şifresi *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setModal(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'En az 8 karakter kullanın'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModal(() => sending = true);
                              try {
                                await ApiService.post('kullanicilar.php', {
                                  'ad_soyad': name.text.trim(),
                                  'kullanici_adi': username.text.trim(),
                                  'email': email.text.trim(),
                                  'telefon': phone.text.trim(),
                                  'rol': role,
                                  'sifre': password.text,
                                });
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext, true);
                                }
                              } catch (e) {
                                if (sheetContext.mounted) {
                                  setModal(() => sending = false);
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Kullanıcı eklenemedi: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        sending ? 'Ekleniyor...' : 'Kullanıcıyı ekle',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final controller in [name, username, email, phone, password]) {
      controller.dispose();
    }
    if (result == true) {
      _message('Yeni ekip üyesi eklendi.');
      await load();
    }
  }

  int _id(Map<String, dynamic> user) => int.tryParse('${user['id']}') ?? 0;

  bool _active(Map<String, dynamic> user) {
    final value = user['aktif'];
    return value == true || '$value' == '1';
  }

  Future<void> updateUser(
    Map<String, dynamic> user, {
    String? role,
    bool? active,
  }) async {
    final id = _id(user);
    if (busyUsers.contains(id)) return;
    setState(() => busyUsers.add(id));
    try {
      await ApiService.put('kullanicilar.php', {
        'id': user['id'],
        if (role != null) 'rol': role,
        if (active != null) 'aktif': active,
      });
      _message('Kullanıcı bilgileri güncellendi.');
      await load();
    } catch (e) {
      _message('Kullanıcı güncellenemedi: $e', error: true);
    } finally {
      if (mounted) setState(() => busyUsers.remove(id));
    }
  }

  Future<void> resetPassword(Map<String, dynamic> user) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool sending = false;
    bool obscure = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          icon: Icon(
            Icons.lock_reset_rounded,
            color: Theme.of(dialogContext).colorScheme.secondary,
          ),
          title: const Text('Yeni şifre belirle'),
          content: SizedBox(
            width: 390,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${user['ad_soyad']} için geçici veya kalıcı bir şifre oluşturun.',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Yeni şifre',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setDialog(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'En az 8 karakter kullanın'
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
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => sending = true);
                      try {
                        await ApiService.post('kullanicilar.php', {
                          'action': 'password',
                          'id': user['id'],
                          'yeni_sifre': controller.text,
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialog(() => sending = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Şifre yenilenemedi: $e')),
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
              label: Text(sending ? 'Kaydediliyor' : 'Şifreyi kaydet'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == true) _message('Kullanıcının şifresi yenilendi.');
  }

  Future<void> remove(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.person_remove_outlined,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('Kullanıcı silinsin mi?'),
        content: Text(
          '${user['ad_soyad']} hesabı kalıcı olarak silinecek. Bu işlem geri alınamaz.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = _id(user);
    setState(() => busyUsers.add(id));
    try {
      await ApiService.delete('kullanicilar.php', {'id': user['id']});
      _message('Kullanıcı ekipten kaldırıldı.');
      await load();
    } catch (e) {
      _message('Kullanıcı silinemedi: $e', error: true);
    } finally {
      if (mounted) setState(() => busyUsers.remove(id));
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = searchController.text.trim().toLowerCase();
    final list = users.map((e) => Map<String, dynamic>.from(e)).toList();
    if (query.isEmpty) return list;
    return list.where((user) {
      final text = [
        user['ad_soyad'],
        user['kullanici_adi'],
        user['email'],
        user['telefon'],
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final activeCount = users
        .map((e) => Map<String, dynamic>.from(e))
        .where(_active)
        .length;
    final adminCount = users
        .map((e) => Map<String, dynamic>.from(e))
        .where((user) => '${user['rol']}' == 'admin')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ekip yönetimi'),
            Text(
              'Kullanıcılar ve yetkiler',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      floatingActionButton: loadError == null
          ? FloatingActionButton.extended(
              onPressed: addUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Üye ekle'),
            )
          : null,
      body: loading
          ? const _UsersLoading()
          : loadError != null
              ? _UsersError(message: loadError!, onRetry: load)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 104),
                    children: [
                      _TeamSummary(
                        total: users.length,
                        active: activeCount,
                        admins: adminCount,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'İsim, kullanıcı adı veya telefon ara',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: searchController.clear,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ekip üyeleri',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${filtered.length} kişi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (users.isEmpty)
                        const _UsersEmpty(
                          icon: Icons.groups_2_outlined,
                          title: 'Henüz ekip üyesi yok',
                          subtitle: 'İlk ekip üyesini ekleyerek başlayın.',
                        )
                      else if (filtered.isEmpty)
                        const _UsersEmpty(
                          icon: Icons.person_search_outlined,
                          title: 'Eşleşen kullanıcı bulunamadı',
                          subtitle: 'Arama kelimenizi değiştirip tekrar deneyin.',
                        )
                      else
                        for (final user in filtered) ...[
                          _userCard(user),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final colors = Theme.of(context).colorScheme;
    final id = _id(user);
    final self = id == currentUserId;
    final active = _active(user);
    final role = '${user['rol']}' == 'admin' ? 'admin' : 'personel';
    final name = '${user['ad_soyad'] ?? ''}'.trim();
    final username = '${user['kullanici_adi'] ?? ''}'.trim();
    final email = '${user['email'] ?? ''}'.trim();
    final phone = '${user['telefon'] ?? ''}'.trim();
    final busy = busyUsers.contains(id);
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.substring(0, 1).toUpperCase())
            .join();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? colors.secondary.withValues(alpha: .14)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                initials,
                style: TextStyle(
                  color: active ? colors.secondary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'İsimsiz kullanıcı' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (self)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Siz',
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    username.isEmpty ? 'Kullanıcı adı yok' : '@$username',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (email.isNotEmpty || phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [email, phone].where((value) => value.isNotEmpty).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusPill(
                        label: role == 'admin' ? 'Yönetici' : 'Personel',
                        icon: role == 'admin'
                            ? Icons.shield_outlined
                            : Icons.badge_outlined,
                        color: role == 'admin'
                            ? colors.secondary
                            : colors.primary,
                      ),
                      _StatusPill(
                        label: active ? 'Aktif' : 'Pasif',
                        icon: active
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: active
                            ? const Color(0xFF18A566)
                            : colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (!self)
              PopupMenuButton<String>(
                tooltip: 'Kullanıcı işlemleri',
                onSelected: (value) {
                  if (value == 'role') {
                    updateUser(
                      user,
                      role: role == 'admin' ? 'personel' : 'admin',
                    );
                  } else if (value == 'active') {
                    updateUser(user, active: !active);
                  } else if (value == 'password') {
                    resetPassword(user);
                  } else if (value == 'delete') {
                    remove(user);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'role',
                    child: _MenuRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: role == 'admin' ? 'Personel yap' : 'Yönetici yap',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'active',
                    child: _MenuRow(
                      icon: active
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      label: active ? 'Pasifleştir' : 'Aktifleştir',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: _MenuRow(
                      icon: Icons.lock_reset_rounded,
                      label: 'Şifreyi yenile',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Kullanıcıyı sil',
                      color: colors.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({
    required this.total,
    required this.active,
    required this.admins,
  });

  final int total;
  final int active;
  final int admins;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_2_outlined, color: Colors.white),
              SizedBox(width: 9),
              Text(
                'Ekip özeti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TeamMetric(label: 'Toplam', value: '$total'),
              const _MetricDivider(),
              _TeamMetric(label: 'Aktif', value: '$active'),
              const _MetricDivider(),
              _TeamMetric(label: 'Yönetici', value: '$admins'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamMetric extends StatelessWidget {
  const _TeamMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: .18),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _UsersEmpty extends StatelessWidget {
  const _UsersEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersLoading extends StatelessWidget {
  const _UsersLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 128,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .38),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 116,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _UsersError extends StatelessWidget {
  const _UsersError({required this.message, required this.onRetry});

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
              Icons.admin_panel_settings_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: 58,
            ),
            const SizedBox(height: 16),
            Text(
              'Ekip yönetimi açılamadı',
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
