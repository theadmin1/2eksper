import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RandevularScreen extends StatefulWidget {
  const RandevularScreen({super.key});
  @override
  State<RandevularScreen> createState() => _RandevularScreenState();
}

class _RandevularScreenState extends State<RandevularScreen> {
  List<dynamic> appointments = [];
  bool loading = true;
  String filter = '';
  String scope = '';
  final search = TextEditingController();
  Map<String, dynamic> summary = {};
  static const statuses = ['Bekliyor', 'Tamamlandı', 'İptal'];

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
      final response = await ApiService.get('randevular.php', queryParameters: {
        if (filter.isNotEmpty) 'durum': filter,
        if (scope.isNotEmpty) 'kapsam': scope,
        if (search.text.trim().isNotEmpty) 'search': search.text.trim()
      });
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      setState(() {
        appointments = ApiData.list(data['randevular']);
        summary = ApiData.map(data['ozet']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _message('Randevular yüklenemedi: $e');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> openForm([Map<String, dynamic>? appointment]) async {
    final data = appointment ?? {};
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: '${data['musteri_adi'] ?? ''}');
    final phone = TextEditingController(text: '${data['telefon'] ?? ''}');
    final plate = TextEditingController(text: '${data['plaka'] ?? ''}');
    final vehicle =
        TextEditingController(text: '${data['arac_bilgisi'] ?? ''}');
    final date = TextEditingController(
        text:
            '${data['randevu_tarihi'] ?? DateTime.now().toIso8601String().substring(0, 10)}');
    final time = TextEditingController(
        text: '${data['randevu_saati'] ?? TimeOfDay.now().format(context)}'
            .substring(0, 5));
    final notes = TextEditingController(text: '${data['notlar'] ?? ''}');
    String status = '${data['durum'] ?? 'Bekliyor'}';
    if (!statuses.contains(status)) status = 'Bekliyor';
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => StatefulBuilder(builder: (context, setModal) {
              Future<void> chooseDate() async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(date.text) ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (picked != null) {
                  date.text = picked.toIso8601String().substring(0, 10);
                }
              }

              Future<void> chooseTime() async {
                final parts = time.text.split(':');
                final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                        hour: int.tryParse(parts.first) ?? 9,
                        minute: parts.length > 1
                            ? int.tryParse(parts[1]) ?? 0
                            : 0));
                if (picked != null) {
                  time.text =
                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                }
              }

              return Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(context).viewInsets.bottom + 20),
                  child: Form(
                      key: formKey,
                      child: ListView(shrinkWrap: true, children: [
                        Text(
                            appointment == null
                                ? 'Yeni randevu'
                                : 'Randevuyu düzenle',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _field(name, 'Müşteri adı *', required: true),
                        _field(phone, 'Telefon *',
                            required: true, keyboard: TextInputType.phone),
                        _field(plate, 'Plaka'),
                        _field(vehicle, 'Araç bilgisi'),
                        Row(children: [
                          Expanded(
                              child: TextFormField(
                                  controller: date,
                                  readOnly: true,
                                  onTap: chooseDate,
                                  decoration: const InputDecoration(
                                      labelText: 'Tarih',
                                      suffixIcon: Icon(Icons.date_range)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                                  controller: time,
                                  readOnly: true,
                                  onTap: chooseTime,
                                  decoration: const InputDecoration(
                                      labelText: 'Saat',
                                      suffixIcon: Icon(Icons.schedule))))
                        ]),
                        DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration:
                                const InputDecoration(labelText: 'Durum'),
                            items: statuses
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) =>
                                setModal(() => status = v ?? status)),
                        _field(notes, 'Notlar', maxLines: 3),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final body = {
                                if (appointment != null) 'id': data['id'],
                                'musteri_adi': name.text.trim(),
                                'telefon': phone.text.trim(),
                                'plaka': plate.text.trim().toUpperCase(),
                                'arac_bilgisi': vehicle.text.trim(),
                                'randevu_tarihi': date.text,
                                'randevu_saati': time.text,
                                'notlar': notes.text.trim(),
                                'durum': status
                              };
                              try {
                                if (appointment == null) {
                                  await ApiService.post('randevular.php', body);
                                } else {
                                  await ApiService.put('randevular.php', body);
                                }
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Randevu kaydedilemedi: $e')));
                                }
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Kaydet'))
                      ])));
            }));
    name.dispose();
    phone.dispose();
    plate.dispose();
    vehicle.dispose();
    date.dispose();
    time.dispose();
    notes.dispose();
    if (result == true) load();
  }

  Widget _field(TextEditingController controller, String label,
          {bool required = false, TextInputType? keyboard, int maxLines = 1}) =>
      TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Zorunlu alan' : null
              : null,
          decoration: InputDecoration(labelText: label));

  Color _color(String status) => switch (status) {
        'Tamamlandı' => Colors.green,
        'İptal' => Colors.red,
        _ => Colors.orange
      };

  Widget _statusPill(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _summaryMetric(String label, dynamic value, IconData icon) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: scheme.secondary),
          const SizedBox(height: 7),
          Text('$value',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              )),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: .65),
                fontWeight: FontWeight.w600,
              )),
        ]),
      ),
    );
  }

  Future<void> changeStatus(Map<String, dynamic> item, String status) async {
    try {
      await ApiService.put(
          'randevular.php', {'id': item['id'], 'durum': status});
      load();
    } catch (e) {
      _message('Durum güncellenemedi: $e');
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Randevu silinsin mi?'),
                content: Text(
                    '${item['musteri_adi']} adlı müşterinin randevusu silinecek.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sil'))
                ]));
    if (confirmed != true) return;
    try {
      await ApiService.delete('randevular.php', {'id': item['id']});
      load();
    } catch (e) {
      _message('Randevu silinemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Randevular'),
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
            label: const Text('Yeni randevu')),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(Icons.calendar_month_rounded,
                            color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Randevu merkezi',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 3),
                            Text('Günün akışını tek ekrandan takip edin',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onPrimaryContainer
                                      .withValues(alpha: .72),
                                )),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 15),
                    Row(children: [
                      _summaryMetric('Toplam', summary['toplam'] ?? 0,
                          Icons.event_note_rounded),
                      const SizedBox(width: 8),
                      _summaryMetric('Bekleyen', summary['bekleyen'] ?? 0,
                          Icons.schedule_rounded),
                      const SizedBox(width: 8),
                      _summaryMetric('Geciken', summary['geciken'] ?? 0,
                          Icons.notification_important_rounded),
                    ]),
                  ],
                ),
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
                          hintText: 'Müşteri, telefon, plaka veya araç ara',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                              tooltip: 'Ara',
                              onPressed: load,
                              icon: const Icon(Icons.arrow_forward_rounded)))),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final entry in const ['', ...statuses])
                          Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                  selected: filter == entry,
                                  label: Text(entry.isEmpty ? 'Tümü' : entry),
                                  onSelected: (_) {
                                    setState(() => filter = entry);
                                    load();
                                  }))
                      ])),
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final entry in const {
                          '': 'Tüm tarihler',
                          'geciken': 'Geciken',
                          'bugun': 'Bugün',
                          'gelecek': 'Gelecek'
                        }.entries)
                          Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                  selected: scope == entry.key,
                                  avatar: Icon(
                                    entry.key == 'geciken'
                                        ? Icons.warning_amber_rounded
                                        : Icons.calendar_today_rounded,
                                    size: 16,
                                  ),
                                  label: Text(entry.key == 'geciken'
                                      ? '${entry.value} (${summary['geciken'] ?? 0})'
                                      : entry.value),
                                  onSelected: (_) {
                                    setState(() => scope = entry.key);
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
              else if (appointments.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(children: [
                    Icon(Icons.event_busy_rounded,
                        size: 42, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text('Randevu bulunamadı.',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Filtreleri değiştirin veya yeni randevu ekleyin.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                )
              else
                ...appointments.map((raw) {
                  final item = Map<String, dynamic>.from(raw);
                  final status = '${item['durum'] ?? 'Bekliyor'}';
                  final color = _color(status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: scheme.surfaceContainerLow,
                      child: InkWell(
                        onTap: () => openForm(item),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(Icons.person_outline_rounded,
                                      color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['musteri_adi'] ?? '-'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          )),
                                      Text('${item['plaka'] ?? 'Plaka yok'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          )),
                                    ],
                                  ),
                                ),
                                _statusPill(status, color),
                                PopupMenuButton<String>(
                                    tooltip: 'Randevu işlemleri',
                                    onSelected: (v) {
                                      if (v == 'delete') {
                                        remove(item);
                                      } else {
                                        changeStatus(item, v);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                          ...statuses.map((e) => PopupMenuItem(
                                              value: e, child: Text(e))),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Sil',
                                                  style: TextStyle(
                                                      color: Colors.red)))
                                        ]),
                              ]),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: .55),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 17, color: scheme.secondary),
                                  const SizedBox(width: 7),
                                  Text('${item['randevu_tarihi'] ?? '-'}',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      )),
                                  const SizedBox(width: 14),
                                  Icon(Icons.schedule_rounded,
                                      size: 17, color: scheme.secondary),
                                  const SizedBox(width: 6),
                                  Text('${item['randevu_saati'] ?? '-'}',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      )),
                                ]),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                Icon(Icons.phone_outlined,
                                    size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text('${item['telefon'] ?? '-'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant)),
                                const SizedBox(width: 14),
                                Icon(Icons.directions_car_outlined,
                                    size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('${item['arac_bilgisi'] ?? '-'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      )),
                                ),
                              ]),
                              if ('${item['notlar'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 9),
                                Text('Not: ${item['notlar']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    )),
                              ],
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
