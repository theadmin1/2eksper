import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class PdfFileService {
  const PdfFileService._();

  static const _channel = MethodChannel('com.synaptropic.twoeksper/pdf_file');

  static Future<bool> savePdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!Platform.isAndroid) {
      // TODO: iOS için farklı bir native entegrasyon veya Printing.layoutPdf kullanılabilir
      return false;
    }
    try {
      final saved = await _channel.invokeMethod<bool>('savePdf', {
        'bytes': bytes,
        'filename': filename,
      }).timeout(const Duration(minutes: 3));
      return saved ?? false;
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Dosya kaydetme işlemi başarısız oldu: ${e.message}',
        details: e.details,
      );
    }
  }

  static Future<bool> sharePdf({
    required Uint8List bytes,
    required String filename,
    String subject = '2EKSPER Ekspertiz Raporu',
    String body = '2EKSPER ekspertiz raporu ektedir.',
  }) async {
    if (!Platform.isAndroid) {
      // iOS fallback
      return await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: subject,
        body: body,
      );
    }
    try {
      final shared = await _channel.invokeMethod<bool>('sharePdf', {
        'bytes': bytes,
        'filename': filename,
        'subject': subject,
        'body': body,
      }).timeout(const Duration(seconds: 30));
      return shared ?? false;
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Paylaşım işlemi başarısız oldu: ${e.message}',
        details: e.details,
      );
    }
  }
}
