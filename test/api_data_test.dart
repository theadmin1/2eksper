import 'dart:convert';

import 'package:eksper_mobile/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiData', () {
    test('JSON metni ve Map yanıtını aynı biçimde okur', () {
      expect(ApiData.map('{"plaka":"34 ABC 123"}')['plaka'], '34 ABC 123');
      expect(ApiData.map({'plaka': '34 ABC 123'})['plaka'], '34 ABC 123');
    });

    test('JSON metni ve List yanıtını aynı biçimde okur', () {
      expect(ApiData.list('[{"id":1}]').first['id'], 1);
      expect(
          ApiData.list([
            {'id': 1}
          ]).first['id'],
          1);
    });

    test('çift kodlanmış eski çizim JSON verisini derinlemesine çözer', () {
      final encoded = jsonEncode(jsonEncode([
        {
          'type': 'lokal',
          'points': [
            {'x': 12.5, 'y': 40}
          ]
        }
      ]));
      final polygons = ApiData.list(encoded);
      expect(polygons, hasLength(1));
      expect(polygons.first['type'], 'lokal');
      expect(polygons.first['points'].first['x'], 12.5);
    });

    test('HTML quote kodlu eski JSON listesini çözer', () {
      final polygons = ApiData.list(
        '[{&quot;type&quot;:&quot;boyali&quot;,&quot;x&quot;:4}]',
      );
      expect(polygons.first['type'], 'boyali');
    });

    test('tek fotoğraf yolunu gerektiğinde listeye sarar', () {
      expect(
        ApiData.list('uploads/firma_1/arac.jpg', wrapString: true),
        ['uploads/firma_1/arac.jpg'],
      );
    });

    test('geçersiz veya boş türler güvenli sonuç verir', () {
      expect(ApiData.map('geçersiz'), isEmpty);
      expect(ApiData.list(null), isEmpty);
      expect(ApiData.list('{}'), isEmpty);
    });
  });

  group('ApiService güvenli bağlantı', () {
    test('yalnızca HTTPS ve /api/v1 adresini kabul eder', () {
      expect(
        ApiService.normalizeBaseUrl('https://app.2eksper.com/api/v1/'),
        'https://app.2eksper.com/api/v1',
      );
      expect(
        () => ApiService.normalizeBaseUrl('http://app.2eksper.com/api/v1'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => ApiService.normalizeBaseUrl('https://app.2eksper.com'),
        throwsA(isA<ApiException>()),
      );
    });

    test('daha yeni API sürümlerini uyumlu kabul eder', () {
      expect(ApiService.isCompatible({'api_version': '1.2.0'}), isTrue);
      expect(ApiService.isCompatible({'api_version': '1.3.0'}), isTrue);
      expect(ApiService.isCompatible({'api_version': '2.0.0'}), isTrue);
      expect(ApiService.isCompatible({'api_version': '1.1.9'}), isFalse);
      expect(ApiService.isCompatible({'api_version': 'geçersiz'}), isFalse);
    });
  });
}
