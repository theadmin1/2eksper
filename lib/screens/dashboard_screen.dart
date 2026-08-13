import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'araclar_screen.dart';
import 'randevular_screen.dart';
import 'raporlar_screen.dart';
import 'web_panel_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = const {};
  String? _error;

  Color get _chrome => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F172A)
      : Theme.of(context).colorScheme.primary;
  Color get _accent => Theme.of(context).colorScheme.secondary;
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _border => Theme.of(context).colorScheme.outlineVariant;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response = await ApiService.get('dashboard.php');
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      if (response['status'] == true && data.isNotEmpty) {
        setState(() {
          _data = data;
          _error = null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '${response['message'] ?? 'Veriler alınamadı.'}';
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reports = ApiData.list(_data['recent_reports']);
    final appointments = ApiData.list(_data['upcoming_appointments']);
    final stats = ApiData.map(_data['stats']);
    final fullName = '${auth.user?['ad_soyad'] ?? 'Kullanıcı'}'.trim();
    final firstName = fullName.split(RegExp(r'\s+')).first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(auth, firstName)),
              if (_loading)
                SliverToBoxAdapter(child: _loadingBlock())
              else if (_error != null)
                SliverToBoxAdapter(child: _errorView())
              else ...[
                SliverToBoxAdapter(
                  child: _sectionTitle(
                    'Araç Ekspertiz Durumu',
                    action: 'Tümünü Gör',
                    onTap: () => _push(const RaporlarScreen()),
                  ),
                ),
                SliverToBoxAdapter(child: _recentReports(reports)),
                SliverToBoxAdapter(
                  child: _sectionTitle('Günlük Akış'),
                ),
                SliverToBoxAdapter(
                  child: _appointmentSummary(stats, appointments.length),
                ),
                SliverToBoxAdapter(child: _sectionTitle('Genel Bakış')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.48,
                    children: [
                      _metric(
                        'Bugünkü Rapor',
                        stats['today_reports'],
                        CupertinoIcons.doc_text_fill,
                        _accent,
                      ),
                      _metric(
                        'Bekleyen Randevu',
                        stats['pending_appointments'],
                        CupertinoIcons.clock_fill,
                        const Color(0xFFF4B740),
                      ),
                      _metric(
                        'Toplam Rapor',
                        stats['total_reports'],
                        CupertinoIcons.folder_fill,
                        const Color(0xFF4E7BD9),
                      ),
                      _metric(
                        'Toplam Araç',
                        stats['total_vehicles'],
                        CupertinoIcons.car_fill,
                        const Color(0xFF20B26B),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: _sectionTitle('Hızlı İşlemler')),
                SliverList.list(
                  children: [
                    _quickAction(
                      CupertinoIcons.calendar_badge_plus,
                      'Randevular',
                      '${appointments.length} yaklaşan randevu',
                      () => _push(const RandevularScreen()),
                    ),
                    _quickAction(
                      CupertinoIcons.car_detailed,
                      'Araç Galerisi',
                      'Envanter ve araç kayıtları',
                      () => _push(const AraclarScreen()),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AuthProvider auth, String firstName) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.read<AppThemeProvider>();
    final company = '${auth.firma?['firma_adi'] ?? 'Oto Ekspertiz & Galeri'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 15),
      decoration: BoxDecoration(
        color: dark ? _chrome : _surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .18 : .05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent, _accent.withValues(alpha: .72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.shield_outlined, color: _chrome, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2EKSPER',
                      style: TextStyle(
                        color: dark ? Colors.white : _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: (dark ? Colors.white : _text)
                            .withValues(alpha: .55),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: dark ? 'Açık moda geç' : 'Koyu moda geç',
                onPressed: () => themeProvider.toggleBrightness(
                  Theme.of(context).brightness,
                ),
                icon: Icon(
                    dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 19,
                backgroundColor: _accent,
                child: Icon(CupertinoIcons.person_fill, color: _chrome),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hoş geldin, $firstName!',
            style: TextStyle(
              color: dark ? Colors.white : _text,
              fontSize: 22,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withValues(alpha: .92), _accent],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: .2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              minLines: 1,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _push(
                RaporlarScreen(initialSearch: value.trim()),
              ),
              style: TextStyle(color: _chrome, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Plaka, müşteri veya araç ara…',
                hintStyle: TextStyle(color: _chrome.withValues(alpha: .58)),
                prefixIcon: Icon(CupertinoIcons.search, color: _chrome),
                suffixIcon: Icon(Icons.arrow_forward_rounded, color: _chrome),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                fillColor: Colors.transparent,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? action, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null) TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }

  Widget _recentReports(List<dynamic> reports) {
    if (reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: _emptyCard('Henüz ekspertiz raporu bulunmuyor.'),
      );
    }
    return SizedBox(
      height: 242,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        scrollDirection: Axis.horizontal,
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _reportCard(ApiData.map(reports[index])),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final id = report['uuid'] ?? report['id'];
    final vehicle = ApiData.map(report['arac_bilgileri']);
    final photos = ApiData.list(report['foto_yolu'], wrapString: true);
    final photoUrl = photos.isEmpty ? '' : ApiService.mediaUrl(photos.first);
    final model = '${vehicle['marka_model'] ?? 'Ekspertiz raporu'}';
    final status = '${report['durum'] ?? 'taslak'}';
    final completed = status == 'tamamlandi' || status == 'teslim_edildi';
    final (statusLabel, statusColor) = switch (status) {
      'tamamlandi' => ('Tamamlandı', const Color(0xFF20B26B)),
      'teslim_edildi' => ('Teslim Edildi', const Color(0xFF20B26B)),
      'kontrolde' => ('Kontrolde', const Color(0xFF38BDF8)),
      'onay_bekliyor' => ('Onay Bekliyor', const Color(0xFF0EA5E9)),
      _ => ('Taslak', const Color(0xFF94A3B8)),
    };
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _push(WebPanelScreen(initialPath: 'rapor.php?id=$id')),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: .05),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 88,
                  width: double.infinity,
                  child: photoUrl.isEmpty
                      ? _vehiclePlaceholder()
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _vehiclePlaceholder(),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: statusColor,
                    child: Icon(
                      completed
                          ? Icons.check_rounded
                          : Icons.more_horiz_rounded,
                      size: 16,
                      color: completed ? Colors.white : _chrome,
                    ),
                  ),
                ],
              ),
              Text(
                '${report['plaka'] ?? 'Plakasız'} • ${report['musteri'] ?? 'Müşteri yok'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _text.withValues(alpha: .55), fontSize: 11.5),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(Icons.circle, size: 9, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                        color: _text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => _push(
                    WebPanelScreen(initialPath: 'rapor.php?id=$id'),
                  ),
                  child: const Text('Raporu Görüntüle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehiclePlaceholder() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _chrome.withValues(alpha: .92),
              _chrome.withValues(alpha: .7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
                right: 12,
                top: 10,
                child: Icon(Icons.shield_outlined, color: _accent)),
            Center(
                child: Icon(CupertinoIcons.car_detailed,
                    size: 62, color: Colors.white.withValues(alpha: .9))),
          ],
        ),
      );

  Widget _appointmentSummary(Map<String, dynamic> stats, int upcoming) {
    final pending = int.tryParse('${stats['pending_appointments'] ?? 0}') ?? 0;
    final todayReports = int.tryParse('${stats['today_reports'] ?? 0}') ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 11, color: _accent),
              const SizedBox(width: 7),
              Text('Operasyon özeti',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('$upcoming yaklaşan',
                  style: TextStyle(
                      color: _text.withValues(alpha: .54), fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _summaryValue('Bugünkü rapor', todayReports),
              _verticalDivider(),
              _summaryValue('Bekleyen', pending),
              _verticalDivider(),
              _summaryValue('Yaklaşan', upcoming),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, int value) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: _text.withValues(alpha: .52), fontSize: 10.5)),
          ],
        ),
      );

  Widget _verticalDivider() => Container(width: 1, height: 38, color: _border);

  Widget _metric(String title, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value ?? 0}',
                  style: TextStyle(
                      color: _text, fontSize: 21, fontWeight: FontWeight.w900),
                ),
                Text(
                  title,
                  maxLines: 2,
                  style: TextStyle(
                      color: _text.withValues(alpha: .55), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: _text, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: _text.withValues(alpha: .52),
                              fontSize: 11.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingBlock() => const SizedBox(
        height: 280,
        child: Center(child: CupertinoActivityIndicator(radius: 16)),
      );

  Widget _emptyCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );

  Widget _errorView() => SizedBox(
        height: 280,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 52, color: _accent),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
}
