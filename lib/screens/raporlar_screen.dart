import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'report_form_screen.dart';
import 'web_panel_screen.dart';

class RaporlarScreen extends StatefulWidget {
  const RaporlarScreen({super.key, this.initialSearch = ''});

  final String initialSearch;

  @override
  State<RaporlarScreen> createState() => _RaporlarScreenState();
}

class _RaporlarScreenState extends State<RaporlarScreen> {
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<dynamic> _reports = [];
  String _status = '';
  String _type = '';

  static const _statusOptions = <String, String>{
    '': 'Tümü',
    'taslak': 'Taslak',
    'kontrolde': 'Kontrolde',
    'tamamlandi': 'Tamamlandı',
  };

  static const _typeOptions = <String, String>{
    '': 'Tüm işlemler',
    'genel': 'Genel ekspertiz',
    'rent_teslim': 'Rent teslim',
    'rent_iade': 'Rent iade',
    'galeri_alim': 'Galeri alım',
    'galeri_satis': 'Galeri satış',
  };

  Color get _chrome => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F172A)
      : const Color(0xFF0B2345);
  Color get _accent => Theme.of(context).colorScheme.secondary;
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _border => Theme.of(context).colorScheme.outlineVariant;

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialSearch;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiService.get(
        'raporlar.php',
        queryParameters: {
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          if (_status.isNotEmpty) 'durum': _status,
          if (_type.isNotEmpty) 'islem_turu': _type,
        },
      );
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      setState(() {
        _reports = ApiData.list(data['raporlar']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createReport() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportFormScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _edit(Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(reportId: '${report['id']}'),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _copy(Map<String, dynamic> report) async {
    try {
      await ApiService.post(
        'raporlar.php',
        {'action': 'copy', 'id': report['id']},
      );
      if (!mounted) return;
      _message('Rapor kopyalandı.');
      await _load();
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _remove(Map<String, dynamic> report) async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: const Text('Rapor silinsin mi?'),
            content: Text(
              '${report['rapor_no'] ?? 'Bu rapor'} kalıcı olarak silinecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved) return;

    try {
      await ApiService.post(
        'raporlar.php',
        {'action': 'delete', 'id': report['id']},
      );
      if (!mounted) return;
      _message('Rapor silindi.');
      await _load();
    } catch (error) {
      _message('$error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value.replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _reportAction(
    String action,
    Map<String, dynamic> report,
  ) async {
    final identifier = report['uuid'] ?? report['id'];
    switch (action) {
      case 'edit':
        await _edit(report);
        return;
      case 'digital':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebPanelScreen(
              initialPath: 'dijital_rapor.php?id=$identifier',
            ),
          ),
        );
        return;
      case 'link':
        final link = '${ApiService.webRoot}/dijital_rapor.php?id=$identifier';
        await Clipboard.setData(ClipboardData(text: link));
        _message('Müşteri bağlantısı kopyalandı.');
        return;
      case 'compare':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebPanelScreen(
              initialPath: 'rapor_karsilastir.php?id=${report['id']}',
            ),
          ),
        );
        return;
      case 'copy':
        await _copy(report);
        return;
      case 'delete':
        await _remove(report);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekspertiz Raporları',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              '${_reports.length} rapor • tüm süreç tek ekranda',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .52),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 7),
          IconButton.filled(
            tooltip: 'Yeni rapor',
            onPressed: _createReport,
            icon: Icon(Icons.add_rounded, color: dark ? _chrome : Colors.white),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _filterArea()),
            if (_loading)
              SliverList.list(
                children: List.generate(3, (_) => _loadingCard()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _errorView(),
              )
            else if (_reports.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyView(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList.separated(
                  itemCount: _reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => _reportCard(
                    ApiData.map(_reports[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createReport,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Rapor'),
      ),
    );
  }

  Widget _filterArea() {
    final typeLabel = _typeOptions[_type] ?? 'İşlem türü';
    final hasFilters = _status.isNotEmpty || _type.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: .045),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withValues(alpha: .86), _accent],
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              style: TextStyle(color: _chrome, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Plaka, müşteri veya rapor no ara',
                hintStyle: TextStyle(color: _chrome.withValues(alpha: .58)),
                prefixIcon: Icon(CupertinoIcons.search, color: _chrome),
                suffixIcon: IconButton(
                  tooltip: 'Ara',
                  onPressed: _load,
                  icon: Icon(Icons.arrow_forward_rounded, color: _chrome),
                ),
                fillColor: Colors.transparent,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final entry = _statusOptions.entries.elementAt(index);
                final selected = _status == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  showCheckmark: false,
                  avatar: selected
                      ? const Icon(Icons.check_rounded, size: 16)
                      : null,
                  onSelected: (_) {
                    setState(() => _status = entry.key);
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  tooltip: 'İşlem türünü seç',
                  onSelected: (value) {
                    setState(() => _type = value);
                    _load();
                  },
                  itemBuilder: (_) => _typeOptions.entries
                      .map(
                        (entry) => CheckedPopupMenuItem<String>(
                          value: entry.key,
                          checked: _type == entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _accent.withValues(alpha: .2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, color: _accent, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, color: _accent),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Filtreleri temizle',
                  onPressed: () {
                    setState(() {
                      _status = '';
                      _type = '';
                    });
                    _load();
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 19),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final car = ApiData.map(report['arac_bilgileri']);
    final identifier = report['uuid'] ?? report['id'];
    final reportStatus = '${report['durum'] ?? 'taslak'}';
    final statusData = _statusData(reportStatus);
    final photoUrl = _firstPhotoUrl(report);
    final plate = '${report['plaka'] ?? 'PLAKASIZ'}'.trim().toUpperCase();
    final model = '${car['marka_model'] ?? 'Araç bilgisi yok'}'.trim();
    final customer = '${report['musteri'] ?? ''}'.trim();
    final processType = _typeOptions['${report['islem_turu'] ?? ''}'] ??
        '${report['islem_turu'] ?? 'Genel ekspertiz'}';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border.withValues(alpha: .5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .065),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 154,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photoUrl.isNotEmpty)
                      Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _vehiclePlaceholder(),
                      )
                    else
                      _vehiclePlaceholder(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000E21)],
                          stops: [.38, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _statusPill(statusData.$1, statusData.$2),
                    ),
                    Positioned(
                      top: 5,
                      right: 6,
                      child: PopupMenuButton<String>(
                        tooltip: 'Diğer işlemler',
                        color: _surface,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                        ),
                        onSelected: (value) => _reportAction(value, report),
                        itemBuilder: (_) => _actionItems(report),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  model.isEmpty ? 'Araç bilgisi yok' : model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    shadows: [Shadow(blurRadius: 8)],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  customer.isEmpty
                                      ? 'Müşteri belirtilmedi'
                                      : customer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .72),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              plate.isEmpty ? 'PLAKASIZ' : plate,
                              style: const TextStyle(
                                color: Color(0xFF07162A),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _infoItem(
                            Icons.confirmation_number_outlined,
                            'Rapor No',
                            '${report['rapor_no'] ?? '—'}',
                          ),
                        ),
                        Container(width: 1, height: 33, color: _border),
                        Expanded(
                          child: _infoItem(
                            CupertinoIcons.calendar,
                            'Tarih',
                            '${report['tarih'] ?? '—'}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.car_repair_rounded,
                              color: _accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              processType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _text,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _edit(report),
                            icon: const Icon(Icons.edit_rounded, size: 19),
                            label: const Text('Düzenle'),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WebPanelScreen(
                                  initialPath: 'rapor.php?id=$identifier',
                                ),
                              ),
                            ),
                            icon:
                                const Icon(Icons.description_rounded, size: 19),
                            label: const Text('Raporu Gör'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _actionItems(Map<String, dynamic> report) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_rounded),
            title: Text('Düzenle'),
          ),
        ),
        const PopupMenuItem(
          value: 'digital',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language_rounded),
            title: Text('Dijital raporu aç'),
          ),
        ),
        const PopupMenuItem(
          value: 'link',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.link_rounded),
            title: Text('Müşteri bağlantısını kopyala'),
          ),
        ),
        if ('${report['islem_turu']}' == 'rent_iade')
          const PopupMenuItem(
            value: 'compare',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.compare_arrows_rounded),
              title: Text('Teslim/iade karşılaştır'),
            ),
          ),
        const PopupMenuItem(
          value: 'copy',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_rounded),
            title: Text('Kopyala'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading:
                Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            title: Text('Sil'),
          ),
        ),
      ];

  (String, Color) _statusData(String status) => switch (status) {
        'tamamlandi' => ('Tamamlandı', const Color(0xFF20B26B)),
        'teslim_edildi' => ('Teslim Edildi', const Color(0xFF20B26B)),
        'kontrolde' => ('Kontrolde', const Color(0xFF38BDF8)),
        'onay_bekliyor' => ('Onay Bekliyor', const Color(0xFF0EA5E9)),
        _ => ('Taslak', const Color(0xFF94A3B8)),
      };

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 7, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _infoItem(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          children: [
            Icon(icon, color: _accent, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _text.withValues(alpha: .48),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String _firstPhotoUrl(Map<String, dynamic> report) {
    final photos = ApiData.list(report['foto_yolu'], wrapString: true);
    if (photos.isEmpty) return '';
    final first = photos.first;
    if (first is Map) {
      final photo = ApiData.map(first);
      final path = photo['url'] ??
          photo['path'] ??
          photo['yol'] ??
          photo['foto_yolu'] ??
          photo['src'];
      return ApiService.mediaUrl(path);
    }
    return ApiService.mediaUrl(first);
  }

  Widget _vehiclePlaceholder() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_chrome, const Color(0xFF173C69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -34,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: .12),
                ),
              ),
            ),
            Positioned(
              left: -34,
              bottom: -48,
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .04),
                ),
              ),
            ),
            Center(
              child: Icon(
                CupertinoIcons.car_detailed,
                size: 82,
                color: Colors.white.withValues(alpha: .88),
              ),
            ),
          ],
        ),
      );

  Widget _loadingCard() => Container(
        height: 300,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: CupertinoActivityIndicator(color: _accent, radius: 15),
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, color: _accent, size: 34),
              ),
              const SizedBox(height: 17),
              Text(
                'Raporlar yüklenemedi',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _text.withValues(alpha: .56)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded, color: _accent, size: 38),
              ),
              const SizedBox(height: 17),
              Text(
                'Rapor bulunamadı',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Arama sözcüğünü veya filtrelerini değiştirerek tekrar dene.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _text.withValues(alpha: .56)),
              ),
            ],
          ),
        ),
      );
}
