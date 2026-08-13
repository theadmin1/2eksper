import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'api_service.dart';

/// Raporu WebView/HTML dönüştürmesine bağlı kalmadan gerçek A4 PDF olarak üretir.
/// Böylece Android WebView sürümü, sayfa önbelleği veya çok büyük JavaScript
/// String sonuçları kaydetme ve paylaşmayı etkileyemez.
class ReportPdfService {
  const ReportPdfService._();

  static const _outer = <String, String>{
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
    'rear-right-mudguard': 'Sağ Arka Çamurluk',
  };

  static const _inside = <String, String>{
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
    'sag_marspiyel': 'Sağ Marşpiyel',
  };

  static const _airbags = <String, String>{
    'airbag_direksiyon': 'Direksiyon Airbag',
    'airbag_torpido': 'Torpido Airbag',
    'airbag_tavan': 'Tavan Airbag',
    'airbag_koltuk_diz': 'Koltuk ve Diz Airbag',
    'emniyet_kemerleri': 'Emniyet Kemerleri',
  };

  static const _motor = <String, String>{
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
    'motor_elektrik': 'Motor Elektrik Tesisatı',
  };

  static const _mechanic = <String, String>{
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
    'mek_sanziman_kacak': 'Şanzıman Yağ Kaçakları',
  };

  static const _cosmetic = <String, String>{
    'dis_sase': 'Şase No Eşleştirme',
    'dis_korna': 'Korna Fonksiyonu',
    'dis_el_fren': 'El Freni',
    'dis_cam': 'Camlar ve Krikolar',
    'dis_torpido': 'Torpido & Göğüs',
    'dis_sunroof': 'Sunroof / Cam Tavan',
    'dis_gosterge': 'Gösterge ve İkazlar',
    'klima': 'Klima Performansı',
    'dis_koltuk': 'Koltuk Döşemeleri',
    'dis_direksiyon': 'Direksiyon Kumandaları',
  };

  static Future<Uint8List> buildForIdentifier(String identifier) async {
    Map<String, dynamic> response;
    try {
      response = await ApiService.get(
        'raporlar.php',
        queryParameters: {'id': identifier},
      );
    } catch (e) {
      throw ApiException('PDF oluşturmak için sunucuya bağlanılamadı: $e');
    }
    final data = ApiData.map(response['data']);
    final report = ApiData.map(data['rapor']);
    if (report.isEmpty) {
      throw const ApiException('PDF için rapor verisi alınamadı.');
    }
    return build(report: report, meta: ApiData.map(data['pdf_meta']));
  }

  static Future<Uint8List> build({
    required Map<String, dynamic> report,
    Map<String, dynamic> meta = const {},
  }) async {
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final settings = ApiData.map(meta['ayarlar']);
    final theme = ApiData.map(meta['tema']);
    final brand =
        _pdfColor(theme['renk_marka'], const PdfColor(0.027, .106, .208));
    final accent =
        _pdfColor(theme['renk_vurgu'], const PdfColor(.961, .655, .078));
    const border = PdfColor(.87, .89, .92);
    final vehicle = ApiData.map(report['arac_bilgileri']);
    final body = ApiData.map(report['kaporta_data']);
    final tests = ApiData.map(report['test_data']);
    final airbag = ApiData.map(report['airbag_data']);
    final operations = ApiData.map(report['operasyon_data']);
    final costs = ApiData.map(report['maliyet_data']);
    final polygons = ApiData.list(report['nokta_data']);
    final diagram = pw.MemoryImage(await _renderDiagram(body, polygons));
    final photos = await _downloadPhotos(ApiData.list(
      report['foto_yolu'],
      wrapString: true,
    ));
    final reportNo = _text(report['rapor_no'], 'RAPOR');
    final plate = _text(report['plaka'], 'PLAKASIZ').toUpperCase();
    final brandFirst = _text(settings['firma_adi_renkli'], '2');
    final brandSecond = _text(settings['firma_adi_duz'], 'EKSPER');
    final document = pw.Document(
      title: '$plate Ekspertiz Raporu',
      author: '$brandFirst$brandSecond',
      creator: '2EKSPER Mobil',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget page(
      int number,
      String title,
      pw.Widget child, {
      String? kicker,
    }) =>
        _pageFrame(
          number: number,
          title: title,
          kicker: kicker,
          child: child,
          reportNo: reportNo,
          date: _text(report['tarih']),
          brand: brand,
          accent: accent,
          border: border,
          brandFirst: brandFirst,
          brandSecond: brandSecond,
          slogan: _text(settings['slogan'], 'oto ekspertiz'),
        );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => page(
          1,
          'EKSPERTİZ RAPORU',
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _vehicleHero(photos, plate, vehicle, brand, accent),
              pw.SizedBox(height: 12),
              _infoStrip(report, vehicle, border),
              pw.SizedBox(height: 14),
              _sectionHeading('ARAÇ KİMLİK BİLGİLERİ', brand),
              _dataTable(
                {
                  'Plaka': plate,
                  'Marka / Model': vehicle['marka_model'],
                  'Model Yılı': vehicle['model_yili'],
                  'Yakıt Türü': vehicle['yakit_turu'],
                  'Vites Türü': vehicle['vites_turu'],
                  'Kasa Tipi': vehicle['kasa_tipi'],
                  'Kilometre': vehicle['kilometre'],
                  'Motor HP / Gücü': vehicle['motor_hp'],
                  'Şasi Numarası': vehicle['sasi'],
                },
                border,
              ),
              if (operations.values
                  .any((value) => _text(value).isNotEmpty)) ...[
                pw.SizedBox(height: 14),
                _sectionHeading('OPERASYON BİLGİLERİ', brand),
                _dataTable(
                  {
                    'Sözleşme / Dosya': report['sozlesme_no'],
                    'Şube': operations['sube'],
                    'Sürücü / Kiralayan': operations['surucu'],
                    'Teslim Eden': operations['teslim_eden'],
                    'Teslim Alan': operations['teslim_alan'],
                  },
                  border,
                ),
              ],
            ],
          ),
          kicker: '${vehicle['sasi'] ?? ''} ŞASİ • $plate',
        ),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => page(
          2,
          'DIŞ KAPORTA & BOYA',
          pw.Column(
            children: [
              pw.Container(
                height: 305,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(.975, .98, .985),
                  border: pw.Border.all(color: border),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(diagram, fit: pw.BoxFit.contain),
                    pw.SizedBox(width: 26),
                    _legend(),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              _statusTable(_outer, body, brand, border),
            ],
          ),
        ),
      ),
    );

    document.addPage(_statusPage(
        3, 'İÇ KAPORTA & ŞASE', _inside, body, page, brand, border));
    document.addPage(_statusPage(
        4, 'AİRBAG & EMNİYET', _airbags, airbag, page, brand, border));
    document.addPage(_statusPage(
        5, 'MOTOR BÖLÜMÜ KONTROLLERİ', _motor, tests, page, brand, border));
    document.addPage(_statusPage(
        6, 'ALT MEKANİK & YÜRÜYEN', _mechanic, tests, page, brand, border));

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => page(
          7,
          'GENEL TEST SONUÇLARI',
          pw.Column(
            children: [
              _testResult('WÜRTH CO2 KAÇAK TESTİ', tests['test_wurth'],
                  tests['test_wurth_not'], brand, border),
              pw.SizedBox(height: 18),
              _testResult('OBD BEYİN DİAGNOSTİK', tests['diag'],
                  tests['diag_not'], brand, border),
              pw.SizedBox(height: 18),
              _testResult('DİNAMİK YOL TESTİ', tests['test_yol'],
                  tests['test_yol_not'], brand, border),
              if (costs.values.any((value) => _number(value) != 0)) ...[
                pw.SizedBox(height: 24),
                _sectionHeading('MALİYET & OPERASYON ÖZETİ', brand),
                _dataTable(
                  {
                    'Alış Fiyatı': _money(costs['alis_fiyati']),
                    'Tahmini Masraf': _money(costs['tahmini_masraf']),
                    'Toplam Maliyet': _money(costs['toplam_maliyet']),
                    'Hedef Satış': _money(costs['hedef_satis']),
                    'Beklenen Kâr': _money(costs['beklenen_kar']),
                  },
                  border,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => page(
          8,
          'KOZMETİK & UZMAN GÖRÜŞÜ',
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _statusTable(_cosmetic, tests, brand, border),
              pw.SizedBox(height: 16),
              _sectionHeading('UZMAN NOTU', brand),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(.975, .98, .985),
                  border: pw.Border.all(color: border),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  _text(report['uzman_notu'],
                      'Ekspertiz kontrolleri tamamlanmıştır.'),
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                ),
              ),
              if (photos.isNotEmpty) ...[
                pw.SizedBox(height: 18),
                _sectionHeading('ARAÇ FOTOĞRAFLARI', brand),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos
                      .take(4)
                      .map(
                        (photo) => pw.Container(
                          width: 230,
                          height: 125,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: border),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 8,
                            verticalRadius: 8,
                            child: pw.Image(photo, fit: pw.BoxFit.cover),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Page _statusPage(
    int number,
    String title,
    Map<String, String> labels,
    Map<String, dynamic> values,
    pw.Widget Function(int, String, pw.Widget, {String? kicker}) page,
    PdfColor brand,
    PdfColor border,
  ) =>
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => page(
          number,
          title,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _statusSummary(labels, values, brand, border),
              pw.SizedBox(height: 18),
              _statusTable(labels, values, brand, border),
            ],
          ),
        ),
      );

  static pw.Widget _pageFrame({
    required int number,
    required String title,
    required pw.Widget child,
    required String reportNo,
    required String date,
    required PdfColor brand,
    required PdfColor accent,
    required PdfColor border,
    required String brandFirst,
    required String brandSecond,
    required String slogan,
    String? kicker,
  }) =>
      pw.Stack(
        children: [
          pw.Container(color: PdfColors.white),
          pw.Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(width: 30, color: brand),
          ),
          pw.Positioned(
            right: 0,
            bottom: 0,
            child: pw.Container(width: 30, height: 195, color: accent),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(34, 27, 52, 34),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 15, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: brand,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold),
                          children: [
                            pw.TextSpan(text: brandFirst),
                            pw.TextSpan(
                                text: brandSecond,
                                style: pw.TextStyle(color: accent)),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Container(width: 1, height: 32, color: border),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: pw.Text(slogan,
                          style: const pw.TextStyle(
                              fontSize: 13, color: PdfColor(.27, .31, .37))),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: pw.BoxDecoration(
                          color: accent,
                          borderRadius: pw.BorderRadius.circular(20)),
                      child: pw.Text('$number / 8',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: brand)),
                    ),
                  ],
                ),
                pw.Container(
                    height: 1.5,
                    margin: const pw.EdgeInsets.only(top: 12),
                    color: border),
                pw.SizedBox(height: 18),
                if (kicker != null && kicker.trim().isNotEmpty)
                  pw.Text(kicker.toUpperCase(),
                      style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColor(.42, .46, .52),
                          letterSpacing: .5)),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: brand)),
                pw.SizedBox(height: 16),
                pw.Expanded(child: child),
              ],
            ),
          ),
          pw.Positioned(
            left: 34,
            right: 52,
            bottom: 15,
            child: pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text('Tarih: $date',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColor(.4, .43, .48)))),
                pw.Text('Rapor No: $reportNo',
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: brand,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      );

  static pw.Widget _vehicleHero(List<pw.MemoryImage> photos, String plate,
          Map<String, dynamic> vehicle, PdfColor brand, PdfColor accent) =>
      pw.Container(
        height: 138,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor(.965, .973, .984),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 175,
              height: 114,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(9),
              ),
              child: photos.isEmpty
                  ? pw.Center(
                      child: pw.Text('ARAÇ FOTOĞRAFI',
                          style: pw.TextStyle(color: brand, fontSize: 9)))
                  : pw.ClipRRect(
                      horizontalRadius: 9,
                      verticalRadius: 9,
                      child: pw.Image(photos.first, fit: pw.BoxFit.cover),
                    ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 34, height: 4, color: accent),
                  pw.SizedBox(height: 10),
                  pw.Text(_text(vehicle['marka_model'], 'ARAÇ'),
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: brand)),
                  pw.SizedBox(height: 5),
                  pw.Text(plate,
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColor(.35, .39, .45))),
                ],
              ),
            ),
          ],
        ),
      );

  static pw.Widget _infoStrip(Map<String, dynamic> report,
      Map<String, dynamic> vehicle, PdfColor border) {
    final values = [
      ['Müşteri', _text(report['musteri'], '-')],
      ['Telefon', _text(vehicle['telefon'], '-')],
      ['Tarih', _text(report['tarih'], '-')],
      ['Rapor No', _text(report['rapor_no'], '-')],
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        children: values
            .map((entry) => pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(color: border))),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(entry[0],
                              style: const pw.TextStyle(
                                  fontSize: 7, color: PdfColor(.42, .46, .52))),
                          pw.SizedBox(height: 3),
                          pw.Text(entry[1],
                              maxLines: 2,
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ]),
                  ),
                ))
            .toList(),
      ),
    );
  }

  static pw.Widget _sectionHeading(String title, PdfColor brand) =>
      pw.Container(
        color: brand,
        padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: pw.Text(title,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: .5)),
      );

  static pw.Widget _dataTable(Map<String, dynamic> values, PdfColor border) {
    final rows =
        values.entries.where((entry) => _text(entry.value).isNotEmpty).toList();
    return pw.Table(
      border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: border),
          left: pw.BorderSide(color: border),
          right: pw.BorderSide(color: border),
          bottom: pw.BorderSide(color: border)),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1.8)
      },
      children: rows
          .map((entry) => pw.TableRow(children: [
                pw.Container(
                    color: const PdfColor(.965, .973, .984),
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: pw.Text(entry.key,
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: pw.Text(_text(entry.value),
                        style: const pw.TextStyle(fontSize: 8.5))),
              ]))
          .toList(),
    );
  }

  static pw.Widget _statusTable(Map<String, String> labels,
          Map<String, dynamic> values, PdfColor brand, PdfColor border) =>
      pw.Table(
        border: pw.TableBorder.all(color: border),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.7),
          1: pw.FlexColumnWidth(1)
        },
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: brand), children: [
            _tableHeader('KONTROL NOKTASI'),
            _tableHeader('MEVCUT DURUM'),
          ]),
          ...labels.entries.map((entry) {
            final status = _text(values[entry.key], 'orijinal');
            return pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  child: pw.Text(entry.value,
                      style: const pw.TextStyle(fontSize: 8.5))),
              pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  color: _statusColor(status).shade(.92),
                  child: pw.Text(_statusLabel(status),
                      style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _statusColor(status)))),
            ]);
          }),
        ],
      );

  static pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _statusSummary(Map<String, String> labels,
      Map<String, dynamic> values, PdfColor brand, PdfColor border) {
    final changed =
        labels.keys.where((key) => !_isOriginal(values[key])).length;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
          color: const PdfColor(.965, .973, .984),
          border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Row(children: [
        pw.Container(
            width: 46,
            height: 46,
            decoration: pw.BoxDecoration(
                color: changed == 0
                    ? const PdfColor(.125, .698, .42)
                    : const PdfColor(.961, .655, .078),
                shape: pw.BoxShape.circle),
            child: pw.Center(
                child: pw.Text(changed == 0 ? '✓' : '$changed',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)))),
        pw.SizedBox(width: 13),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(
                  changed == 0
                      ? 'Tüm kontroller standart'
                      : '$changed noktada işlem kaydı var',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: brand)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'Aşağıdaki tabloda tüm kontrol noktaları ve sonuçları yer alır.',
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: PdfColor(.42, .46, .52))),
            ])),
      ]),
    );
  }

  static pw.Widget _testResult(String title, dynamic status, dynamic note,
          PdfColor brand, PdfColor border) =>
      pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                      color: brand,
                      borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(9),
                          topRight: pw.Radius.circular(9))),
                  child: pw.Text(title,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: pw.BoxDecoration(
                                color: _statusColor(_text(status)).shade(.9),
                                borderRadius: pw.BorderRadius.circular(20)),
                            child: pw.Text(
                                _statusLabel(_text(status, 'KUSURSUZ')),
                                style: pw.TextStyle(
                                    color: _statusColor(_text(status)),
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                            child: pw.Text(
                                _text(note, 'Açıklama girilmemiştir.'),
                                style: const pw.TextStyle(
                                    fontSize: 9, lineSpacing: 2))),
                      ])),
            ]),
      );

  static pw.Widget _legend() => pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: const [
          ['Orijinal', PdfColor(.063, .82, .506)],
          ['Lokal Boyalı', PdfColor(.918, .702, .031)],
          ['Boyalı', PdfColor(.231, .51, .965)],
          ['Değişen', PdfColor(.976, .451, .086)],
        ]
            .map((entry) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(children: [
                  pw.Container(
                      width: 13, height: 13, color: entry[1] as PdfColor),
                  pw.SizedBox(width: 7),
                  pw.Text(entry[0] as String,
                      style: const pw.TextStyle(fontSize: 8.5)),
                ])))
            .toList(),
      );

  static Future<List<pw.MemoryImage>> _downloadPhotos(
      List<dynamic> paths) async {
    if (paths.isEmpty) return <pw.MemoryImage>[];
    final token = await ApiService.getToken();
    final result = <pw.MemoryImage>[];
    for (final path in paths.take(4)) {
      final url = ApiService.mediaUrl(path);
      if (url.isEmpty) continue;
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token'
          },
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            response.bodyBytes.length > 100) {
          result.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (_) {
        // Fotoğraf indirilemese de raporun metin ve şema sayfaları oluşturulur.
      }
    }
    return result;
  }

  static Future<Uint8List> _renderDiagram(
      Map<String, dynamic> parts, List<dynamic> polygons) async {
    final plan = await _loadUiImage('assets/images/vehicle_plan.png');
    final mask = await _loadUiImage('assets/images/vehicle_mask.png');
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale, scale);
    canvas.drawImage(plan, ui.Offset.zero, ui.Paint());
    for (final entry in _sourceRects.entries) {
      final destination = _partRects[entry.key]!;
      canvas.drawImageRect(
        mask,
        entry.value,
        destination,
        ui.Paint()
          ..colorFilter = ui.ColorFilter.mode(
              _uiStatusColor(_text(parts[entry.key], 'orijinal')),
              ui.BlendMode.srcIn),
      );
    }
    for (final raw in polygons) {
      if (raw is! Map) continue;
      final points = _polygonPoints(raw);
      if (points.length < 3) continue;
      final offset = ui.Offset(_number(raw['dx']), _number(raw['dy']));
      final path = ui.Path()
        ..addPolygon(points.map((point) => point + offset).toList(), true);
      canvas.drawPath(
          path, ui.Paint()..color = _uiPolygonColor(_text(raw['type'])));
      canvas.drawPath(
          path,
          ui.Paint()
            ..color = const ui.Color(0xFF111827)
            ..strokeWidth = 1
            ..style = ui.PaintingStyle.stroke);
    }
    final image = await recorder.endRecording().toImage(622, 782);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw const ApiException('Araç şeması PDF için hazırlanamadı.');
    }
    return bytes.buffer.asUint8List();
  }

  static Future<ui.Image> _loadUiImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  static List<ui.Offset> _polygonPoints(Map raw) {
    final points = raw['points'];
    if (points is List) {
      return points
          .map((point) {
            if (point is Map) {
              return ui.Offset(_number(point['x']), _number(point['y']));
            }
            if (point is List && point.length >= 2) {
              return ui.Offset(_number(point[0]), _number(point[1]));
            }
            return null;
          })
          .whereType<ui.Offset>()
          .toList();
    }
    final x = _number(raw['x']);
    final y = _number(raw['y']);
    final w = _number(raw['w']);
    final h = _number(raw['h']);
    return [
      ui.Offset(x, y),
      ui.Offset(x + w, y),
      ui.Offset(x + w, y + h),
      ui.Offset(x, y + h)
    ];
  }

  static PdfColor _pdfColor(dynamic value, PdfColor fallback) {
    final raw = _text(value).replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null || raw.length != 6) return fallback;
    return PdfColor((parsed >> 16 & 255) / 255, (parsed >> 8 & 255) / 255,
        (parsed & 255) / 255);
  }

  static PdfColor _statusColor(String status) => switch (status.toLowerCase()) {
        'orijinal' ||
        'kusursuz' ||
        'standart' =>
          const PdfColor(.063, .62, .36),
        'lokal' || 'orta' || 'islemli' => const PdfColor(.72, .49, 0),
        'boyali' => const PdfColor(.15, .36, .78),
        'degisen' || 'değişmiş' || 'kotu' => const PdfColor(.82, .25, .07),
        _ => const PdfColor(.38, .42, .48),
      };

  static ui.Color _uiStatusColor(String status) =>
      switch (status.toLowerCase()) {
        'lokal' => const ui.Color(0xFFEAB308),
        'boyali' => const ui.Color(0xFF3B82F6),
        'degisen' => const ui.Color(0xFFF97316),
        'plastik' => const ui.Color(0xFF22C55E),
        _ => const ui.Color(0xFF10D981),
      };

  static ui.Color _uiPolygonColor(String status) =>
      switch (status.toLowerCase()) {
        'boyali' => const ui.Color(0xCC3B82F6),
        'degisen' => const ui.Color(0xCCF97316),
        _ => const ui.Color(0xCCEAB308),
      };

  static bool _isOriginal(dynamic value) => const {
        'orijinal',
        'kusursuz',
        'standart'
      }.contains(_text(value, 'orijinal').toLowerCase());

  static String _statusLabel(String value) => switch (value.toLowerCase()) {
        'orijinal' => 'Orijinal',
        'lokal' => 'Lokal Boyalı',
        'boyali' => 'Boyalı',
        'degisen' => 'Değişen',
        'islemli' => 'İşlemli',
        'kusursuz' => 'Kusursuz',
        'orta' => 'Orta',
        'kotu' => 'Kötü',
        'yok' => 'Yok',
        _ => value.isEmpty ? '-' : value,
      };

  static String _text(dynamic value, [String fallback = '']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  static double _number(dynamic value) =>
      double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;

  static String _money(dynamic value) {
    final amount = _number(value);
    return '${amount.toStringAsFixed(2)} TL';
  }

  static const _partRects = <String, ui.Rect>{
    'front-bumper': ui.Rect.fromLTWH(104, 16, 105, 22),
    'front-left-mudguard': ui.Rect.fromLTWH(21, 51, 28, 43),
    'front-right-mudguard': ui.Rect.fromLTWH(262, 51, 28, 43),
    'front-hood': ui.Rect.fromLTWH(101, 48, 110, 80),
    'front-left-door': ui.Rect.fromLTWH(21, 108, 80, 104),
    'front-right-door': ui.Rect.fromLTWH(210, 108, 80, 105),
    'rear-left-door': ui.Rect.fromLTWH(21, 197, 79, 84),
    'rear-right-door': ui.Rect.fromLTWH(211, 197, 79, 85),
    'roof': ui.Rect.fromLTWH(119, 208, 74, 53),
    'rear-hood': ui.Rect.fromLTWH(104, 309, 104, 30),
    'rear-left-mudguard': ui.Rect.fromLTWH(21, 292, 28, 46),
    'rear-right-mudguard': ui.Rect.fromLTWH(262, 293, 28, 45),
    'rear-bumper': ui.Rect.fromLTWH(104, 352, 105, 22),
  };

  static const _sourceRects = <String, ui.Rect>{
    'front-bumper': ui.Rect.fromLTWH(532, 252, 105, 22),
    'front-left-mudguard': ui.Rect.fromLTWH(872, 43, 28, 43),
    'front-right-mudguard': ui.Rect.fromLTWH(900, 0, 28, 43),
    'front-hood': ui.Rect.fromLTWH(0, 682, 110, 80),
    'front-left-door': ui.Rect.fromLTWH(190, 473, 80, 104),
    'front-right-door': ui.Rect.fromLTWH(110, 577, 80, 105),
    'rear-left-door': ui.Rect.fromLTWH(349, 304, 79, 84),
    'rear-right-door': ui.Rect.fromLTWH(270, 388, 79, 85),
    'roof': ui.Rect.fromLTWH(742, 177, 74, 53),
    'rear-bumper': ui.Rect.fromLTWH(637, 230, 105, 22),
    'rear-hood': ui.Rect.fromLTWH(428, 274, 104, 30),
    'rear-left-mudguard': ui.Rect.fromLTWH(816, 131, 28, 46),
    'rear-right-mudguard': ui.Rect.fromLTWH(844, 86, 28, 45),
  };
}
