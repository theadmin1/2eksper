import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'report_form_screen.dart';
import 'web_panel_screen.dart';

class AraclarScreen extends StatefulWidget {
  const AraclarScreen({super.key});
  @override
  State<AraclarScreen> createState() => _AraclarScreenState();
}

class _AraclarScreenState extends State<AraclarScreen> {
  final search = TextEditingController();
  List<dynamic> vehicles = [];
  bool loading = true;
  String filter = '';
  static const statuses = [
    'musait',
    'kirada',
    'stokta',
    'ekspertizde',
    'serviste',
    'hasarli',
    'satildi',
    'pasif'
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await ApiService.get('araclar.php', queryParameters: {
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (filter.isNotEmpty) 'durum': filter
      });
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      setState(() {
        vehicles = ApiData.list(data['araclar']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Araçlar yüklenemedi: $e')));
    }
  }

  Future<void> openForm([Map<String, dynamic>? vehicle]) async {
    final formKey = GlobalKey<FormState>();
    final data = vehicle ?? {};
    final plate = TextEditingController(text: '${data['plaka'] ?? ''}');
    final vin = TextEditingController(text: '${data['sasi'] ?? ''}');
    final model = TextEditingController(text: '${data['marka_model'] ?? ''}');
    final year = TextEditingController(text: '${data['model_yili'] ?? ''}');
    final mileage = TextEditingController(text: '${data['kilometre'] ?? ''}');
    final notes = TextEditingController(text: '${data['notlar'] ?? ''}');
    String status = '${data['durum'] ?? 'musait'}';
    if (!statuses.contains(status)) status = 'musait';
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Form(
                    key: formKey,
                    child: ListView(shrinkWrap: true, children: [
                      Text(vehicle == null ? 'Yeni araç' : 'Aracı düzenle',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: plate,
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Plaka zorunludur'
                              : null,
                          decoration:
                              const InputDecoration(labelText: 'Plaka *')),
                      TextFormField(
                          controller: vin,
                          textCapitalization: TextCapitalization.characters,
                          decoration:
                              const InputDecoration(labelText: 'Şasi / VIN')),
                      TextFormField(
                          controller: model,
                          decoration: const InputDecoration(
                              labelText: 'Marka / model')),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: year,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Model yılı'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextFormField(
                                controller: mileage,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Kilometre')))
                      ]),
                      DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Durum'),
                          items: statuses
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(statusLabel(e))))
                              .toList(),
                          onChanged: (v) =>
                              setModal(() => status = v ?? status)),
                      TextFormField(
                          controller: notes,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'Notlar')),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final body = {
                              if (vehicle != null) 'id': data['id'],
                              'plaka': plate.text.trim().toUpperCase(),
                              'sasi': vin.text.trim().toUpperCase(),
                              'marka_model': model.text.trim(),
                              'model_yili': int.tryParse(year.text),
                              'kilometre': int.tryParse(mileage.text),
                              'durum': status,
                              'notlar': notes.text.trim()
                            };
                            try {
                              vehicle == null
                                  ? await ApiService.post('araclar.php', body)
                                  : await ApiService.put('araclar.php', body);
                              if (context.mounted) Navigator.pop(context, true);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Araç kaydedilemedi: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Kaydet'))
                    ])))));
    for (final controller in [plate, vin, model, year, mileage, notes]) {
      controller.dispose();
    }
    if (result == true) load();
  }

  static String statusLabel(String status) => switch (status) {
        'musait' => 'Müsait',
        'kirada' => 'Kirada',
        'stokta' => 'Stokta',
        'ekspertizde' => 'Ekspertizde',
        'serviste' => 'Serviste',
        'hasarli' => 'Hasarlı',
        'satildi' => 'Satıldı',
        'pasif' => 'Pasif',
        _ => status
      };

  Color statusColor(String value) => switch (value) {
        'kirada' => Colors.amber,
        'stokta' => Colors.teal,
        'ekspertizde' => Colors.orange,
        'serviste' => Colors.deepOrange,
        'hasarli' => Colors.red,
        'satildi' => Colors.green,
        'pasif' => Colors.blueGrey,
        _ => Colors.blue
      };

  Widget _statusPill(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Text(
          statusLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _vehicleMeta(IconData icon, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ]),
    );
  }

  Future<void> openHistory(Map<String, dynamic> vehicle) async {
    try {
      final response = await ApiService.get('araclar.php',
          queryParameters: {'id': '${vehicle['id']}'});
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      final reports = ApiData.list(data['raporlar']);
      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Padding(
              padding: const EdgeInsets.all(18),
              child: ListView(shrinkWrap: true, children: [
                Text('${vehicle['plaka']} ekspertiz geçmişi',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (reports.isEmpty)
                  const Text('Bu araca bağlı rapor bulunamadı.'),
                ...reports.map((report) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text('${report['rapor_no']} • ${report['tarih']}'),
                    subtitle:
                        Text('${report['musteri']} • ${report['islem_turu']}'),
                    trailing: const Icon(Icons.picture_as_pdf),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => WebPanelScreen(
                                initialPath:
                                    'rapor.php?id=${report['uuid'] ?? report['id']}')))))
              ])));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Araç geçmişi açılamadı: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Araçlar'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni araç')),
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .14),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(Icons.directions_car_filled_rounded,
                        color: scheme.onPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Araç envanteri',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 3),
                        Text('Araçları, durumları ve rapor geçmişini yönetin',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: .72),
                            )),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${vehicles.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(children: [
                  TextField(
                      controller: search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => load(),
                      decoration: InputDecoration(
                          hintText: 'Plaka, şasi veya marka ara',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                              tooltip: 'Ara',
                              onPressed: load,
                              icon: const Icon(Icons.arrow_forward_rounded)))),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final value in ['', ...statuses])
                          Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                  selected: filter == value,
                                  label: Text(value.isEmpty
                                      ? 'Tümü'
                                      : statusLabel(value)),
                                  onSelected: (_) {
                                    setState(() => filter = value);
                                    load();
                                  }))
                      ])),
                ]),
              ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                    padding: EdgeInsets.all(54),
                    child: Center(child: CircularProgressIndicator()))
              else if (vehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(children: [
                    Icon(Icons.no_crash_outlined,
                        size: 42, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text('Araç bulunamadı.',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Filtreleri değiştirin veya yeni araç ekleyin.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                )
              else
                ...vehicles.map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  final status = '${item['durum'] ?? 'musait'}';
                  final color = statusColor(status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: scheme.surfaceContainerLow,
                      child: InkWell(
                        onTap: () => openForm(item),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Icon(Icons.directions_car_rounded,
                                    color: color),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                            '${item['plaka'] ?? 'Plakasız'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            )),
                                      ),
                                      _statusPill(status, color),
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${item['marka_model'] ?? '-'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 11),
                                    Row(children: [
                                      _vehicleMeta(Icons.tag_rounded,
                                          '${item['sasi'] ?? '-'}'),
                                      const SizedBox(width: 10),
                                      _vehicleMeta(Icons.speed_rounded,
                                          '${item['kilometre'] ?? '-'} km'),
                                    ]),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                  tooltip: 'Araç işlemleri',
                                  onSelected: (value) {
                                    if (value == 'edit') openForm(item);
                                    if (value == 'history') openHistory(item);
                                    if (value == 'report') {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ReportFormScreen(
                                                  initialVehicle: item)));
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'report',
                                            child: Text('Yeni rapor oluştur')),
                                        PopupMenuItem(
                                            value: 'history',
                                            child: Text('Ekspertiz geçmişi')),
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Aracı düzenle'))
                                      ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 80)
            ])));
  }
}
