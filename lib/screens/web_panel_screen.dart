import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/pdf_file_service.dart';
import '../services/report_pdf_service.dart';

/// Web panelindeki bütün işlevleri mobil uygulamanın içinde çalıştırır.
/// Rapor sayfasındaki window.print çağrısı yakalanarak aynı HTML/CSS şablonu
/// Android/iOS yazdırma ve PDF kaydetme ekranına gönderilir.
class WebPanelScreen extends StatefulWidget {
  final String initialPath;

  const WebPanelScreen({super.key, this.initialPath = 'anasayfa.php'});

  @override
  State<WebPanelScreen> createState() => _WebPanelScreenState();
}

class _WebPanelScreenState extends State<WebPanelScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';
  String? _error;
  bool _printing = false;
  bool _allowPop = false;
  String _pdfStage = '';
  Uint8List? _cachedPdf;
  String? _cachedPdfForUrl;
  Completer<String>? _pdfHtmlCompleter;
  String? _pdfTransferId;
  List<String?>? _pdfHtmlChunks;

  bool get _isReport =>
      Uri.tryParse(_currentUrl)?.path.endsWith('/rapor.php') ?? false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F3F1))
      ..addJavaScriptChannel(
        'PrintBridge',
        onMessageReceived: (_) => _printReport(),
      )
      ..addJavaScriptChannel(
        'AppBridge',
        onMessageReceived: (message) {
          if (message.message == 'close') _closePanel();
        },
      )
      ..addJavaScriptChannel(
        'PdfBridge',
        onMessageReceived: _handlePdfBridge,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onProgress: (value) =>
              mounted ? setState(() => _progress = value) : null,
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _error = null;
                _cachedPdf = null;
                _cachedPdfForUrl = null;
              });
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _progress = 100;
              });
            }
            await _installMobileBridge();
          },
          onWebResourceError: (value) {
            if (value.isForMainFrame == true && mounted) {
              setState(() => _error =
                  'Sayfa sunucudan alınamadı. İnternet bağlantısını kontrol edip tekrar deneyin.');
            }
          },
        ),
      );
    _openAuthenticated(widget.initialPath);
  }

  Future<void> _openAuthenticated(String path) async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) await context.read<AuthProvider>().logout();
      return;
    }
    final requested = Uri.parse(path);
    final freshPath = requested.replace(
      queryParameters: {
        ...requested.queryParameters,
        '_mobile_ts': '${DateTime.now().millisecondsSinceEpoch}',
      },
    ).toString();
    final bridge = Uri.parse('${ApiService.baseUrl}/web_session.php')
        .replace(queryParameters: {'next': freshPath});
    try {
      if (requested.path.endsWith('rapor.php')) {
        await _controller.clearCache();
      }
      await _controller.loadRequest(
        bridge,
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Sunucu bağlantısı kurulamadı. Bağlantıyı kontrol edip tekrar deneyin.');
      }
    }
  }

  Future<void> _installMobileBridge() async {
    final planBytes = await rootBundle.load('assets/images/vehicle_plan.png');
    final maskBytes = await rootBundle.load('assets/images/vehicle_mask.png');
    final planData =
        'data:image/png;base64,${base64Encode(planBytes.buffer.asUint8List())}';
    final maskData =
        'data:image/png;base64,${base64Encode(maskBytes.buffer.asUint8List())}';
    await _controller.runJavaScript('''
      (() => {
        document.documentElement.classList.add('mobile-app-webview');
        window.print = () => PrintBridge.postMessage('print');
        if (document.querySelector('.car-parts')) {
          [
            ['two-eksper-plan-source', '$planData'],
            ['two-eksper-mask-source', '$maskData']
          ].forEach(([id, path]) => {
            if (document.getElementById(id)) return;
            const image = document.createElement('img');
            image.id = id;
            image.src = path;
            image.alt = '';
            image.setAttribute('aria-hidden', 'true');
            image.style.cssText = 'position:fixed;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;pointer-events:none';
            document.body.appendChild(image);
          });
        }
        if (!window.__twoEksperNativeNavigation) {
          window.__twoEksperNativeNavigation = true;
          document.addEventListener('click', (event) => {
            const link = event.target.closest && event.target.closest('a');
            if (!link) return;
            const href = (link.getAttribute('href') || '').toLowerCase();
            const text = (link.textContent || '').toLocaleLowerCase('tr-TR');
            const returnsToApp = text.includes('kütüphaneye dön') ||
              text.includes('uygulamaya dön') ||
              href === 'index.php' || href.endsWith('/index.php') ||
              href === 'raporlar.php' || href.endsWith('/raporlar.php');
            if (returnsToApp) {
              event.preventDefault();
              event.stopPropagation();
              AppBridge.postMessage('close');
            }
          }, true);
        }
        const fitPdfPages = () => {
          const pages = document.querySelectorAll('.a4-page');
          if (!pages.length) return;
          const scale = Math.min(1, (window.innerWidth - 16) / 793.7);
          pages.forEach((page) => {
            page.style.transform = `scale(\${scale})`;
            page.style.transformOrigin = 'top left';
            page.style.marginLeft = '0';
            page.style.marginRight = '0';
            page.style.marginBottom = `\${-(page.offsetHeight * (1 - scale)) + 12}px`;
          });
        };
        fitPdfPages();
        if (!window.__twoEksperFitListener) {
          window.__twoEksperFitListener = true;
          window.addEventListener('resize', fitPdfPages);
        }
        let style = document.getElementById('mobile-app-overrides');
        if (!style) {
          style = document.createElement('style');
          style.id = 'mobile-app-overrides';
          style.textContent = `
            @media screen and (max-width: 700px) {
              html, body { overflow-x: hidden !important; }
              body { -webkit-text-size-adjust: 100%; padding: 8px !important;
                gap: 12px !important; display: block !important; background: #f3f3f1 !important; }
              .a4-page { box-shadow: 0 5px 18px rgba(15,32,56,.16) !important; }
              .dashboard-wrapper { margin: 16px auto !important; padding: 0 12px !important; }
              .section-card { padding: 16px !important; border-radius: 14px !important; }
              .grid-3, .grid-4, .kaporta-form { grid-template-columns: 1fr !important; min-width: 0 !important; }
              .kaporta-layout { gap: 16px !important; }
              .kaporta-preview { width: 100% !important; padding: 10px !important; overflow-x: auto !important; }
              .btn-controls { display: none !important; }
              input, select, textarea { font-size: 16px !important; }
            }
          `;
          document.head.appendChild(style);
        }
      })();
    ''');
  }

  void _handlePdfBridge(JavaScriptMessage message) {
    final completer = _pdfHtmlCompleter;
    if (completer == null || completer.isCompleted) return;
    try {
      final payload = jsonDecode(message.message);
      if (payload is! Map) {
        throw const FormatException('PDF aktarım mesajı geçersiz.');
      }
      final type = '${payload['type'] ?? ''}';
      final transferId = '${payload['id'] ?? ''}';
      if (type == 'start') {
        final total = (payload['total'] as num?)?.toInt() ?? 0;
        if (transferId.isEmpty || total < 1 || total > 4000) {
          throw const FormatException('PDF aktarım boyutu geçersiz.');
        }
        _pdfTransferId = transferId;
        _pdfHtmlChunks = List<String?>.filled(total, null);
        return;
      }
      if (type == 'error') {
        completer.completeError(
          ApiException('${payload['message'] ?? 'PDF sayfası hazırlanamadı.'}'),
        );
        return;
      }
      if (transferId != _pdfTransferId || _pdfHtmlChunks == null) return;
      if (type == 'chunk') {
        final index = (payload['index'] as num?)?.toInt() ?? -1;
        if (index < 0 || index >= _pdfHtmlChunks!.length) {
          throw const FormatException('PDF aktarım sırası geçersiz.');
        }
        _pdfHtmlChunks![index] = '${payload['data'] ?? ''}';
        return;
      }
      if (type == 'end') {
        if (_pdfHtmlChunks!.any((chunk) => chunk == null)) {
          throw const FormatException(
              'PDF içeriğinin bir bölümü aktarılamadı.');
        }
        completer.complete(_pdfHtmlChunks!.join());
      }
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(
          ApiException('PDF sayfası uygulamaya aktarılamadı: $error'),
        );
      }
    }
  }

  void _resetPdfTransfer() {
    _pdfHtmlCompleter = null;
    _pdfTransferId = null;
    _pdfHtmlChunks = null;
  }

  Future<Uint8List> _buildCurrentPdf() async {
    if (_cachedPdf != null && _cachedPdfForUrl == _currentUrl) {
      return _cachedPdf!;
    }
    final identifier = Uri.tryParse(_currentUrl)?.queryParameters['id'] ??
        Uri.tryParse(widget.initialPath)?.queryParameters['id'];
    if (identifier == null || identifier.trim().isEmpty) {
      throw const ApiException('PDF oluşturulacak rapor kimliği bulunamadı.');
    }
    
    Future<Uint8List> attemptGeneration() async {
      _setPdfStage('Güncel rapor verileri sunucudan alınıyor');
      try {
        final bytes = await ReportPdfService.buildForIdentifier(identifier);
        if (bytes.length < 1024) {
          throw const ApiException('PDF belgesi boş oluşturuldu.');
        }
        return bytes;
      } on ApiException catch (e) {
        try {
          return await _buildLegacyHtmlPdf();
        } catch (_) {
          throw ApiException('PDF oluşturulamadı: ${e.message}');
        }
      } catch (e) {
        return await _buildLegacyHtmlPdf();
      }
    }

    try {
      final bytes = await attemptGeneration();
      _cachedPdf = bytes;
      _cachedPdfForUrl = _currentUrl;
      return bytes;
    } catch (e) {
      _setPdfStage('Yeniden deneniyor...');
      await _controller.clearCache();
      try {
        final bytes = await attemptGeneration();
        _cachedPdf = bytes;
        _cachedPdfForUrl = _currentUrl;
        return bytes;
      } catch (retryError) {
        if (retryError is ApiException) {
          rethrow;
        }
        throw ApiException('PDF oluşturulamadı: $retryError');
      }
    }
  }

  // ignore: unused_element
  Future<Uint8List> _buildLegacyHtmlPdf() async {
    if (_cachedPdf != null && _cachedPdfForUrl == _currentUrl) {
      return _cachedPdf!;
    }
    _setPdfStage('Rapor sayfası hazırlanıyor');
    await _waitForReportAssets();
    _setPdfStage('Şema ve işaretler PDF’ye aktarılıyor');
    final transfer = Completer<String>();
    _pdfHtmlCompleter = transfer;
    late final String encodedHtml;
    try {
      await _controller.runJavaScriptReturningResult(r'''
      (() => {
        try {
        const root = document.documentElement.cloneNode(true);
        root.querySelectorAll('.no-print, #mobile-app-overrides').forEach((node) => node.remove());
        root.querySelectorAll('script').forEach((node) => node.remove());
        root.querySelectorAll('style').forEach((style) => {
          style.textContent = (style.textContent || '').replace(/@import\s+url\([^;]+;/gi, '');
        });
        const sourceImages = Array.from(document.querySelectorAll('img'));
        root.querySelectorAll('img').forEach((image, index) => {
          const source = sourceImages[index];
          if (source && source.complete && source.naturalWidth > 0) {
            image.setAttribute('src', source.src);
          } else {
            image.remove();
          }
        });
        const plan = document.getElementById('two-eksper-plan-source');
        const mask = document.getElementById('two-eksper-mask-source');
        const partMap = {
          'front-bumper': [532,252,105,22,104,16],
          'front-left-mudguard': [872,43,28,43,21,51],
          'front-right-mudguard': [900,0,28,43,262,51],
          'front-hood': [0,682,110,80,101,48],
          'front-left-door': [190,473,80,104,21,108],
          'front-right-door': [110,577,80,105,210,108],
          'rear-left-door': [349,304,79,84,21,197],
          'rear-right-door': [270,388,79,85,211,197],
          'roof': [742,177,74,53,119,208],
          'rear-bumper': [637,230,105,22,104,352],
          'rear-hood': [428,274,104,30,104,309],
          'rear-left-mudguard': [816,131,28,46,21,292],
          'rear-right-mudguard': [844,86,28,45,262,293]
        };
        const partColor = (node) => {
          if (node.classList.contains('local-painted-new')) return '#eab308';
          if (node.classList.contains('painted-new')) return '#3b82f6';
          if (node.classList.contains('changed-new')) return '#f97316';
          return '#10d981';
        };
        if (plan && mask && plan.complete && mask.complete &&
            plan.naturalWidth > 0 && mask.naturalWidth > 0) {
          const sourceCars = Array.from(document.querySelectorAll('.car-parts'));
          const clonedCars = Array.from(root.querySelectorAll('.car-parts'));
          sourceCars.forEach((sourceCar, index) => {
            const target = clonedCars[index];
            if (!target) return;
            const canvas = document.createElement('canvas');
            canvas.width = 311;
            canvas.height = 391;
            const context = canvas.getContext('2d');
            context.drawImage(plan, 0, 0, 311, 391);
            Object.entries(partMap).forEach(([className, rect]) => {
              const part = sourceCar.querySelector('.' + className);
              if (!part) return;
              const [sx, sy, width, height, dx, dy] = rect;
              const layer = document.createElement('canvas');
              layer.width = width;
              layer.height = height;
              const layerContext = layer.getContext('2d');
              layerContext.drawImage(mask, sx, sy, width, height, 0, 0, width, height);
              layerContext.globalCompositeOperation = 'source-in';
              layerContext.fillStyle = partColor(part);
              layerContext.fillRect(0, 0, width, height);
              context.drawImage(layer, dx, dy);
            });
            sourceCar.querySelectorAll('svg.drawing-layer polygon').forEach((polygon) => {
              const points = (polygon.getAttribute('points') || '').trim()
                .split(/\s+/).map((pair) => pair.split(',').map(Number))
                .filter((pair) => pair.length === 2 && pair.every(Number.isFinite));
              if (points.length < 3) return;
              const transform = polygon.getAttribute('transform') || '';
              const match = transform.match(/translate\(\s*(-?[\d.]+)[,\s]+(-?[\d.]+)/i);
              const offsetX = match ? Number(match[1]) : 0;
              const offsetY = match ? Number(match[2]) : 0;
              context.beginPath();
              context.moveTo(points[0][0] + offsetX, points[0][1] + offsetY);
              points.slice(1).forEach((point) =>
                context.lineTo(point[0] + offsetX, point[1] + offsetY));
              context.closePath();
              context.fillStyle = polygon.getAttribute('fill') || 'rgba(234,179,8,.8)';
              context.fill();
              context.strokeStyle = '#191c21';
              context.lineWidth = 1;
              context.stroke();
            });
            const image = document.createElement('img');
            image.src = canvas.toDataURL('image/png');
            image.alt = 'Araç kaporta ve hasar şeması';
            image.style.cssText = 'display:block;width:311px;height:391px;max-width:none';
            target.innerHTML = '';
            target.style.backgroundImage = 'none';
            target.appendChild(image);
          });
        }
        root.querySelectorAll('#two-eksper-plan-source, #two-eksper-mask-source').forEach((node) => node.remove());
        const viewport = root.querySelector('meta[name="viewport"]');
        if (viewport) viewport.setAttribute('content', 'width=794, initial-scale=1');
        root.querySelectorAll('svg.drawing-layer').forEach((svg) => {
          svg.setAttribute('width', '311');
          svg.setAttribute('height', '391');
          svg.setAttribute('viewBox', '0 0 311 391');
          svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
        });
        const pdfStyle = document.createElement('style');
        pdfStyle.textContent = `
          @page { size: A4 portrait; margin: 0 !important; }
          html, body {
            width: 210mm !important;
            height: auto !important;
            min-height: 0 !important;
            margin: 0 !important;
            padding: 0 !important;
            background: white !important;
            display: block !important;
            overflow: visible !important;
          }
          body { gap: 0 !important; }
          .a4-page {
            width: 210mm !important;
            height: auto !important;
            min-height: 297mm !important;
            max-width: none !important;
            box-sizing: border-box !important;
            flex: none !important;
            margin: 0 !important;
            padding: 0 !important;
            box-shadow: none !important;
            transform: none !important;
            overflow: visible !important;
            break-after: page !important;
            page-break-after: always !important;
            break-inside: auto !important;
            page-break-inside: auto !important;
          }
          .a4-page:last-child {
            break-after: auto !important;
            page-break-after: auto !important;
          }
          .a4-page, .a4-page * {
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }
          svg.drawing-layer {
            display: block !important;
            visibility: visible !important;
          }
        `;
        root.querySelector('head').appendChild(pdfStyle);
        const html = '<!doctype html>' + root.outerHTML;
        const encoded = btoa(unescape(encodeURIComponent(html)));
        const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const chunkSize = 48000;
        const total = Math.ceil(encoded.length / chunkSize);
        PdfBridge.postMessage(JSON.stringify({type:'start', id, total}));
        for (let index = 0; index < total; index++) {
          PdfBridge.postMessage(JSON.stringify({
            type: 'chunk',
            id,
            index,
            data: encoded.slice(index * chunkSize, (index + 1) * chunkSize)
          }));
        }
        PdfBridge.postMessage(JSON.stringify({type:'end', id}));
        return 'sent';
        } catch (error) {
          PdfBridge.postMessage(JSON.stringify({
            type: 'error',
            id: '',
            message: String(error && error.message ? error.message : error)
          }));
          return 'error';
        }
      })();
    ''');
      encodedHtml = await transfer.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const ApiException(
        'PDF sayfasının aktarımı zaman aşımına uğradı. Sayfayı yenileyip tekrar deneyin.',
      );
    } finally {
      _resetPdfTransfer();
    }
    String html;
    try {
      html = utf8.decode(base64Decode(encodedHtml));
    } on FormatException {
      throw const ApiException(
          'PDF sayfası uygulamaya geçerli biçimde aktarılamadı.');
    }
    if (!html.contains('a4-page')) {
      throw const ApiException(
        'Sunucudaki rapor şablonu PDF sayfalarını göndermedi.',
      );
    }
    _setPdfStage('A4 PDF dosyası oluşturuluyor');
    final base = Uri.parse(_currentUrl).resolve('.').toString();
    // ignore: deprecated_member_use
    final bytes = await Printing.convertHtml(
      html: html,
      baseUrl: base,
      format: PdfPageFormat.a4,
    );
    if (bytes.length < 1024) {
      throw const ApiException(
          'PDF belgesi boş oluşturuldu. Lütfen tekrar deneyin.');
    }
    _cachedPdf = bytes;
    _cachedPdfForUrl = _currentUrl;
    return bytes;
  }

  void _setPdfStage(String value) {
    if (!mounted) return;
    setState(() => _pdfStage = value);
  }

  String _pdfFilename() {
    final id = Uri.tryParse(_currentUrl)?.queryParameters['id'] ?? 'rapor';
    final safe = id
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return '2EKSPER-$safe.pdf';
  }

  String _javascriptString(Object result) {
    if (result is String) {
      final value = result.trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is String) return decoded;
        } on FormatException {
          // Bazı Android WebView sürümleri sonucu zaten çözülmüş String döndürür.
        }
      }
      return value;
    }
    throw ApiException(
      'PDF içeriği beklenmeyen veri tipinde döndü: ${result.runtimeType}',
    );
  }

  Future<void> _waitForReportAssets() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final result = await _controller.runJavaScriptReturningResult('''
        (() => {
          const carDiagram = document.querySelector('.car-parts');
          const plan = document.getElementById('two-eksper-plan-source');
          const mask = document.getElementById('two-eksper-mask-source');
          const diagramReady = !carDiagram || (plan && mask &&
            plan.complete && mask.complete &&
            plan.naturalWidth > 0 && mask.naturalWidth > 0);
          const imagesReady = Array.from(document.images)
            .filter((image) => !['two-eksper-plan-source', 'two-eksper-mask-source'].includes(image.id))
            .every((image) => image.complete);
          return diagramReady && imagesReady ? 'ready' : 'waiting';
        })();
      ''');
      if (_javascriptString(result) == 'ready') return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final diagramState = await _controller.runJavaScriptReturningResult('''
      (() => {
        if (!document.querySelector('.car-parts')) return 'not-required';
        const plan = document.getElementById('two-eksper-plan-source');
        const mask = document.getElementById('two-eksper-mask-source');
        return plan && mask && plan.naturalWidth > 0 && mask.naturalWidth > 0
          ? 'ready' : 'missing';
      })();
    ''');
    if (_javascriptString(diagramState) == 'missing') {
      throw const ApiException(
        'Araç şeması yüklenemedi. PDF eksik oluşturulmadı; bağlantıyı kontrol edip tekrar deneyin.',
      );
    }
  }

  Future<void> _printReport() async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _pdfStage = 'PDF hazırlanıyor';
    });
    try {
      final bytes = await _buildCurrentPdf();
      _setPdfStage('Dosyanın kaydedileceği konum seçiliyor');
      final completed = Platform.isAndroid
          ? await PdfFileService.savePdf(
              bytes: bytes,
              filename: _pdfFilename(),
            )
          : await Printing.layoutPdf(
              name: _pdfFilename(),
              format: PdfPageFormat.a4,
              dynamicLayout: false,
              onLayout: (_) async => bytes,
            );
      if (completed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF dosyası başarıyla kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is PlatformException
            ? 'Cihazın kaydetme/yazdırma özelliği yanıt vermedi veya izniniz yok. Lütfen depolama izinlerini kontrol edin.\n\nDetay: ${e.message}'
            : e.toString();
        await _showPdfError('PDF kaydedilemedi', message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
          _pdfStage = '';
        });
      }
    }
  }

  Future<void> _systemPrint() async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _pdfStage = 'PDF hazırlanıyor';
    });
    try {
      final bytes = await _buildCurrentPdf();
      _setPdfStage('Yazdırma seçenekleri açılıyor');
      await Printing.layoutPdf(
        name: _pdfFilename(),
        format: PdfPageFormat.a4,
        dynamicLayout: false,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (mounted) await _showPdfError('PDF yazdırılamadı', '$e');
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
          _pdfStage = '';
        });
      }
    }
  }

  Future<void> _shareReport() async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _pdfStage = 'PDF hazırlanıyor';
    });
    try {
      final bytes = await _buildCurrentPdf();
      _setPdfStage('Paylaşım seçenekleri açılıyor');
      final shared = Platform.isAndroid
          ? await PdfFileService.sharePdf(
              bytes: bytes,
              filename: _pdfFilename(),
            )
          : await Printing.sharePdf(
              bytes: bytes,
              filename: _pdfFilename(),
              subject: '2EKSPER Ekspertiz Raporu',
              body: '2EKSPER ekspertiz raporu ektedir.',
            );
      if (!shared) {
        throw const ApiException('Cihaz paylaşım ekranını açamadı.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF paylaşım ekranı açıldı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is PlatformException
            ? 'Cihazın paylaşım özelliği yanıt vermedi. Lütfen farklı bir uygulama seçmeyi deneyin.\n\nDetay: ${e.message}'
            : e.toString();
        await _showPdfError('PDF paylaşılamadı', message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
          _pdfStage = '';
        });
      }
    }
  }

  Future<void> _showPdfError(String title, String message) {
    final clean = message
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '');
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, size: 38),
        title: Text(title),
        content: Text(clean),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _cachedPdf = null;
                _cachedPdfForUrl = null;
              });
              _controller.reload();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Sayfayı Yenile'),
          ),
        ],
      ),
    );
  }

  Future<void> _goBack() async {
    if (!_isReport && await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    _closePanel();
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final target = Uri.tryParse(request.url);
    final current = Uri.tryParse(_currentUrl);
    final allowedHost = Uri.parse(ApiService.webRoot).host;
    if (request.isMainFrame &&
        target != null &&
        target.scheme != 'about' &&
        target.host.isNotEmpty &&
        target.host != allowedHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Güvenlik için dış bağlantı uygulama içinde açılmadı.'),
            ),
          );
        }
      });
      return NavigationDecision.prevent;
    }
    if (request.isMainFrame &&
        current?.path.endsWith('/rapor.php') == true &&
        target != null &&
        const {'index.php', 'raporlar.php', 'anasayfa.php'}.contains(
            target.pathSegments.isEmpty ? '' : target.pathSegments.last)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closePanel());
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _closePanel() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final webBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF08172B)
        : const Color(0xFFF3F3F1);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 52,
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: _isReport
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rapor Önizleme',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'No: ${Uri.tryParse(_currentUrl)?.queryParameters['id'] ?? '-'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .58),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Text(
                  '2EKSPER',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
          actions: [
            if (_isReport)
              PopupMenuButton<String>(
                tooltip: 'Diğer işlemler',
                enabled: !_printing,
                onSelected: (value) {
                  if (value == 'print') _systemPrint();
                  if (value == 'refresh') {
                    setState(() {
                      _cachedPdf = null;
                      _cachedPdfForUrl = null;
                    });
                    _openAuthenticated(widget.initialPath);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      leading: Icon(Icons.print_rounded),
                      title: Text('Yazdır'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh_rounded),
                      title: Text('Güncel veriyi yenile'),
                    ),
                  ),
                ],
              )
            else
              IconButton(
                tooltip: 'Yenile',
                onPressed: () => _controller.reload(),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 3,
                    color: const Color(0xFFFF641F),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: webBackground)),
            Positioned.fill(
              child: _error == null
                  ? WebViewWidget(controller: _controller)
                  : _ErrorView(
                      message: _error!,
                      onRetry: () {
                        setState(() => _error = null);
                        _openAuthenticated(widget.initialPath);
                      },
                    ),
            ),
            if (_printing)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xCC191C21),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.all(28),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 18),
                          const Text(
                            'Rapor hazırlanıyor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _pdfStage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .62),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _isReport
            ? Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _printing ? null : _shareReport,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Paylaş'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _printing ? null : _printReport,
                          icon: _printing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(
                            _printing ? 'Hazırlanıyor...' : 'Cihaza Kaydet',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Sunucuya ulaşılamadı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
