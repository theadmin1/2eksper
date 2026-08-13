import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'araclar_screen.dart';
import 'dashboard_screen.dart';
import 'musteriler_screen.dart';
import 'profile_screen.dart';
import 'randevular_screen.dart';
import 'raporlar_screen.dart';
import 'report_form_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _pageIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const RandevularScreen(),
    const RaporlarScreen(),
    const _MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppThemeProvider>().load();
    });
  }

  Future<void> _openReportForm() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportFormScreen()),
    );
    if (mounted) {
      setState(() {
        _pages[2] = RaporlarScreen(key: UniqueKey());
        _pageIndex = 2;
      });
    }
  }

  void _selectDestination(int value) => setState(() => _pageIndex = value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationColor = isDark ? const Color(0xFF0F172A).withValues(alpha: .85) : Colors.white.withValues(alpha: .9);
    final unselectedColor =
        isDark ? const Color(0xFFA7B3C5) : const Color(0xFF526177);
    const navy = Color(0xFF071B36);
    final accent = colors.secondary;
    return PopScope(
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pageIndex != 0) setState(() => _pageIndex = 0);
      },
      child: Scaffold(
        body: Column(
          children: [
            ValueListenableBuilder<ApiHealthState>(
              valueListenable: ApiService.health,
              builder: (_, state, __) => _ConnectionBanner(state: state),
            ),
            Expanded(
              child: IndexedStack(index: _pageIndex, children: _pages),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Semantics(
          button: true,
          label: 'Yeni ekspertiz oluştur',
          child: FloatingActionButton(
            tooltip: 'Yeni ekspertiz',
            elevation: 7,
            highlightElevation: 9,
            backgroundColor: accent,
            foregroundColor: navy,
            shape: CircleBorder(
              side: BorderSide(color: navigationColor, width: 3),
            ),
            onPressed: _openReportForm,
            child: const Icon(Icons.car_repair_rounded, size: 27),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          height: 76,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          color: navigationColor,
          surfaceTintColor: Colors.transparent,
          elevation: 18,
          shadowColor: const Color(0xFF0EA5E9).withValues(alpha: .15),
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: Row(
            children: [
              Expanded(
                child: _NavigationItem(
                  icon: CupertinoIcons.house,
                  selectedIcon: CupertinoIcons.house_fill,
                  label: 'Ana Sayfa',
                  selected: _pageIndex == 0,
                  selectedColor: accent,
                  unselectedColor: unselectedColor,
                  onTap: () => _selectDestination(0),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: CupertinoIcons.calendar,
                  selectedIcon: CupertinoIcons.calendar_today,
                  label: 'Randevular',
                  selected: _pageIndex == 1,
                  selectedColor: accent,
                  unselectedColor: unselectedColor,
                  onTap: () => _selectDestination(1),
                ),
              ),
              SizedBox(
                width: 68,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'Yeni',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: CupertinoIcons.doc_plaintext,
                  selectedIcon: CupertinoIcons.doc_text_fill,
                  label: 'Raporlar',
                  selected: _pageIndex == 2,
                  selectedColor: accent,
                  unselectedColor: unselectedColor,
                  onTap: () => _selectDestination(2),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: CupertinoIcons.square_grid_2x2,
                  selectedIcon: CupertinoIcons.square_grid_2x2_fill,
                  label: 'Diğer',
                  selected: _pageIndex == 3,
                  selectedColor: accent,
                  unselectedColor: unselectedColor,
                  onTap: () => _selectDestination(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        radius: 30,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 39,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? selectedColor.withValues(alpha: .18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: .15),
                    blurRadius: 8,
                  )
                ] : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final ApiHealthState state;

  const _ConnectionBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final message = switch (state) {
      ApiHealthState.offline =>
        'İnternet bağlantısı yok • Kayıtlar cihazda korunur',
      ApiHealthState.serverError => 'Sunucu geçici olarak yanıt veremiyor',
      ApiHealthState.unauthorized => 'Oturum sona erdi',
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();
    final isOffline = state == ApiHealthState.offline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isOffline
        ? (isDark ? const Color(0xFFFFB38D) : const Color(0xFFB6400D))
        : (isDark ? const Color(0xFFFFA5A5) : const Color(0xFFB42318));
    return Material(
      color: isDark
          ? (isOffline ? const Color(0xFF3C261D) : const Color(0xFF3A2027))
          : (isOffline ? const Color(0xFFFFF0E8) : const Color(0xFFFFE8E8)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Icon(
                isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.warning_amber_rounded,
                size: 17,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?['rol'] == 'admin';
    final colors = Theme.of(context).colorScheme;
    final theme = context.watch<AppThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chrome = isDark ? const Color(0xFF0F172A) : colors.primary;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: chrome,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.grid_view_rounded, color: chrome),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İşlem Merkezi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Araç, müşteri ve hesap yönetimi',
                          style:
                              TextStyle(color: Color(0xFFB8BBC0), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('GÖRÜNÜM'),
            Card(
              margin: const EdgeInsets.only(bottom: 18),
              child: SwitchListTile.adaptive(
                secondary: Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isDark
                        ? CupertinoIcons.moon_stars_fill
                        : CupertinoIcons.sun_max_fill,
                    color: colors.secondary,
                    size: 21,
                  ),
                ),
                title: const Text(
                  'Koyu Mod',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  isDark ? 'Koyu görünüm etkin' : 'Açık görünüm etkin',
                ),
                value: isDark,
                onChanged: (value) => theme.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
            _sectionLabel('OPERASYON'),
            _item(
              context,
              CupertinoIcons.car_detailed,
              'Araçlar',
              'Araç envanteri ve galeri kayıtları',
              const AraclarScreen(),
            ),
            _item(
              context,
              CupertinoIcons.person_2_fill,
              'Müşteriler',
              'Müşteri, araç ve ödeme kayıtları',
              const MusterilerScreen(),
            ),
            const SizedBox(height: 13),
            _sectionLabel('HESAP VE GÜVENLİK'),
            _item(
              context,
              CupertinoIcons.person_crop_circle,
              'Profil ve Güvenlik',
              'Hesap bilgileri ve şifre yönetimi',
              const ProfileScreen(),
            ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: _sectionLabel('YÖNETİM'),
              ),
            if (isAdmin)
              _item(
                context,
                Icons.groups_2_outlined,
                'Ekip Yönetimi',
                'Kullanıcı, rol ve hesap durumları',
                const UsersScreen(),
              ),
            if (isAdmin)
              _item(
                context,
                Icons.settings_outlined,
                'Ayarlar ve Tema',
                'Kurumsal kimlik, PDF tasarımı ve görünüm',
                const SettingsScreen(),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: .28)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Güvenli Çıkış Yap'),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String value) => Padding(
        padding: const EdgeInsets.fromLTRB(3, 0, 3, 9),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Color(0xFF777B82),
          ),
        ),
      );

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget screen,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: colors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: .55),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
