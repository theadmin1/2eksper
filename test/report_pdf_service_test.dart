import 'dart:io';

import 'package:eksper_mobile/services/report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sekiz sayfalık A4 rapor ve çizim şeması üretir', () async {
    final report = <String, dynamic>{
      'id': 724,
      'uuid': 'qa-report',
      'rapor_no': 'MD-2026081200724',
      'tarih': '12.08.2026',
      'plaka': '34 QA 724',
      'musteri': 'PDF Kalite Kontrol',
      'durum': 'tamamlandi',
      'arac_bilgileri': {
        'telefon': '0555 000 00 00',
        'marka_model': 'CHERY OMODA 5',
        'model_yili': '2023',
        'yakit_turu': 'BENZİN',
        'vites_turu': 'OTOMATİK',
        'kasa_tipi': 'SUV / ARAZİ',
        'kilometre': '123.200 km',
        'motor_hp': '180 HP',
        'sasi': 'LVVDB21B9PD246741',
      },
      'kaporta_data': {
        'front-hood': 'boyali',
        'front-left-door': 'lokal',
        'rear-right-door': 'degisen',
      },
      'airbag_data': {
        'airbag_direksiyon': 'ORİJİNAL',
        'airbag_torpido': 'ORİJİNAL',
      },
      'test_data': {
        'motor_genel': 'KUSURSUZ',
        'motor_enjektor': 'ORTA',
        'mek_lastik_sol_on': 'KUSURSUZ',
        'test_wurth': 'KUSURSUZ',
        'test_wurth_not': 'CO2 kaçağı tespit edilmedi.',
        'diag': 'KUSURSUZ',
        'diag_not': 'Aktif arıza kodu yok.',
        'test_yol': 'ORTA',
        'test_yol_not': 'Yol testi tamamlandı.',
        'dis_sase': 'KUSURSUZ',
      },
      'nokta_data': [
        {
          'type': 'lokal',
          'points': [
            {'x': 50, 'y': 120},
            {'x': 88, 'y': 126},
            {'x': 76, 'y': 170},
            {'x': 44, 'y': 160},
          ],
          'dx': 5,
          'dy': 3,
        },
      ],
      'operasyon_data': {'sube': 'Merkez', 'surucu': 'Test Sürücüsü'},
      'maliyet_data': {},
      'foto_yolu': [],
      'uzman_notu':
          'Araç üzerinde yapılan fiziki, elektronik ve mekanik kontroller tamamlandı.',
    };
    final bytes = await ReportPdfService.build(
      report: report,
      meta: {
        'ayarlar': {
          'firma_adi_renkli': '2',
          'firma_adi_duz': 'EKSPER',
          'slogan': 'oto ekspertiz',
        },
        'tema': {'renk_marka': '#071b35', 'renk_vurgu': '#f5a714'},
      },
    );

    expect(bytes.length, greaterThan(10000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final output = Directory('../tmp/pdfs');
    await output.create(recursive: true);
    await File('${output.path}/report_pdf_qa.pdf').writeAsBytes(bytes);
  });
}
