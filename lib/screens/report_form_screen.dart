import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/body_map_editor.dart';
import 'web_panel_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final String? reportId;
  final Map<String, dynamic>? initialVehicle;
  const ReportFormScreen({super.key, this.reportId, this.initialVehicle});
  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  bool loading = false, saving = false;
  String saveStage = '';
  Timer? _draftTimer;
  String _serverSignature = '';
  String _serverUpdatedAt = '';
  String _lastDraftSignature = '';
  bool _allowExit = false;
  bool _polygonsTouched = false;
  final _bodyMapKey = GlobalKey<BodyMapEditorState>();
  final c = <String, TextEditingController>{};
  Map<String, String> body = {}, inner = {}, airbag = {}, tests = {};
  List<dynamic> polygons = [], existingPhotos = [];
  List<dynamic> deliveryReports = [];
  final newPhotos = <XFile>[];
  String operation = 'genel', status = 'taslak';
  String? activeReportId;

  static const vehicle = {
    'telefon': 'Müşteri Telefon',
    'marka_model': 'Marka / Model',
    'model_yili': 'Model Yılı',
    'yakit_turu': 'Yakıt Türü',
    'vites_turu': 'Vites Türü',
    'kasa_tipi': 'Kasa Tipi',
    'tescil_tarihi': 'Tescil / İlk Tescil',
    'muayene_tarihi': 'Muayene Geçerlilik',
    'renk': 'Araç Rengi',
    'motor_hp': 'Motor HP / Gücü',
    'kilometre': 'Kilometre',
    'cekis_tipi': 'Çekiş Tipi',
    'sasi': 'Şasi Numarası'
  };
  static const outer = {
    'front-bumper': 'Ön Tampon',
    'front-hood': 'Kaput',
    'roof': 'Tavan',
    'rear-hood': 'Arka Bagaj Kapağı',
    'rear-bumper': 'Arka Tampon',
    'front-left-mudguard': 'Sol Ön Çamurluk',
    'front-left-door': 'Sol Ön Kapı',
    'rear-left-door': 'Sol Arka Kapı',
    'rear-left-mudguard': 'Sol Arka Çamurluk',
    'front-right-mudguard': 'Sağ Ön Çamurluk',
    'front-right-door': 'Sağ Ön Kapı',
    'rear-right-door': 'Sağ Arka Kapı',
    'rear-right-mudguard': 'Sağ Arka Çamurluk'
  };
  static const inside = {
    'sol_ic_direk': 'Sol İç Direk',
    'sol_ust_direk': 'Sol Üst Direk',
    'arka_panel': 'Arka Panel',
    'arka_havuz': 'Arka Havuz Sacı',
    'sag_ic_direk': 'Sağ İç Direk',
    'sag_ust_direk': 'Sağ Üst Direk',
    'on_panel': 'Ön Panel',
    'sag_on_sase': 'Sağ Ön Şase',
    'sol_on_sase': 'Sol Ön Şase',
    'sol_ic_podya': 'Sol İç Podya',
    'ic_podya': 'İç Podya (Sağ/Sol)',
    'arka_sag_sase': 'Arka Sağ Şase',
    'arka_sol_sase': 'Arka Sol Şase',
    'sol_marspiyel': 'Sol Marşpiyel',
    'sag_marspiyel': 'Sağ Marşpiyel'
  };
  static const airbags = {
    'airbag_direksiyon': 'Direksiyon Airbag',
    'airbag_torpido': 'Torpido Airbag',
    'airbag_tavan': 'Tavan Airbag',
    'airbag_koltuk_diz': 'Koltuk ve Diz Airbag',
    'emniyet_kemerleri': 'Emniyet Kemerleri'
  };
  static const motor = {
    'motor_genel': 'Hava Filtre Kabin',
    'motor_isi': 'Isı ve Ses İzolasyon',
    'motor_enjektor': 'Enjektör Kontrolü',
    'motor_yakit': 'Yakıt Sistemi',
    'motor_yag_sogutucu': 'Yağ Soğutucusu',
    'turbo': 'Turbo Kontrolleri',
    'motor_fren': 'Fren Hidroliği',
    'motor_buhar': 'Motor Buharı / Üfleme',
    'motor_antifriz': 'Antifriz / Yağ Seviye',
    'motor_fan': 'Soğutma Fanları',
    'motor_su_radyator': 'Su Radyatörü',
    'motor_klima': 'Klima Radyatörü',
    'yag_kacak': 'Motor Yağı Sızdırmazlık',
    'motor_elektrik': 'Motor Elektrik Tesisatı'
  };
  static const mechanic = {
    'mek_lastik_sol_on': 'Lastik (Sol Ön)',
    'mek_lastik_sag_on': 'Lastik (Sağ Ön)',
    'mek_lastik_sol_arka': 'Lastik (Sol Arka)',
    'mek_lastik_sag_arka': 'Lastik (Sağ Arka)',
    'mek_jant_sol_on': 'Jant Kondisyonu',
    'mek_rot': 'Rot Kolları / Başları',
    'mek_aks': 'Aks Kontrolü',
    'mek_fren_disk_sol': 'Fren Disk (Sol)',
    'mek_fren_disk_sag': 'Fren Disk (Sağ)',
    'fren_balata': 'Fren Balataları',
    'sanziman': 'Şanzıman Alt Kontrolü',
    'mek_egzoz': 'Egzoz Sistemi',
    'mek_sanziman_kacak': 'Şanzıman Yağ Kaçakları'
  };
  static const cosmetic = {
    'dis_sase': 'Şase No Eşleştirme',
    'dis_korna': 'Korna Fonksiyonu',
    'dis_el_fren': 'El Freni',
    'dis_cam': 'Camlar ve Krikolar',
    'dis_torpido': 'Torpido & Göğüs',
    'dis_sunroof': 'Sunroof / Cam Tavan',
    'dis_gosterge': 'Gösterge ve İkazlar',
    'klima': 'Klima Performansı',
    'dis_koltuk': 'Koltuk Döşemeleri',
    'dis_direksiyon': 'Direksiyon Kumandaları'
  };

  @override
  void initState() {
    super.initState();
    activeReportId = widget.reportId;
    tabs = TabController(length: 9, vsync: this);
    tabs.addListener(_handleTabChanged);
    for (final k in [
      'rapor_no',
      'tarih',
      'plaka',
      'musteri',
      'sozlesme_no',
      'referans_rapor_id',
      'uzman_notu',
      'sube',
      'teslim_eden',
      'teslim_alan',
      'surucu',
      'yakit_seviyesi',
      'aksesuarlar',
      'temizlik_durumu',
      'hasar_sorumlulugu',
      'operasyon_notu',
      'alis_fiyati',
      'tahmini_masraf',
      'hedef_satis',
      'hasar_bedeli',
      'depozito',
      'test_wurth_not',
      'diag_not',
      'test_yol_not',
      ...vehicle.keys
    ]) {
      c[k] = TextEditingController();
    }
    c['rapor_no']!.text = 'MD-${DateTime.now().millisecondsSinceEpoch}';
    final n = DateTime.now();
    c['tarih']!.text =
        '${n.day.toString().padLeft(2, '0')}.${n.month.toString().padLeft(2, '0')}.${n.year}';
    body = {for (final k in outer.keys) k: 'orijinal'};
    inner = {for (final k in inside.keys) k: 'orijinal'};
    airbag = {for (final k in airbags.keys) k: 'ORİJİNAL'};
    tests = {
      for (final k in [
        ...motor.keys,
        ...mechanic.keys,
        ...cosmetic.keys,
        'test_wurth',
        'diag',
        'test_yol'
      ])
        k: 'KUSURSUZ'
    };
    c['uzman_notu']!.text =
        'Araç üzerinde yapılan fiziki, elektronik ve mekanik testler sonucunda yukarıdaki veriler elde edilmiştir.';
    if (widget.reportId == null && widget.initialVehicle != null) {
      setText('plaka', widget.initialVehicle!['plaka']);
      setText('sasi', widget.initialVehicle!['sasi']);
      setText('marka_model', widget.initialVehicle!['marka_model']);
      setText('model_yili', widget.initialVehicle!['model_yili']);
      setText('kilometre', widget.initialVehicle!['kilometre']);
    }
    loadDeliveryReports();
    _initializeDraftState();
  }

  @override
  void dispose() {
    tabs.removeListener(_handleTabChanged);
    _draftTimer?.cancel();
    tabs.dispose();
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  void setText(String k, dynamic v) => c[k]?.text = '${v ?? ''}';

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  String get _draftKey => 'report_draft_${widget.reportId ?? 'new'}';

  Map<String, dynamic> _draftSnapshot() => {
        'fields': {for (final entry in c.entries) entry.key: entry.value.text},
        'body': body,
        'inner': inner,
        'airbag': airbag,
        'tests': tests,
        'polygons': polygons,
        'polygons_touched': _polygonsTouched,
        'existing_photos': existingPhotos,
        'new_photo_paths': newPhotos.map((photo) => photo.path).toList(),
        'operation': operation,
        'status': status,
        'active_report_id': activeReportId,
        'base_updated_at': _serverUpdatedAt,
        'step': tabs.index,
      };

  String _currentSignature() => jsonEncode(_draftSnapshot());

  String _contentSignature() {
    final snapshot = _draftSnapshot()
      ..remove('step')
      ..remove('polygons_touched');
    return jsonEncode(snapshot);
  }

  bool get _hasUnsavedChanges =>
      _serverSignature.isNotEmpty && _contentSignature() != _serverSignature;

  Future<void> _initializeDraftState() async {
    if (activeReportId != null) await load();
    if (!mounted) return;
    _serverSignature = _contentSignature();
    await _restoreLocalDraft();
    _lastDraftSignature = _currentSignature();
    _draftTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _saveLocalDraft(),
    );
  }

  Future<void> _restoreLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final draft = ApiData.map(jsonDecode(raw));
      final draftBase = '${draft['base_updated_at'] ?? ''}'.trim();
      if (activeReportId != null &&
          draftBase.isNotEmpty &&
          _serverUpdatedAt.isNotEmpty &&
          draftBase != _serverUpdatedAt) {
        final restore = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                icon: const Icon(Icons.sync_problem_rounded),
                title: const Text('Sunucuda daha yeni kayıt var'),
                content: const Text(
                  'Bu cihazdaki taslak daha eski bir rapor sürümüne ait. Sunucudaki güncel kaydı kullanabilir veya yerel taslağı açabilirsiniz.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Sunucudakini Kullan'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Yerel Taslağı Aç'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!restore) {
          await prefs.remove(_draftKey);
          return;
        }
      }
      final fields = ApiData.map(draft['fields']);
      for (final entry in fields.entries) {
        setText(entry.key, entry.value);
      }
      body = ApiData.map(draft['body']).map((k, v) => MapEntry(k, '$v'));
      inner = ApiData.map(draft['inner']).map((k, v) => MapEntry(k, '$v'));
      airbag = ApiData.map(draft['airbag']).map((k, v) => MapEntry(k, '$v'));
      tests = ApiData.map(draft['tests']).map((k, v) => MapEntry(k, '$v'));
      final draftPolygons = ApiData.list(draft['polygons']);
      final polygonsTouched = draft['polygons_touched'] == true;
      if (polygonsTouched || polygons.isEmpty || draftPolygons.isNotEmpty) {
        polygons = draftPolygons;
      }
      _polygonsTouched = polygonsTouched;
      existingPhotos = ApiData.list(draft['existing_photos'], wrapString: true);
      newPhotos.clear();
      for (final path in ApiData.list(draft['new_photo_paths'])) {
        final file = File('$path');
        if (await file.exists()) newPhotos.add(XFile(file.path));
      }
      operation = '${draft['operation'] ?? operation}';
      status = '${draft['status'] ?? status}';
      activeReportId = '${draft['active_report_id'] ?? activeReportId ?? ''}';
      if (activeReportId!.isEmpty) activeReportId = null;
      final step = (draft['step'] as num?)?.toInt() ?? 0;
      tabs.index = step.clamp(0, tabs.length - 1).toInt();
      if (mounted) {
        setState(() {});
        _message('Kaydedilmemiş taslak geri yüklendi.');
      }
    } catch (_) {
      await prefs.remove(_draftKey);
    }
  }

  Future<void> _saveLocalDraft({bool force = false}) async {
    if (loading || saving) return;
    final signature = _currentSignature();
    if (!force && signature == _lastDraftSignature) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, signature);
    _lastDraftSignature = signature;
  }

  Future<void> _clearLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    _serverSignature = _contentSignature();
    _lastDraftSignature = _currentSignature();
  }

  Future<void> _confirmExit() async {
    if (!_hasUnsavedChanges) {
      setState(() => _allowExit = true);
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.edit_note_rounded, size: 38),
        title: const Text('Değişiklikler kaybolmasın'),
        content: const Text(
          'Bu raporda sunucuya gönderilmemiş değişiklikler var. Taslak olarak cihazda saklayabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'stay'),
            child: const Text('Düzenlemeye Devam'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Değişiklikleri Sil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Taslağı Kaydet ve Çık'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'stay') return;
    if (action == 'discard') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } else {
      await _saveLocalDraft(force: true);
    }
    if (!mounted) return;
    setState(() => _allowExit = true);
    Navigator.pop(context);
  }

  Future<void> loadDeliveryReports() async {
    try {
      final response = await ApiService.get('raporlar.php',
          queryParameters: {'islem_turu': 'rent_teslim'});
      if (mounted) {
        final data = ApiData.map(response['data']);
        setState(() => deliveryReports = ApiData.list(data['raporlar']));
      }
    } catch (_) {
      // Referans seçimi zorunlu değildir; ana form çalışmaya devam eder.
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await ApiService.get('raporlar.php',
          queryParameters: {'id': activeReportId!});
      final responseData = ApiData.map(r['data']);
      final x = ApiData.map(responseData['rapor']);
      if (x.isEmpty) {
        throw const ApiException('Sunucu rapor detayını boş gönderdi.');
      }
      for (final k in [
        'rapor_no',
        'tarih',
        'plaka',
        'musteri',
        'sozlesme_no',
        'referans_rapor_id',
        'uzman_notu'
      ]) {
        setText(k, x[k]);
      }
      operation = '${x['islem_turu'] ?? 'genel'}';
      status = '${x['durum'] ?? 'taslak'}';
      final a = ApiData.map(x['arac_bilgileri']);
      for (final k in vehicle.keys) {
        setText(k, a[k]);
      }
      final bodyData = ApiData.map(x['kaporta_data']);
      body.addAll(bodyData.map((k, v) => MapEntry(k, '$v')));
      inner = {for (final k in inside.keys) k: '${bodyData[k] ?? 'orijinal'}'};
      final airbagData = ApiData.map(x['airbag_data']);
      airbag = {
        for (final k in airbags.keys) k: '${airbagData[k] ?? 'ORİJİNAL'}'
      };
      final td = ApiData.map(x['test_data']);
      for (final k in tests.keys) {
        tests[k] = '${td[k] ?? 'KUSURSUZ'}';
      }
      for (final k in ['test_wurth_not', 'diag_not', 'test_yol_not']) {
        setText(k, td[k]);
      }
      final op = ApiData.map(x['operasyon_data']);
      for (final k in [
        'sube',
        'teslim_eden',
        'teslim_alan',
        'surucu',
        'yakit_seviyesi',
        'aksesuarlar',
        'temizlik_durumu',
        'hasar_sorumlulugu',
        'operasyon_notu'
      ]) {
        setText(k, op[k]);
      }
      final cost = ApiData.map(x['maliyet_data']);
      for (final k in [
        'alis_fiyati',
        'tahmini_masraf',
        'hedef_satis',
        'hasar_bedeli',
        'depozito'
      ]) {
        setText(k, cost[k]);
      }
      polygons = ApiData.list(x['nokta_data']);
      _polygonsTouched = false;
      existingPhotos = ApiData.list(x['foto_yolu'], wrapString: true);
      _serverUpdatedAt = '${x['guncelleme_tarihi'] ?? ''}'.trim();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Rapor yüklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pick(ImageSource source) async {
    if (existingPhotos.length + newPhotos.length >= 12) {
      _message('Bir rapora en fazla 12 fotoğraf eklenebilir.');
      return;
    }
    final list = source == ImageSource.gallery
        ? await ImagePicker().pickMultiImage(
            imageQuality: 68,
            maxWidth: 1280,
            maxHeight: 960,
          )
        : <XFile>[
            if (await ImagePicker().pickImage(
                    source: source,
                    imageQuality: 68,
                    maxWidth: 1280,
                    maxHeight: 960)
                case final f?)
              f
          ];
    final available = 12 - existingPhotos.length - newPhotos.length;
    if (!mounted) return;
    setState(() => newPhotos.addAll(list.take(available)));
    if (list.length > available) {
      _message('Fotoğraf sınırı nedeniyle yalnızca $available görsel eklendi.');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Map<String, String> mapOf(List<String> keys) =>
      {for (final k in keys) k: c[k]!.text.trim()};
  Future<void> save() async {
    if (c['plaka']!.text.trim().isEmpty ||
        c['marka_model']!.text.trim().isEmpty ||
        c['sasi']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plaka, marka/model ve şasi zorunludur.')));
      tabs.animateTo(0);
      return;
    }
    final pendingPoints = _bodyMapKey.currentState?.pendingPointCount ?? 0;
    if (pendingPoints > 0 && pendingPoints < 3) {
      tabs.animateTo(2);
      _message(
        'Çizim tamamlanmadı. En az 3 nokta ekleyin veya “Geri Al” ile iptal edin.',
      );
      return;
    }
    final pendingPolygon = _bodyMapKey.currentState?.takePendingPolygon();
    if (pendingPolygon != null) {
      polygons = List<dynamic>.from(polygons)..add(pendingPolygon);
      _polygonsTouched = true;
    }
    setState(() {
      saving = true;
      saveStage = 'Sunucu bağlantısı kontrol ediliyor';
    });
    try {
      final serverCheck = await ApiService.get(
        'raporlar.php',
        queryParameters: const {'search': '__mobile_api_version_check__'},
      );
      final serverCheckData = ApiData.map(serverCheck['data']);
      final reportRevision =
          int.tryParse('${serverCheckData['report_api_revision'] ?? serverCheck['report_api_revision'] ?? 0}') ?? 0;
      final bool hasApiVersion = serverCheck['api_version'] != null && '${serverCheck['api_version']}'.isNotEmpty;
      
      if ((hasApiVersion && !ApiService.isCompatible(serverCheck)) ||
          (reportRevision > 0 && reportRevision < ApiService.requiredReportApiRevision)) {
        throw const ApiException(
          'Sunucudaki rapor servisi bu uygulamayla uyumlu değil. v1.5.0 paketindeki api/v1/raporlar.php dosyasını yükleyin; kayıt gönderilmedi.',
        );
      } else if (!hasApiVersion && reportRevision == 0) {
        debugPrint('Uyarı: Sunucu API versiyon bilgisi eksik, işleme devam ediliyor.');
      }
      if (mounted) setState(() => saveStage = 'Rapor bilgileri kaydediliyor');
      final kaporta = <String, String>{...body, ...inner};
      final testData = <String, String>{
        ...tests,
        'test_wurth_not': c['test_wurth_not']!.text,
        'diag_not': c['diag_not']!.text,
        'test_yol_not': c['test_yol_not']!.text
      };
      final payload = {
        'id': activeReportId,
        if (activeReportId != null && _serverUpdatedAt.isNotEmpty)
          'base_updated_at': _serverUpdatedAt,
        'rapor_no': c['rapor_no']!.text,
        'tarih': c['tarih']!.text,
        'plaka': c['plaka']!.text,
        'musteri': c['musteri']!.text,
        'sozlesme_no': c['sozlesme_no']!.text,
        'referans_rapor_id': c['referans_rapor_id']!.text,
        'islem_turu': operation,
        'durum': status,
        'uzman_notu': c['uzman_notu']!.text,
        'arac_bilgileri': mapOf(vehicle.keys.toList()),
        'kaporta_data': kaporta,
        'airbag_data': airbag,
        'test_data': testData,
        'nokta_data': polygons,
        'operasyon_data': mapOf([
          'sube',
          'teslim_eden',
          'teslim_alan',
          'surucu',
          'yakit_seviyesi',
          'aksesuarlar',
          'temizlik_durumu',
          'hasar_sorumlulugu',
          'operasyon_notu'
        ]),
        'maliyet_data': mapOf([
          'alis_fiyati',
          'tahmini_masraf',
          'hedef_satis',
          'hasar_bedeli',
          'depozito'
        ]),
        'foto_yolu': existingPhotos,
        'yeni_fotolar': <dynamic>[],
      };
      // Önce küçük metin/veri kaydı yapılır. Fotoğraflar ayrı küçük partilerle
      // gönderildiği için PHP post_max_size ve zayıf bağlantı sınırları aşılmaz.
      var response = await ApiService.post(
        'raporlar.php',
        payload,
      );
      final savedResponseData = ApiData.map(response['data']);
      final savedRevision =
          int.tryParse('${savedResponseData['report_api_revision'] ?? response['report_api_revision'] ?? 0}') ?? 0;
      final bool hasSavedApiVersion = response['api_version'] != null && '${response['api_version']}'.isNotEmpty;
      
      if ((hasSavedApiVersion && !ApiService.isCompatible(response)) ||
          (savedRevision > 0 && savedRevision < ApiService.requiredReportApiRevision)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Uyarı: Rapor servisi eski sürüm veya doğrulanamadı.')));
        }
      }
      var responseData = savedResponseData;
      var saved = ApiData.map(responseData['rapor']);
      if (saved.isEmpty && responseData.containsKey('id')) saved = responseData;
      var identifier =
          saved['uuid'] ?? saved['id'] ?? activeReportId ?? payload['rapor_no'];
      if (identifier == null || '$identifier'.trim().isEmpty) {
        throw const ApiException(
            'Sunucu kaydı oluşturdu ancak rapor kimliğini göndermedi.');
      }
      activeReportId = '${saved['id'] ?? activeReportId ?? identifier}';
      existingPhotos = ApiData.list(saved['foto_yolu'], wrapString: true);

      final totalPhotos = newPhotos.length;
      var uploaded = 0;
      while (newPhotos.isNotEmpty) {
        final batchFiles = List<XFile>.from(newPhotos.take(1));
        if (mounted) {
          setState(() =>
              saveStage = 'Fotoğraflar yükleniyor • $uploaded/$totalPhotos');
        }
        final batch = <Map<String, String>>[];
        for (final file in batchFiles) {
          final bytes = await file.readAsBytes();
          if (bytes.length > 4 * 1024 * 1024) {
            throw ApiException('${file.name} sıkıştırılmış olsa da çok büyük.');
          }
          batch.add({'name': file.name, 'data': base64Encode(bytes)});
        }
        final uploadPayload = <String, dynamic>{
          ...payload,
          'id': activeReportId,
          'foto_yolu': existingPhotos,
          'yeni_fotolar': batch,
        };
        response = await ApiService.post(
          'raporlar.php',
          uploadPayload,
          isUpload: true,
        );
        responseData = ApiData.map(response['data']);
        saved = ApiData.map(responseData['rapor']);
        if (saved.isEmpty) {
          throw const ApiException(
              'Fotoğraf yüklendi ancak sunucu güncel raporu göndermedi.');
        }
        identifier = saved['uuid'] ?? saved['id'] ?? identifier;
        existingPhotos = ApiData.list(saved['foto_yolu'], wrapString: true);
        uploaded += batchFiles.length;
        if (!mounted) return;
        setState(() {
          newPhotos.removeWhere(
            (photo) => batchFiles.any((done) => done.path == photo.path),
          );
          saveStage = 'Fotoğraflar yükleniyor • $uploaded/$totalPhotos';
        });
      }

      if (mounted) setState(() => saveStage = 'Sunucu kaydı doğrulanıyor');
      final verification = await ApiService.get(
        'raporlar.php',
        queryParameters: {'id': '$identifier'},
      );
      final verifiedData = ApiData.map(verification['data']);
      final verified = ApiData.map(verifiedData['rapor']);
      _validateServerRecord(payload, verified);
      if (!mounted) return;
      setState(() {
        activeReportId = '${verified['id'] ?? identifier}';
        existingPhotos = ApiData.list(
          verified['foto_yolu'],
          wrapString: true,
        );
        _polygonsTouched = false;
        _serverUpdatedAt = '${verified['guncelleme_tarihi'] ?? ''}'.trim();
        saveStage = '';
      });
      await _clearLocalDraft();
      await _showSaveSuccess(
        verified,
        '${response['message'] ?? 'Rapor kaydedildi'}',
      );
    } catch (e) {
      if (mounted) await _showSaveError('$e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          saveStage = '';
        });
      }
    }
  }

  void _validateServerRecord(
    Map<String, dynamic> sent,
    Map<String, dynamic> received,
  ) {
    if (received.isEmpty) {
      throw const ApiException(
          'Sunucu kayıt cevabı verdi ancak rapor tekrar okunamadı.');
    }
    final mismatches = <String>[];
    for (final field in [
      'rapor_no',
      'tarih',
      'plaka',
      'musteri',
      'sozlesme_no',
      'islem_turu',
      'durum',
      'uzman_notu',
    ]) {
      if (!_sameValue(sent[field], received[field])) mismatches.add(field);
    }
    for (final entry in <String, dynamic>{
      'araç bilgileri': sent['arac_bilgileri'],
      'kaporta': sent['kaporta_data'],
      'airbag': sent['airbag_data'],
      'testler': sent['test_data'],
      'operasyon': sent['operasyon_data'],
    }.entries) {
      if (!_sameMap(entry.value, received[_serverKey(entry.key)])) {
        mismatches.add(entry.key);
      }
    }
    if (!_sameCostMap(sent['maliyet_data'], received['maliyet_data'])) {
      mismatches.add('maliyet');
    }
    if (!_sameJsonList(sent['nokta_data'], received['nokta_data'])) {
      mismatches.add('hasar çizimleri');
    }
    if (mismatches.isNotEmpty) {
      throw ApiException(
        'Rapor sunucuya gönderildi fakat yeniden okunan kayıtta şu alanlar farklı geldi: ${mismatches.join(', ')}. Sayfayı yenileyip tekrar deneyin; sorun sürerse bu alanların değerlerini destek ekibine iletin.',
      );
    }
  }

  String _serverKey(String label) => switch (label) {
        'araç bilgileri' => 'arac_bilgileri',
        'kaporta' => 'kaporta_data',
        'airbag' => 'airbag_data',
        'testler' => 'test_data',
        'operasyon' => 'operasyon_data',
        _ => label,
      };

  bool _sameValue(dynamic first, dynamic second) =>
      '${first ?? ''}'.trim() == '${second ?? ''}'.trim();

  bool _sameMap(dynamic first, dynamic second) {
    final sentMap = ApiData.map(first);
    final receivedMap = ApiData.map(second);
    return sentMap.entries.every(
      (entry) => _sameValue(entry.value, receivedMap[entry.key]),
    );
  }

  bool _sameCostMap(dynamic first, dynamic second) {
    final sentMap = ApiData.map(first);
    final receivedMap = ApiData.map(second);
    return sentMap.entries.every((entry) {
      final sentText = '${entry.value ?? ''}'.trim();
      final receivedText = '${receivedMap[entry.key] ?? ''}'.trim();
      // Sunucu boş maliyet alanlarını veritabanına 0 olarak yazar. Bu veri
      // normalizasyonudur; kayıt uyuşmazlığı olarak kullanıcıya gösterilmemeli.
      final sentNumber = sentText.isEmpty
          ? 0.0
          : double.tryParse(sentText.replaceAll(',', '.'));
      final receivedNumber = receivedText.isEmpty
          ? 0.0
          : double.tryParse(receivedText.replaceAll(',', '.'));
      if (sentNumber != null && receivedNumber != null) {
        return (sentNumber - receivedNumber).abs() < .01;
      }
      return _sameValue(entry.value, receivedMap[entry.key]);
    });
  }

  bool _sameJsonList(dynamic first, dynamic second) =>
      _sameJsonValue(ApiData.list(first), ApiData.list(second));

  bool _sameJsonValue(dynamic first, dynamic second) {
    if (first is num && second is num) {
      return (first.toDouble() - second.toDouble()).abs() < .001;
    }
    if (first is Map && second is Map) {
      if (first.length != second.length) return false;
      return first.entries.every(
        (entry) =>
            second.containsKey(entry.key) &&
            _sameJsonValue(entry.value, second[entry.key]),
      );
    }
    if (first is List && second is List) {
      if (first.length != second.length) return false;
      for (var index = 0; index < first.length; index++) {
        if (!_sameJsonValue(first[index], second[index])) return false;
      }
      return true;
    }
    return _sameValue(first, second);
  }

  Future<void> _showSaveSuccess(
      Map<String, dynamic> report, String message) async {
    if (tabs.index < tabs.length - 1) {
      _message('Değişiklikler sunucuya kaydedildi.');
      return;
    }
    final identifier = report['uuid'] ?? report['id'] ?? activeReportId;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFE7F8EF),
                child: Icon(Icons.check_rounded,
                    size: 34, color: Color(0xFF079455)),
              ),
              const SizedBox(height: 12),
              Text(message,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('Değişiklikler sunucuya başarıyla aktarıldı.'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'continue'),
                      child: const Text('Düzenlemeye Devam'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: identifier == null
                          ? null
                          : () => Navigator.pop(context, 'pdf'),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF Aç'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'close'),
                child: const Text('Raporlara Dön'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'pdf' && identifier != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              WebPanelScreen(initialPath: 'rapor.php?id=$identifier'),
        ),
      );
    } else if (action == 'close') {
      Navigator.pop(context, true);
    }
  }

  Future<void> _showSaveError(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded,
            size: 42, color: Colors.red),
        title: const Text('Rapor kaydedilemedi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              save();
            },
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  static const _stepTitles = [
    'Araç',
    'Operasyon',
    'Dış Kaporta',
    'İç Kaporta',
    'Airbag',
    'Motor',
    'Mekanik',
    'Testler',
    'Not & Fotoğraf',
  ];

  Widget field(
    String key,
    String label, {
    TextInputType? type,
    int lines = 1,
    bool readOnly = false,
  }) {
    final refreshKeys = {
      'alis_fiyati',
      'tahmini_masraf',
      'hedef_satis',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c[key],
        keyboardType: type,
        maxLines: lines,
        readOnly: readOnly,
        textCapitalization: {'plaka', 'sasi'}.contains(key)
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        onChanged: refreshKeys.contains(key) ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline_rounded, size: 19)
              : null,
        ),
      ),
    );
  }

  Widget select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> change, {
    Map<String, String> labels = const {},
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(labels[v] ?? _statusLabel(v)),
                ))
            .toList(),
        onChanged: change,
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
        'orijinal' || 'ORİJİNAL' => 'Orijinal',
        'lokal' => 'Lokal Boyalı',
        'boyali' => 'Boyalı',
        'degisen' || 'DEĞİŞMİŞ' => 'Değişen',
        'islemli' => 'İşlemli',
        'plastik' => 'Plastik',
        'standart' => 'Standart',
        'KUSURSUZ' => 'Kusursuz',
        'ORTA' => 'Orta',
        'KOTU' => 'Kötü',
        'YOK' => 'Yok',
        'DONANIMDA YOK' => 'Donanımda Yok',
        _ => value,
      };

  Color _statusColor(String value) => switch (value.toLowerCase()) {
        'orijinal' || 'kusursuz' || 'standart' => const Color(0xFF20B26B),
        'lokal' || 'orta' || 'islemli' => const Color(0xFFF4B740),
        'boyali' => const Color(0xFF3B82F6),
        'degisen' || 'değişmiş' || 'kotu' => const Color(0xFFFF641F),
        _ => const Color(0xFF8B9098),
      };

  Widget _statusRows(
    Map<String, String> labels,
    Map<String, String> values,
    List<String> options,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final entry in labels.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _statusColor(values[entry.key] ?? options.first),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: options.contains(values[entry.key])
                        ? values[entry.key]
                        : options.first,
                    borderRadius: BorderRadius.circular(16),
                    items: options
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(
                                _statusLabel(option),
                                style: TextStyle(
                                  color: _statusColor(option),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setState(
                      () => values[entry.key] = value ?? options.first,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bulkStatusActions(
    Map<String, String> values,
    List<String> options,
  ) {
    final colors = Theme.of(context).colorScheme;
    final defaultValue = options.first;
    final changed =
        values.values.where((value) => value != defaultValue).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.secondary.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hızlı seçim',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  changed == 0
                      ? 'Sorunlu seçim yok'
                      : '$changed farklı durum seçildi',
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF6F4A39)),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {
              for (final key in values.keys) {
                values[key] = defaultValue;
              }
            }),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text('Tümü ${_statusLabel(defaultValue)}'),
          ),
        ],
      ),
    );
  }

  Widget _sectionPage({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    final chrome = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF07162A)
        : colors.primary;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: chrome,
            borderRadius: BorderRadius.circular(20),
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
                child: Icon(icon, color: chrome),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .66),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  double _amount(String key) =>
      double.tryParse(c[key]!.text.replaceAll(',', '.')) ?? 0;

  Widget _costSummary() {
    final colors = Theme.of(context).colorScheme;
    final total = _amount('alis_fiyati') + _amount('tahmini_masraf');
    final profit = _amount('hedef_satis') - total;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _amountLabel('Toplam Maliyet', total)),
          Container(width: 1, height: 36, color: colors.outlineVariant),
          Expanded(child: _amountLabel('Beklenen Kâr', profit)),
        ],
      ),
    );
  }

  Widget _amountLabel(String label, double amount) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      );

  Widget _vehiclePage() => _sectionPage(
        icon: Icons.directions_car_filled_rounded,
        title: 'Araç ve Müşteri',
        description: 'Kimlik, iletişim ve teknik araç bilgileri',
        children: [
          field('rapor_no', 'Rapor No', readOnly: true),
          field('tarih', 'Rapor Tarihi'),
          field('plaka', 'Plaka *'),
          field('musteri', 'Müşteri Adı'),
          for (final entry in vehicle.entries)
            field(
              entry.key,
              '${entry.value}${{
                'marka_model',
                'sasi'
              }.contains(entry.key) ? ' *' : ''}',
              type: {'model_yili', 'kilometre'}.contains(entry.key)
                  ? TextInputType.number
                  : entry.key == 'telefon'
                      ? TextInputType.phone
                      : null,
            ),
        ],
      );

  Widget _operationPage() {
    final isRental = operation == 'rent_teslim' || operation == 'rent_iade';
    final isGallery = operation == 'galeri_alim' || operation == 'galeri_satis';
    return _sectionPage(
      icon: Icons.route_rounded,
      title: 'Operasyon ve İş Akışı',
      description: 'İşlem türüne göre yalnızca gerekli alanlar gösterilir',
      children: [
        select(
          'İşlem Türü',
          operation,
          const [
            'genel',
            'rent_teslim',
            'rent_iade',
            'galeri_alim',
            'galeri_satis',
          ],
          (value) => setState(() => operation = value ?? 'genel'),
          labels: const {
            'genel': 'Genel Ekspertiz',
            'rent_teslim': 'Kiralama Teslim',
            'rent_iade': 'Kiralama İade',
            'galeri_alim': 'Galeri Alım',
            'galeri_satis': 'Galeri Satış',
          },
        ),
        select(
          'Rapor Durumu',
          status,
          const [
            'taslak',
            'kontrolde',
            'onay_bekliyor',
            'tamamlandi',
            'teslim_edildi',
          ],
          (value) => setState(() => status = value ?? 'taslak'),
          labels: const {
            'taslak': 'Taslak',
            'kontrolde': 'Kontrolde',
            'onay_bekliyor': 'Onay Bekliyor',
            'tamamlandi': 'Tamamlandı',
            'teslim_edildi': 'Teslim Edildi',
          },
        ),
        field('sozlesme_no', 'Sözleşme / Dosya No'),
        field('sube', 'Şube'),
        if (isRental) ...[
          field('surucu', 'Sürücü / Kiralayan'),
          if (operation == 'rent_teslim') field('teslim_eden', 'Teslim Eden'),
          if (operation == 'rent_iade') field('teslim_alan', 'Teslim Alan'),
          field('yakit_seviyesi', 'Yakıt Seviyesi (%)',
              type: TextInputType.number),
          if (operation == 'rent_iade') _deliveryReference(),
          field('aksesuarlar', 'Aksesuarlar / Eksikler'),
          field('temizlik_durumu', 'Temizlik Durumu'),
          field('hasar_sorumlulugu', 'Hasar Sorumluluğu'),
        ],
        if (isGallery) ...[
          field('alis_fiyati', 'Alış Fiyatı', type: TextInputType.number),
          field('tahmini_masraf', 'Tahmini Masraf', type: TextInputType.number),
          field('hedef_satis', 'Hedef Satış', type: TextInputType.number),
          field('hasar_bedeli', 'Hasar Bedeli', type: TextInputType.number),
          field('depozito', 'Depozito', type: TextInputType.number),
          _costSummary(),
        ],
        field('operasyon_notu', 'Operasyon Notu', lines: 4),
      ],
    );
  }

  Widget _deliveryReference() {
    final values = ['', ...deliveryReports.map((report) => '${report['id']}')];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(c['referans_rapor_id']!.text)
            ? c['referans_rapor_id']!.text
            : '',
        decoration: const InputDecoration(labelText: 'Teslim Referans Raporu'),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Referans seçilmedi'),
          ),
          ...deliveryReports.map(
            (report) => DropdownMenuItem(
              value: '${report['id']}',
              child: Text(
                '${report['plaka']} • ${report['rapor_no']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) => c['referans_rapor_id']!.text = value ?? '',
      ),
    );
  }

  Widget _outerBodyPage() => _sectionPage(
        icon: Icons.gesture_rounded,
        title: 'Dış Kaporta Şeması',
        description: 'Parçaya dokunun veya noktalarla hasar alanını çizin',
        children: [
          BodyMapEditor(
            key: _bodyMapKey,
            parts: body,
            labels: outer,
            polygons: polygons,
            onPartsChanged: (value) => setState(() => body = value),
            onPolygonsChanged: (value) => setState(() {
              polygons = value;
              _polygonsTouched = true;
            }),
          ),
          const Divider(height: 34),
          const Text(
            'Parça Durumları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _bulkStatusActions(
            body,
            const ['orijinal', 'lokal', 'boyali', 'degisen', 'plastik'],
          ),
          _statusRows(
            outer,
            body,
            const ['orijinal', 'lokal', 'boyali', 'degisen', 'plastik'],
          ),
        ],
      );

  Widget _statusPage(
    IconData icon,
    String title,
    String description,
    Map<String, String> labels,
    Map<String, String> values,
    List<String> options,
  ) =>
      _sectionPage(
        icon: icon,
        title: title,
        description: description,
        children: [
          _bulkStatusActions(values, options),
          _statusRows(labels, values, options),
        ],
      );

  String _photoUrl(dynamic raw) {
    final value = '$raw'.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${ApiService.webRoot}/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Widget _photoTile({required Widget image, required VoidCallback remove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(width: 105, height: 92, child: image),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: InkWell(
            onTap: remove,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xD9191C21),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesPage() => _sectionPage(
        icon: Icons.fact_check_rounded,
        title: 'Uzman Görüşü ve Fotoğraflar',
        description: 'Rapor notunu tamamlayın ve araç görsellerini ekleyin',
        children: [
          field('uzman_notu', 'Uzman Görüşü', lines: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${existingPhotos.length + newPhotos.length}/12 fotoğraf',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (var index = 0; index < existingPhotos.length; index++)
                _photoTile(
                  image: Image.network(
                    _photoUrl(existingPhotos[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF1F1EE),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  remove: () => setState(() => existingPhotos.removeAt(index)),
                ),
              for (var index = 0; index < newPhotos.length; index++)
                _photoTile(
                  image: Image.file(File(newPhotos[index].path),
                      fit: BoxFit.cover),
                  remove: () => setState(() => newPhotos.removeAt(index)),
                ),
            ],
          ),
        ],
      );

  Widget _testPage() {
    final labels = <String, String>{
      ...cosmetic,
      'test_wurth': 'Würth CO2 Testi',
      'diag': 'OBD Diagnostik',
      'test_yol': 'Dinamik Yol Testi',
    };
    return _sectionPage(
      icon: Icons.monitor_heart_rounded,
      title: 'Genel Testler ve Kozmetik',
      description: 'Elektronik, yol testi ve iç/dış kozmetik kontrolleri',
      children: [
        _statusRows(labels, tests, const ['KUSURSUZ', 'ORTA', 'KOTU', 'YOK']),
        const Divider(height: 30),
        field('test_wurth_not', 'Würth Açıklaması'),
        field('diag_not', 'OBD Açıklaması'),
        field('test_yol_not', 'Yol Testi Açıklaması'),
      ],
    );
  }

  void _moveStep(int delta) {
    final next = (tabs.index + delta).clamp(0, tabs.length - 1);
    tabs.animateTo(next);
  }

  Future<void> _chooseStep() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ekspertiz adımları',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  _stepTitles.length,
                  (index) => ChoiceChip(
                    selected: tabs.index == index,
                    avatar: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    label: Text(_stepTitles[index]),
                    onSelected: (_) => Navigator.pop(sheetContext, index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) tabs.animateTo(selected);
  }

  Widget _bottomActions() {
    final last = tabs.index == tabs.length - 1;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  saving
                      ? Icons.cloud_sync_rounded
                      : _hasUnsavedChanges
                          ? Icons.edit_note_rounded
                          : Icons.cloud_done_rounded,
                  size: 17,
                  color: saving
                      ? colors.secondary
                      : _hasUnsavedChanges
                          ? colors.secondary
                          : const Color(0xFF20B26B),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    saving
                        ? (saveStage.isEmpty
                            ? 'Sunucuya kaydediliyor'
                            : saveStage)
                        : _hasUnsavedChanges
                            ? 'Kaydedilmemiş değişiklikler var'
                            : 'Sunucuyla eşitlendi',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (saving) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            Row(children: [
              if (tabs.index > 0) ...[
                IconButton.outlined(
                  tooltip: 'Önceki adım',
                  onPressed: saving ? null : () => _moveStep(-1),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
              ],
              if (!last) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Kaydet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving ? null : () => _moveStep(1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Devam'),
                  ),
                ),
              ] else
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_done_rounded),
                    label: Text(
                      saving
                          ? 'Sunucuya Kaydediliyor...'
                          : activeReportId == null
                              ? 'Raporu Oluştur ve Doğrula'
                              : 'Değişiklikleri Kaydet ve Doğrula',
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowExit || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 62,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  activeReportId == null ? 'Yeni Ekspertiz' : 'Raporu Düzenle'),
              Text(
                '${tabs.index + 1}/9 • ${_stepTitles[tabs.index]}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Adımları göster',
              onPressed: _chooseStep,
              icon: const Icon(Icons.format_list_numbered_rounded),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: (tabs.index + 1) / tabs.length,
              color: colors.secondary,
              backgroundColor: Colors.white.withValues(alpha: .12),
            ),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _vehiclePage(),
                  _operationPage(),
                  _outerBodyPage(),
                  _statusPage(
                    Icons.car_crash_rounded,
                    'İç Kaporta / Şase Podye',
                    'Şase, direk, panel ve podye kontrolleri',
                    inside,
                    inner,
                    const [
                      'orijinal',
                      'islemli',
                      'boyali',
                      'degisen',
                      'plastik',
                      'standart',
                    ],
                  ),
                  _statusPage(
                    Icons.health_and_safety_rounded,
                    'Airbag ve Emniyet',
                    'Airbag ve emniyet kemeri kontrolleri',
                    airbags,
                    airbag,
                    const ['ORİJİNAL', 'DEĞİŞMİŞ', 'DONANIMDA YOK'],
                  ),
                  _statusPage(
                    Icons.settings_suggest_rounded,
                    'Motor Ekspertizi',
                    'Motor, yakıt, soğutma ve elektrik kontrolleri',
                    motor,
                    tests,
                    const ['KUSURSUZ', 'ORTA', 'KOTU', 'YOK'],
                  ),
                  _statusPage(
                    Icons.build_circle_rounded,
                    'Alt Mekanik ve Yürüyen',
                    'Lastik, fren, aks, şanzıman ve egzoz kontrolleri',
                    mechanic,
                    tests,
                    const ['KUSURSUZ', 'ORTA', 'KOTU', 'YOK'],
                  ),
                  _testPage(),
                  _notesPage(),
                ],
              ),
        bottomNavigationBar: loading ? null : _bottomActions(),
      ),
    );
  }
}
