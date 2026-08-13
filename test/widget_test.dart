import 'package:flutter_test/flutter_test.dart';
import 'package:eksper_mobile/services/api_service.dart';

void main() {
  test('API adresinden web panel kökü türetilir', () {
    ApiService.baseUrl = 'https://example.com/subdir/api/v1';
    expect(ApiService.webRoot, 'https://example.com/subdir');
  });
}
