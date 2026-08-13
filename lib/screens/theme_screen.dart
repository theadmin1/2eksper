import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  bool loading = true;
  bool saving = false;
  String? loadError;
  Map<String, dynamic> data = {};
  Map<String, dynamic> presets = {};
  Map<String, dynamic> options = {};
  String sector = 'karma';

  static const colorLabels = <String, String>{
    'renk_marka': 'Marka',
    'renk_vurgu': 'Vurgu',
    'renk_arkaplan': 'Arka plan',
    'renk_yuzey': 'Yüzey',
    'renk_metin': 'Metin',
    'renk_kenar': 'Kenar',
    'renk_basari': 'Başarı',
    'renk_uyari': 'Uyarı',
    'renk_hata': 'Hata',
    'renk_bilgi': 'Bilgi',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final response = await ApiService.get('tema.php');
      final responseData = ApiData.map(response['data']);
      final theme = ApiData.map(responseData['tema']);
      if (theme.isEmpty) {
        throw const ApiException('Sunucu tema bilgisini boş gönderdi.');
      }
      if (!mounted) return;
      setState(() {
        data = theme;
        presets = ApiData.map(responseData['hazir_setler']);
        options = ApiData.map(responseData['secenekler']);
        final serverSector = '${responseData['sektor_tipi'] ?? 'karma'}';
        sector = const {'rentacar', 'galeri', 'karma'}.contains(serverSector)
            ? serverSector
            : 'karma';
      });
    } catch (e) {
      if (mounted) loadError = 'Tema ayarları alınamadı.\n$e';
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

  Future<void> save({bool reset = false}) async {
    if (saving) return;
    if (reset) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.restart_alt_rounded,
            color: Theme.of(dialogContext).colorScheme.secondary,
          ),
          title: const Text('Varsayılan temaya dön'),
          content: const Text(
            'Özel renk, tipografi ve rapor görünümü ayarlarınız sıfırlanacak.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sıfırla'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => saving = true);
    try {
      final payload = Map<String, dynamic>.from(data)..['sektor_tipi'] = sector;
      if (reset) payload['action'] = 'reset';
      final response = await ApiService.put('tema.php', payload);
      final responseData = ApiData.map(response['data']);
      final theme = ApiData.map(responseData['tema']);
      if (theme.isEmpty) {
        throw const ApiException(
          'Sunucu kaydedilen tema bilgisini göndermedi.',
        );
      }
      if (!mounted) return;
      context.read<AppThemeProvider>().apply(theme);
      setState(() => data = theme);
      _message(
        reset
            ? 'Varsayılan tema geri yüklendi.'
            : 'Tema uygulamaya ve raporlara uygulandı.',
      );
    } catch (e) {
      _message('Tema kaydedilemedi: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Color parse(dynamic value, [Color fallback = Colors.grey]) {
    final raw = '${value ?? ''}'.trim().replaceFirst('#', '');
    final number = int.tryParse(raw, radix: 16);
    return number == null ? fallback : Color(0xFF000000 | number);
  }

  Color _onColor(Color color) =>
      color.computeLuminance() > .45 ? const Color(0xFF09172B) : Colors.white;

  bool _presetSelected(Map<String, dynamic> values) => values.entries.every(
        (entry) =>
            '${data[entry.key]}'.toLowerCase() ==
            '${entry.value}'.toLowerCase(),
      );

  Future<void> _chooseColor(String key, String label) async {
    const swatches = [
      '#0b1d3a',
      '#132238',
      '#191c21',
      '#ff641f',
      '#f5b83d',
      '#ffffff',
      '#f4f6f9',
      '#e2e7ee',
      '#18a566',
      '#f4b740',
      '#d92d20',
      '#2563eb',
      '#7c3aed',
      '#64748b',
    ];
    final controller = TextEditingController(text: '${data[key] ?? ''}');
    String? validationError;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('$label rengini seçin'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hazır renkler',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final hex in swatches)
                      Tooltip(
                        message: hex.toUpperCase(),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(dialogContext, hex),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: parse(hex),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 19),
                TextField(
                  controller: controller,
                  maxLength: 7,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Özel HEX değeri',
                    hintText: '#FF641F',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    errorText: validationError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                  Navigator.pop(dialogContext, value.toLowerCase());
                } else {
                  setDialog(() => validationError = 'Örnek: #FF641F');
                }
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (selected != null && mounted) {
      setState(() => data[key] = selected);
    }
  }

  Map<String, String> _optionMap(dynamic source) {
    if (source is Map) {
      return source.map(
        (key, value) => MapEntry('$key', '$value'),
      );
    }
    if (source is List) {
      return {for (final value in source) '$value': '$value'};
    }
    return const {};
  }

  Widget _dropdown(String key, String label, dynamic source, IconData icon) {
    final items = _optionMap(source);
    if (items.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          'Sunucudan seçenek alınamadı',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final current = '${data[key] ?? ''}';
    final safeValue = items.containsKey(current) ? current : items.keys.first;
    if (current != safeValue) data[key] = safeValue;
    return DropdownButtonFormField<String>(
      key: ValueKey('$key-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: saving
          ? null
          : (value) => setState(() => data[key] = value ?? safeValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Görünüm ve tema'),
            Text(
              'Uygulama ve PDF tasarımı',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Temayı kaydet',
            onPressed: loading || saving ? null : save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: loading
          ? const _ThemeLoading()
          : loadError != null
              ? _ThemeError(message: loadError!, onRetry: load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
                  children: [
                    _buildModeCard(),
                    const SizedBox(height: 16),
                    _buildLivePreview(),
                    const SizedBox(height: 24),
                    const _ThemeSectionTitle(
                      title: 'Hazır temalar',
                      subtitle: 'Dengeli ve profesyonel paletlerden birini seçin',
                    ),
                    const SizedBox(height: 10),
                    _buildPresets(),
                    const SizedBox(height: 24),
                    const _ThemeSectionTitle(
                      title: 'Rapor görünümü',
                      subtitle: 'Sektör ve PDF yerleşim tercihleri',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey('sector-$sector'),
                              initialValue: sector,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Kullanım profili',
                                prefixIcon: Icon(Icons.business_center_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'rentacar',
                                  child: Text('Rent a Car / Filo'),
                                ),
                                DropdownMenuItem(
                                  value: 'galeri',
                                  child: Text('Galeri / Araç Ticareti'),
                                ),
                                DropdownMenuItem(
                                  value: 'karma',
                                  child: Text('Karma Kullanım'),
                                ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) => setState(
                                        () => sector = value ?? 'karma',
                                      ),
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'rapor_sablonu',
                              'Rapor şablonu',
                              options['rapor_sablonlari'],
                              Icons.description_outlined,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'logo_konumu',
                              'Belgede logo konumu',
                              options['logo_konumlari'],
                              Icons.branding_watermark_outlined,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'foto_duzeni',
                              'Rapor fotoğraf düzeni',
                              options['foto_duzenleri'],
                              Icons.photo_library_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _ThemeSectionTitle(
                      title: 'Tipografi',
                      subtitle: 'Okunabilirliği ve başlık karakterini ayarlayın',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _dropdown(
                              'font_govde',
                              'Gövde yazı tipi',
                              options['fontlar'],
                              Icons.format_align_left_rounded,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'font_baslik',
                              'Başlık yazı tipi',
                              options['fontlar'],
                              Icons.title_rounded,
                            ),
                            const SizedBox(height: 8),
                            _slider(
                              'font_boyut',
                              'Temel yazı boyutu',
                              12,
                              17,
                              suffix: 'pt',
                            ),
                            _slider(
                              'baslik_kalinlik',
                              'Başlık kalınlığı',
                              600,
                              900,
                              divisions: 3,
                            ),
                            _slider(
                              'harf_araligi',
                              'Harf aralığı',
                              -3,
                              3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _ThemeSectionTitle(
                      title: 'Renk paleti',
                      subtitle: 'Mobil arayüz ve PDF için ortak renk sistemi',
                    ),
                    const SizedBox(height: 10),
                    _buildColorGrid(),
                    const SizedBox(height: 24),
                    const _ThemeSectionTitle(
                      title: 'Arayüz ayrıntıları',
                      subtitle: 'Yoğunluk, gölge, köşe ve içerik seçenekleri',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _dropdown(
                              'yogunluk',
                              'Arayüz yoğunluğu',
                              options['yogunluklar'],
                              Icons.density_medium_rounded,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'golge',
                              'Kart gölgesi',
                              options['golgeler'],
                              Icons.layers_outlined,
                            ),
                            const SizedBox(height: 12),
                            _dropdown(
                              'menu_stili',
                              'Menü stili',
                              options['menu'],
                              Icons.space_dashboard_outlined,
                            ),
                            const SizedBox(height: 8),
                            _slider(
                              'kose_yaricap',
                              'Köşe yuvarlaklığı',
                              0,
                              24,
                              suffix: 'px',
                            ),
                            const Divider(height: 26),
                            _themeSwitch(
                              'maliyet_goster',
                              'Maliyet özetini göster',
                              'PDF raporlarında maliyet toplamını yayınla',
                              Icons.payments_outlined,
                            ),
                            const Divider(height: 1, indent: 48),
                            _themeSwitch(
                              'tablo_seritli',
                              'Şeritli tablolar',
                              'Uzun tabloların satırlarını ayırır',
                              Icons.table_rows_outlined,
                            ),
                            const Divider(height: 1, indent: 48),
                            _themeSwitch(
                              'animasyon',
                              'Arayüz animasyonları',
                              'Geçiş ve geri bildirim hareketlerini etkinleştirir',
                              Icons.animation_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: saving ? null : () => save(reset: true),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Sıfırla'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: saving ? null : save,
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              saving ? 'Kaydediliyor...' : 'Temayı kaydet',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildModeCard() {
    return Consumer<AppThemeProvider>(
      builder: (context, appTheme, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Uygulama görünümü',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Bu cihazda kullanılacak modu seçin',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: .52),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    _ModeButton(
                      icon: Icons.brightness_auto_rounded,
                      label: 'Sistem',
                      selected: appTheme.themeMode == ThemeMode.system,
                      onTap: () => appTheme.setThemeMode(ThemeMode.system),
                    ),
                    _ModeButton(
                      icon: Icons.light_mode_rounded,
                      label: 'Açık',
                      selected: appTheme.themeMode == ThemeMode.light,
                      onTap: () => appTheme.setThemeMode(ThemeMode.light),
                    ),
                    _ModeButton(
                      icon: Icons.dark_mode_rounded,
                      label: 'Koyu',
                      selected: appTheme.themeMode == ThemeMode.dark,
                      onTap: () => appTheme.setThemeMode(ThemeMode.dark),
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

  Widget _buildLivePreview() {
    final background = parse(data['renk_arkaplan'], const Color(0xFFF4F6F9));
    final surface = parse(data['renk_yuzey'], Colors.white);
    final brand = parse(data['renk_marka'], const Color(0xFF0B1D3A));
    final accent = parse(data['renk_vurgu'], const Color(0xFFFF641F));
    final text = parse(data['renk_metin'], const Color(0xFF191C21));
    final border = parse(data['renk_kenar'], const Color(0xFFE2E7EE));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: brand,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.handyman_outlined,
                    color: _onColor(accent),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '2EKSPER',
                    style: TextStyle(
                      color: _onColor(brand),
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                Icon(
                  Icons.notifications_none_rounded,
                  color: _onColor(brand).withValues(alpha: .78),
                  size: 21,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border.withValues(alpha: .72)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canlı arayüz önizlemesi',
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mobil uygulama ve PDF renkleri',
                        style: TextStyle(
                          color: text.withValues(alpha: .58),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: _onColor(accent),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    if (presets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Hazır tema bulunamadı.')),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = presets.entries.elementAt(index);
          final preset = ApiData.map(entry.value);
          final values = ApiData.map(preset['deger']);
          final selected = _presetSelected(values);
          final colors = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: saving
                ? null
                : () => setState(() => data = {...data, ...values}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 166,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? colors.secondary : colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final key in [
                        'renk_marka',
                        'renk_vurgu',
                        'renk_yuzey',
                      ])
                        Container(
                          width: 31,
                          height: 31,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: parse(values[key], Colors.white),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: colors.outlineVariant,
                              width: .7,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.secondary,
                          size: 20,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${preset['ad'] ?? entry.key}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${preset['aciklama'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in colorLabels.entries)
              SizedBox(
                width: width,
                child: _ColorTile(
                  label: entry.value,
                  value: '${data[entry.key] ?? ''}',
                  color: parse(data[entry.key]),
                  onTap: () => _chooseColor(entry.key, entry.value),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _themeSwitch(
    String key,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final enabled = data[key] == 1 || data[key] == true || '${data[key]}' == '1';
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: enabled,
      onChanged: saving
          ? null
          : (value) => setState(() => data[key] = value ? 1 : 0),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.secondary.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colors.secondary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _slider(
    String key,
    String label,
    double min,
    double max, {
    int? divisions,
    String suffix = '',
  }) {
    final parsed = double.tryParse('${data[key]}') ?? min;
    final value = parsed.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${value.round()}$suffix',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            onChanged: saving
                ? null
                : (newValue) =>
                    setState(() => data[key] = newValue.round()),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .09),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.secondary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSectionTitle extends StatelessWidget {
  const _ThemeSectionTitle({required this.title, required this.subtitle});

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

class _ThemeLoading extends StatelessWidget {
  const _ThemeLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final height in [130.0, 154.0, 144.0, 310.0]) ...[
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .34),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ThemeError extends StatelessWidget {
  const _ThemeError({required this.message, required this.onRetry});

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
              Icons.palette_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: 58,
            ),
            const SizedBox(height: 16),
            Text(
              'Tema ayarları açılamadı',
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
