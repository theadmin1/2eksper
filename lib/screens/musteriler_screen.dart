import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'web_panel_screen.dart';

class MusterilerScreen extends StatefulWidget {
  const MusterilerScreen({super.key});

  @override
  State<MusterilerScreen> createState() => _MusterilerScreenState();
}

class _MusterilerScreenState extends State<MusterilerScreen> {
  final search = TextEditingController();
  bool loading = true;
  List<dynamic> customers = [];
  Map<String, dynamic> summary = {};
  String debtFilter = '';
  DateTimeRange? dateRange;

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
      final result = await ApiService.get('musteriler.php', queryParameters: {
        if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        if (debtFilter.isNotEmpty) 'borc': debtFilter,
        if (dateRange != null) 'bas': _iso(dateRange!.start),
        if (dateRange != null) 'bit': _iso(dateRange!.end)
      });
      if (!mounted) return;
      final data = ApiData.map(result['data']);
      setState(() {
        customers = ApiData.list(data['musteriler']);
        summary = ApiData.map(data['ozet']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _message('Müşteriler yüklenemedi: $e');
    }
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
  String _money(dynamic value) => '₺${_number(value).toStringAsFixed(2)}';
  String _iso(DateTime value) => value.toIso8601String().substring(0, 10);

  Future<void> chooseDateRange() async {
    final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: dateRange);
    if (selected != null) {
      setState(() => dateRange = selected);
      load();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openForm([Map<String, dynamic>? customer]) async {
    final c = customer ?? {};
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: '${c['ad_soyad'] ?? ''}');
    final tc = TextEditingController(text: '${c['tc_kimlik'] ?? ''}');
    final phone = TextEditingController(text: '${c['telefon'] ?? ''}');
    final plate = TextEditingController(text: '${c['plaka'] ?? ''}');
    final vehicle = TextEditingController(text: '${c['marka_model'] ?? ''}');
    final date = TextEditingController(
        text:
            '${c['satis_tarihi'] ?? DateTime.now().toIso8601String().substring(0, 10)}');
    final price = TextEditingController(text: '${c['satis_bedeli'] ?? ''}');
    final advance = TextEditingController(text: customer == null ? '' : '');
    final notes = TextEditingController(text: '${c['notlar'] ?? ''}');
    final vehiclePhotos = List<dynamic>.from(c['arac_fotolar'] ?? []);
    final licensePhotos = List<dynamic>.from(c['ruhsat_fotolar'] ?? []);
    final newVehiclePhotos = <XFile>[];
    final newLicensePhotos = <XFile>[];
    String paymentMethod = 'Nakit';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setModal) {
        Future<void> chooseDate() async {
          final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(date.text) ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          if (picked != null) {
            date.text = picked.toIso8601String().substring(0, 10);
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: ListView(shrinkWrap: true, children: [
              Text(
                  customer == null
                      ? 'Yeni müşteri / satış'
                      : 'Müşteriyi düzenle',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _field(name, 'Ad soyad *', required: true),
              _field(tc, 'T.C. kimlik no', keyboard: TextInputType.number),
              _field(phone, 'Telefon', keyboard: TextInputType.phone),
              _field(plate, 'Plaka *', required: true),
              _field(vehicle, 'Marka / model *', required: true),
              TextFormField(
                controller: date,
                readOnly: true,
                onTap: chooseDate,
                decoration: const InputDecoration(
                    labelText: 'Satış tarihi',
                    suffixIcon: Icon(Icons.date_range)),
              ),
              _field(price, 'Satış bedeli', keyboard: TextInputType.number),
              if (customer == null) ...[
                _field(advance, 'Alınan peşinat',
                    keyboard: TextInputType.number),
                DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration:
                        const InputDecoration(labelText: 'Ödeme yöntemi'),
                    items: const ['Nakit', 'Kredi Kartı', 'Havale / EFT', 'Çek']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setModal(() => paymentMethod = v ?? 'Nakit')),
              ],
              _field(notes, 'Notlar', maxLines: 3),
              const SizedBox(height: 12),
              Text('Araç fotoğrafları',
                  style: Theme.of(context).textTheme.titleMedium),
              _photoPicker(context, setModal, vehiclePhotos, newVehiclePhotos),
              const SizedBox(height: 12),
              Text('Ruhsat fotoğrafları',
                  style: Theme.of(context).textTheme.titleMedium),
              _photoPicker(context, setModal, licensePhotos, newLicensePhotos),
              const SizedBox(height: 18),
              FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final body = <String, dynamic>{
                      if (customer != null) 'id': c['id'],
                      'ad_soyad': name.text.trim(),
                      'tc_kimlik': tc.text.trim(),
                      'telefon': phone.text.trim(),
                      'plaka': plate.text.trim().toUpperCase(),
                      'marka_model': vehicle.text.trim(),
                      'satis_tarihi': date.text,
                      'satis_bedeli':
                          double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
                      'notlar': notes.text.trim(),
                      if (customer == null)
                        'alinan_pesinat': double.tryParse(
                                advance.text.replaceAll(',', '.')) ??
                            0,
                      if (customer == null) 'odeme_yontemi': paymentMethod,
                      'arac_fotolar': vehiclePhotos,
                      'ruhsat_fotolar': licensePhotos,
                      'yeni_arac_fotolar': [
                        for (final file in newVehiclePhotos)
                          {
                            'name': file.name,
                            'data': base64Encode(await file.readAsBytes())
                          }
                      ],
                      'yeni_ruhsat_fotolar': [
                        for (final file in newLicensePhotos)
                          {
                            'name': file.name,
                            'data': base64Encode(await file.readAsBytes())
                          }
                      ],
                    };
                    try {
                      if (customer == null) {
                        await ApiService.post('musteriler.php', body);
                      } else {
                        await ApiService.put('musteriler.php', body);
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kayıt hatası: $e')));
                      }
                    }
                  })
            ]),
          ),
        );
      }),
    );
    name.dispose();
    tc.dispose();
    phone.dispose();
    plate.dispose();
    vehicle.dispose();
    date.dispose();
    price.dispose();
    advance.dispose();
    notes.dispose();
    if (saved == true) load();
  }

  Widget _field(TextEditingController controller, String label,
      {bool required = false, TextInputType? keyboard, int maxLines = 1}) {
    return TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null
            : null,
        decoration: InputDecoration(labelText: label));
  }

  Widget _photoPicker(BuildContext context, StateSetter setModal,
      List<dynamic> existing, List<XFile> added) {
    Future<void> pick(ImageSource source) async {
      final picker = ImagePicker();
      final selected = source == ImageSource.gallery
          ? await picker.pickMultiImage(imageQuality: 85)
          : <XFile>[
              if (await picker.pickImage(source: source, imageQuality: 85)
                  case final photo?)
                photo
            ];
      setModal(() => added.addAll(selected));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
            onPressed: () => pick(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Kamera')),
        OutlinedButton.icon(
            onPressed: () => pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeri'))
      ]),
      for (var i = 0; i < existing.length; i++)
        ListTile(
            dense: true,
            leading: const Icon(Icons.image_outlined),
            title: Text('${existing[i]}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                onPressed: () => setModal(() => existing.removeAt(i)),
                icon: const Icon(Icons.delete_outline))),
      for (var i = 0; i < added.length; i++)
        ListTile(
            dense: true,
            leading: const Icon(Icons.add_photo_alternate),
            title: Text(added[i].name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                onPressed: () => setModal(() => added.removeAt(i)),
                icon: const Icon(Icons.close)))
    ]);
  }

  Future<void> openDetail(Map<String, dynamic> row) async {
    try {
      final response = await ApiService.get('musteriler.php',
          queryParameters: {'id': '${row['id']}'});
      if (!mounted) return;
      final data = ApiData.map(response['data']);
      final customer = ApiData.map(data['musteri']);
      final payments = ApiData.list(data['odemeler']);
      final linked = ApiData.map(data['rapor']);
      final linkedReport = linked.isEmpty ? null : linked;
      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(shrinkWrap: true, children: [
                Row(children: [
                  Expanded(
                      child: Text('${customer['ad_soyad']}',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () {
                        Navigator.pop(context);
                        openForm(customer);
                      },
                      icon: const Icon(Icons.edit)),
                  IconButton(
                      tooltip: 'Sil',
                      color: Colors.red,
                      onPressed: () async {
                        Navigator.pop(context);
                        await remove(customer);
                      },
                      icon: const Icon(Icons.delete_outline))
                ]),
                Text('${customer['plaka']} • ${customer['marka_model']}'),
                Text('Telefon: ${customer['telefon'] ?? '-'}'),
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _stat('Satış', _money(customer['satis_bedeli'])),
                              _stat('Tahsilat',
                                  _money(customer['alinan_pesinat'])),
                              _stat('Kalan', _money(customer['kalan_borc']),
                                  color: _number(customer['kalan_borc']) > 0
                                      ? Colors.red
                                      : Colors.green),
                            ]))),
                FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      addPayment(customer);
                    },
                    icon: const Icon(Icons.payments),
                    label: const Text('Tahsilat ekle')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (linkedReport == null) {
                        chooseReport(customer, null);
                      } else {
                        Navigator.push(
                            this.context,
                            MaterialPageRoute(
                                builder: (_) => WebPanelScreen(
                                    initialPath:
                                        'rapor.php?id=${linkedReport['uuid'] ?? linkedReport['id']}')));
                      }
                    },
                    icon: Icon(linkedReport == null
                        ? Icons.link
                        : Icons.picture_as_pdf),
                    label: Text(linkedReport == null
                        ? 'Ekspertiz raporu bağla'
                        : 'Bağlı raporu aç: ${linkedReport['rapor_no']}')),
                if (linkedReport != null)
                  TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        chooseReport(customer, linkedReport);
                      },
                      icon: const Icon(Icons.link_off),
                      label: const Text('Rapor bağlantısını kaldır')),
                const SizedBox(height: 16),
                Text('Ödeme geçmişi',
                    style: Theme.of(context).textTheme.titleMedium),
                if (payments.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Henüz ödeme kaydı yok.')),
                ...payments.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long),
                    title: Text(_money(p['tutar'])),
                    subtitle: Text('${p['odeme_tarihi']} • ${p['yontem']}'),
                    trailing: IconButton(
                        tooltip: 'Tahsilatı sil',
                        onPressed: () {
                          Navigator.pop(context);
                          removePayment(customer, p);
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red)))),
                const SizedBox(height: 12),
                Text('Araç ve ruhsat fotoğrafları',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if ([
                  ...List<dynamic>.from(customer['arac_fotolar'] ?? []),
                  ...List<dynamic>.from(customer['ruhsat_fotolar'] ?? [])
                ].isEmpty)
                  const Text('Fotoğraf eklenmemiş.'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...List<dynamic>.from(customer['arac_fotolar'] ?? [])
                      .map((photo) => _networkPhoto(photo, 'ARAÇ')),
                  ...List<dynamic>.from(customer['ruhsat_fotolar'] ?? [])
                      .map((photo) => _networkPhoto(photo, 'RUHSAT'))
                ])
              ])));
    } catch (e) {
      _message('Müşteri detayı açılamadı: $e');
    }
  }

  Widget _stat(String name, String value, {Color? color}) => Column(children: [
        Text(name, style: const TextStyle(fontSize: 12)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13))
      ]);

  String _customerInitial(dynamic value) {
    final name = '$value'.trim();
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  Widget _overviewMetric(
      String label, String value, IconData icon, Color accent) {
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
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
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

  Widget _debtPill(double debt) {
    final scheme = Theme.of(context).colorScheme;
    final hasDebt = debt > 0;
    final color = hasDebt ? scheme.error : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Text(
        hasDebt ? _money(debt) : 'Borçsuz',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _networkPhoto(dynamic path, String type) {
    final scheme = Theme.of(context).colorScheme;
    final raw = '$path'.replaceAll('\\', '/');
    final url = raw.startsWith('http')
        ? raw
        : '${ApiService.webRoot}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
    return SizedBox(
        width: 115,
        child: Column(children: [
          AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined,
                              color: scheme.onSurfaceVariant))))),
          Text(type, style: const TextStyle(fontSize: 10))
        ]));
  }

  Future<void> removePayment(
      Map<String, dynamic> customer, dynamic payment) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Tahsilat silinsin mi?'),
                content: Text(
                    '${_money(payment['tutar'])} tutarındaki kayıt silinecek.'),
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
      await ApiService.delete('musteriler.php', {
        'action': 'payment',
        'id': customer['id'],
        'odeme_id': payment['id']
      });
      load();
    } catch (e) {
      _message('Tahsilat silinemedi: $e');
    }
  }

  Future<void> chooseReport(
      Map<String, dynamic> customer, Map<String, dynamic>? linkedReport) async {
    if (linkedReport != null) {
      try {
        await ApiService.put('musteriler.php',
            {'action': 'unlink_report', 'id': customer['id']});
        load();
      } catch (e) {
        _message('Rapor bağlantısı kaldırılamadı: $e');
      }
      return;
    }
    try {
      final response = await ApiService.get('raporlar.php');
      final data = ApiData.map(response['data']);
      final reports = ApiData.list(data['raporlar']);
      if (!mounted) return;
      final selected = await showDialog<dynamic>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Ekspertiz raporu seçin'),
                  content: SizedBox(
                      width: double.maxFinite,
                      child: reports.isEmpty
                          ? const Text('Bağlanabilecek rapor bulunamadı.')
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: reports.length,
                              itemBuilder: (_, index) {
                                final report = reports[index];
                                return ListTile(
                                    title: Text(
                                        '${report['rapor_no']} • ${report['plaka']}'),
                                    subtitle: Text(
                                        '${report['musteri']} • ${report['tarih']}'),
                                    onTap: () =>
                                        Navigator.pop(context, report));
                              })),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Vazgeç'))
                  ]));
      if (selected == null) return;
      await ApiService.put('musteriler.php', {
        'action': 'link_report',
        'id': customer['id'],
        'rapor_id': selected['id']
      });
      load();
    } catch (e) {
      _message('Rapor bağlanamadı: $e');
    }
  }

  Future<void> addPayment(Map<String, dynamic> customer) async {
    final amount = TextEditingController();
    final description = TextEditingController();
    final paymentDate = TextEditingController(text: _iso(DateTime.now()));
    String method = 'Nakit';
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setDialog) {
              return AlertDialog(
                  title: const Text('Tahsilat ekle'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: amount,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tutar')),
                    TextField(
                        controller: paymentDate,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(paymentDate.text) ??
                                      DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) paymentDate.text = _iso(picked);
                        },
                        decoration: const InputDecoration(
                            labelText: 'Ödeme tarihi',
                            suffixIcon: Icon(Icons.date_range))),
                    DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(labelText: 'Yöntem'),
                        items: const [
                          'Nakit',
                          'Kredi Kartı',
                          'Havale / EFT',
                          'Çek'
                        ]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setDialog(() => method = v ?? 'Nakit')),
                    TextField(
                        controller: description,
                        decoration:
                            const InputDecoration(labelText: 'Açıklama'))
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () async {
                          final value = double.tryParse(
                                  amount.text.replaceAll(',', '.')) ??
                              0;
                          if (value <= 0) return;
                          try {
                            await ApiService.post('musteriler.php', {
                              'action': 'payment',
                              'id': customer['id'],
                              'tutar': value,
                              'yontem': method,
                              'aciklama': description.text.trim(),
                              'odeme_tarihi': paymentDate.text
                            });
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Tahsilat kaydedilemedi: $e')));
                            }
                          }
                        },
                        child: const Text('Kaydet'))
                  ]);
            }));
    amount.dispose();
    description.dispose();
    paymentDate.dispose();
    if (saved == true) load();
  }

  Future<void> remove(Map<String, dynamic> customer) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Müşteri silinsin mi?'),
                content: Text(
                    '${customer['ad_soyad']} ve bu müşterinin ödeme geçmişi silinecek.'),
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
      await ApiService.delete('musteriler.php', {'id': customer['id']});
      load();
    } catch (e) {
      _message('Müşteri silinemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Müşteriler'),
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
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Yeni müşteri')),
        body: RefreshIndicator(
            onRefresh: load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
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
                                  child: Icon(Icons.groups_2_rounded,
                                      color: scheme.onPrimary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Müşteri ve satış yönetimi',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            color: scheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w900,
                                          )),
                                      const SizedBox(height: 3),
                                      Text(
                                          'Satışları, tahsilatları ve raporları izleyin',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.onPrimaryContainer
                                                .withValues(alpha: .72),
                                          )),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 15),
                              Row(children: [
                                _overviewMetric(
                                    'Müşteri',
                                    '${summary['adet'] ?? customers.length}',
                                    Icons.people_alt_rounded,
                                    scheme.secondary),
                                const SizedBox(width: 8),
                                _overviewMetric(
                                    'Toplam ciro',
                                    _money(summary['ciro']),
                                    Icons.trending_up_rounded,
                                    Colors.green),
                                const SizedBox(width: 8),
                                _overviewMetric(
                                    'Alacak',
                                    _money(summary['alacak']),
                                    Icons.account_balance_wallet_rounded,
                                    scheme.error),
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
                                    hintText:
                                        'Ad, telefon, plaka veya araç ara',
                                    prefixIcon:
                                        const Icon(Icons.search_rounded),
                                    suffixIcon: IconButton(
                                        tooltip: 'Ara',
                                        onPressed: load,
                                        icon: const Icon(
                                            Icons.arrow_forward_rounded)))),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (final entry in const {
                                    '': 'Tümü',
                                    '1': 'Borçlular',
                                    '0': 'Borcu kapananlar'
                                  }.entries)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(right: 7),
                                        child: ChoiceChip(
                                            selected: debtFilter == entry.key,
                                            label: Text(entry.value),
                                            onSelected: (_) {
                                              setState(
                                                  () => debtFilter = entry.key);
                                              load();
                                            })),
                                  ActionChip(
                                      avatar: const Icon(
                                          Icons.date_range_rounded,
                                          size: 18),
                                      label: Text(dateRange == null
                                          ? 'Tarih aralığı'
                                          : '${_iso(dateRange!.start)} / ${_iso(dateRange!.end)}'),
                                      onPressed: chooseDateRange),
                                  if (dateRange != null)
                                    IconButton(
                                        tooltip: 'Tarih filtresini temizle',
                                        onPressed: () {
                                          setState(() => dateRange = null);
                                          load();
                                        },
                                        icon: const Icon(Icons.close_rounded))
                                ])),
                          ]),
                        ),
                      ]))),
              if (loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (customers.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded,
                                size: 44, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text('Müşteri bulunamadı.',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                'Filtreleri değiştirin veya yeni müşteri ekleyin.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ))
              else
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: SliverList.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final item =
                              Map<String, dynamic>.from(customers[index]);
                          final debt = _number(item['kalan_borc']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              color: scheme.surfaceContainerLow,
                              child: InkWell(
                                onTap: () => openDetail(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: scheme.secondary
                                              .withValues(alpha: .13),
                                          borderRadius:
                                              BorderRadius.circular(17),
                                        ),
                                        child: Text(
                                          _customerInitial(item['ad_soyad']),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            color: scheme.secondary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                child: Text(
                                                    '${item['ad_soyad'] ?? 'İsimsiz'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    )),
                                              ),
                                              _debtPill(debt),
                                            ]),
                                            const SizedBox(height: 6),
                                            Row(children: [
                                              Icon(Icons.phone_outlined,
                                                  size: 15,
                                                  color:
                                                      scheme.onSurfaceVariant),
                                              const SizedBox(width: 6),
                                              Text('${item['telefon'] ?? '-'}',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  )),
                                            ]),
                                            const SizedBox(height: 7),
                                            Row(children: [
                                              Icon(
                                                  Icons.directions_car_outlined,
                                                  size: 16,
                                                  color:
                                                      scheme.onSurfaceVariant),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                    '${item['plaka'] ?? '-'} • ${item['marka_model'] ?? '-'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    )),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.chevron_right_rounded,
                                                  color:
                                                      scheme.onSurfaceVariant),
                                            ]),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }))
            ])));
  }
}
