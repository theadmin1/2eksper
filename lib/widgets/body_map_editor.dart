import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BodyMapEditor extends StatefulWidget {
  const BodyMapEditor({
    super.key,
    required this.parts,
    required this.labels,
    required this.polygons,
    required this.onPartsChanged,
    required this.onPolygonsChanged,
  });

  final Map<String, String> parts;
  final Map<String, String> labels;
  final List<dynamic> polygons;
  final ValueChanged<Map<String, String>> onPartsChanged;
  final ValueChanged<List<dynamic>> onPolygonsChanged;

  static const logicalSize = Size(311, 391);

  @override
  State<BodyMapEditor> createState() => BodyMapEditorState();
}

class BodyMapEditorState extends State<BodyMapEditor> {
  static const logicalSize = BodyMapEditor.logicalSize;
  static const statuses = ['orijinal', 'lokal', 'boyali', 'degisen', 'plastik'];

  static const partRects = <String, Rect>{
    'front-bumper': Rect.fromLTWH(104, 16, 105, 22),
    'front-left-mudguard': Rect.fromLTWH(21, 51, 28, 43),
    'front-right-mudguard': Rect.fromLTWH(262, 51, 28, 43),
    'front-hood': Rect.fromLTWH(101, 48, 110, 80),
    'front-left-door': Rect.fromLTWH(21, 108, 80, 104),
    'front-right-door': Rect.fromLTWH(210, 108, 80, 105),
    'rear-left-door': Rect.fromLTWH(21, 197, 79, 84),
    'rear-right-door': Rect.fromLTWH(211, 197, 79, 85),
    'roof': Rect.fromLTWH(119, 208, 74, 53),
    'rear-hood': Rect.fromLTWH(104, 309, 104, 30),
    'rear-left-mudguard': Rect.fromLTWH(21, 292, 28, 46),
    'rear-right-mudguard': Rect.fromLTWH(262, 293, 28, 45),
    'rear-bumper': Rect.fromLTWH(104, 352, 105, 22),
  };

  String mode = 'part';
  String drawType = 'lokal';
  final List<Offset> drawing = [];
  int? selectedPolygon;
  int? draggingPolygon;
  Offset? dragStartPoint;
  double startDx = 0;
  double startDy = 0;
  ui.Image? backgroundImage;
  ui.Image? maskImage;

  int get pendingPointCount => drawing.length;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant BodyMapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedPolygon != null && selectedPolygon! >= widget.polygons.length) {
      selectedPolygon = null;
    }
  }

  Future<void> _loadImages() async {
    final images = await Future.wait([
      _loadImage('assets/images/vehicle_plan.png'),
      _loadImage('assets/images/vehicle_mask.png'),
    ]);
    if (!mounted) return;
    setState(() {
      backgroundImage = images[0];
      maskImage = images[1];
    });
  }

  Future<ui.Image> _loadImage(String asset) async {
    final ByteData data = await rootBundle.load(asset);
    final bytes = Uint8List.sublistView(data);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Color colorFor(String status) => switch (status) {
        'lokal' => const Color(0xFFEAB308),
        'boyali' => const Color(0xFF3B82F6),
        'degisen' => const Color(0xFFF97316),
        'plastik' => const Color(0xFF22C55E),
        _ => const Color(0xFF10D981),
      };

  Color polygonColor(String status) => switch (status) {
        'boyali' => const Color(0xB83B82F6),
        'degisen' => const Color(0xB8F97316),
        _ => const Color(0xB8EAB308),
      };

  String _label(String status) => switch (status) {
        'orijinal' => 'Orijinal',
        'lokal' => 'Lokal Boyalı',
        'boyali' => 'Boyalı',
        'degisen' => 'Değişen',
        'plastik' => 'Plastik',
        _ => status,
      };

  Future<void> selectPart(String key) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                widget.labels[key] ?? key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final status in statuses)
              ListTile(
                leading: CircleAvatar(backgroundColor: colorFor(status)),
                title: Text(_label(status)),
                trailing: widget.parts[key] == status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    widget.onPartsChanged(
      Map<String, String>.from(widget.parts)..[key] = selected,
    );
  }

  String? partAt(Offset point) {
    for (final entry in partRects.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    return null;
  }

  static double _number(dynamic value) => double.tryParse('$value') ?? 0;

  static List<Offset> _points(dynamic polygon) {
    if (polygon is! Map) return [];
    if (polygon['points'] is List) {
      return (polygon['points'] as List)
          .map((point) {
            if (point is Map) {
              return Offset(_number(point['x']), _number(point['y']));
            }
            if (point is List && point.length >= 2) {
              return Offset(_number(point[0]), _number(point[1]));
            }
            return null;
          })
          .whereType<Offset>()
          .toList();
    }
    final x = _number(polygon['x']);
    final y = _number(polygon['y']);
    final w = _number(polygon['w']);
    final h = _number(polygon['h']);
    return [
      Offset(x, y),
      Offset(x + w, y),
      Offset(x + w, y + h),
      Offset(x, y + h),
    ];
  }

  int? polygonAt(Offset point) {
    for (var index = widget.polygons.length - 1; index >= 0; index--) {
      final raw = widget.polygons[index];
      if (raw is! Map) continue;
      final points = _points(raw);
      if (points.length < 3) continue;
      final offset = Offset(_number(raw['dx']), _number(raw['dy']));
      final path = Path()
        ..addPolygon(points.map((value) => value + offset).toList(), true);
      if (path.contains(point)) return index;
    }
    return null;
  }

  Offset logicalPoint(Offset local, Size actual) => Offset(
        local.dx * logicalSize.width / actual.width,
        local.dy * logicalSize.height / actual.height,
      );

  void handleTap(TapDownDetails details, Size size) {
    final point = logicalPoint(details.localPosition, size);
    if (mode == 'part') {
      final key = partAt(point);
      if (key != null) selectPart(key);
      return;
    }
    if (mode == 'edit') {
      setState(() => selectedPolygon = polygonAt(point));
      return;
    }
    if (mode != 'draw') return;

    if (drawing.length >= 3 && (point - drawing.first).distance <= 12) {
      finishDrawing();
      return;
    }
    setState(() => drawing.add(point));
  }

  void finishDrawing() {
    if (drawing.length < 3) return;
    final polygon = <String, dynamic>{
      'type': drawType,
      'points': drawing
          .map((point) => {
                'x': point.dx.round(),
                'y': point.dy.round(),
              })
          .toList(),
      'dx': 0,
      'dy': 0,
    };
    final hitPart = partAt(drawing.first);
    if (hitPart != null) {
      widget.onPartsChanged(
        Map<String, String>.from(widget.parts)..[hitPart] = drawType,
      );
    }
    final updated = List<dynamic>.from(widget.polygons)..add(polygon);
    widget.onPolygonsChanged(updated);
    setState(() {
      drawing.clear();
      mode = 'edit';
      selectedPolygon = updated.length - 1;
    });
  }

  Map<String, dynamic>? takePendingPolygon() {
    if (drawing.length < 3) return null;
    final polygon = <String, dynamic>{
      'type': drawType,
      'points': drawing
          .map((point) => {'x': point.dx.round(), 'y': point.dy.round()})
          .toList(),
      'dx': 0,
      'dy': 0,
    };
    final hitPart = partAt(drawing.first);
    if (hitPart != null) {
      widget.onPartsChanged(
        Map<String, String>.from(widget.parts)..[hitPart] = drawType,
      );
    }
    setState(() => drawing.clear());
    return polygon;
  }

  void editPointerDown(Offset localPosition, Size size) {
    final point = logicalPoint(localPosition, size);
    final index = polygonAt(point);
    setState(() => selectedPolygon = index);
    if (index == null) return;
    final polygon = widget.polygons[index] as Map;
    draggingPolygon = index;
    dragStartPoint = point;
    startDx = _number(polygon['dx']);
    startDy = _number(polygon['dy']);
  }

  void editPointerMove(Offset localPosition, Size size) {
    if (draggingPolygon == null || dragStartPoint == null) {
      return;
    }
    final point = logicalPoint(localPosition, size);
    final updated = List<dynamic>.from(widget.polygons);
    final polygon = Map<String, dynamic>.from(updated[draggingPolygon!] as Map);
    final points = _points(polygon);
    final minX =
        points.map((value) => value.dx).reduce((a, b) => a < b ? a : b);
    final maxX =
        points.map((value) => value.dx).reduce((a, b) => a > b ? a : b);
    final minY =
        points.map((value) => value.dy).reduce((a, b) => a < b ? a : b);
    final maxY =
        points.map((value) => value.dy).reduce((a, b) => a > b ? a : b);
    final dx = startDx + point.dx - dragStartPoint!.dx;
    final dy = startDy + point.dy - dragStartPoint!.dy;
    polygon['dx'] = dx.clamp(-minX, logicalSize.width - maxX).round();
    polygon['dy'] = dy.clamp(-minY, logicalSize.height - maxY).round();
    updated[draggingPolygon!] = polygon;
    widget.onPolygonsChanged(updated);
  }

  void editPointerUp() {
    draggingPolygon = null;
    dragStartPoint = null;
  }

  void _changeSelectedType(String status) {
    final index = selectedPolygon;
    if (index == null || index >= widget.polygons.length) return;
    final updated = List<dynamic>.from(widget.polygons);
    final polygon = Map<String, dynamic>.from(updated[index] as Map);
    polygon['type'] = status;
    updated[index] = polygon;
    widget.onPolygonsChanged(updated);
    setState(() {});
  }

  void _deleteSelected() {
    final index = selectedPolygon;
    if (index == null || index >= widget.polygons.length) return;
    final previous = List<dynamic>.from(widget.polygons);
    final removed = previous[index];
    final updated = List<dynamic>.from(previous)..removeAt(index);
    widget.onPolygonsChanged(updated);
    setState(() => selectedPolygon = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Çizim silindi.'),
          action: SnackBarAction(
            label: 'GERİ AL',
            onPressed: () {
              final restored = List<dynamic>.from(widget.polygons);
              restored.insert(index.clamp(0, restored.length).toInt(), removed);
              widget.onPolygonsChanged(restored);
              setState(() => selectedPolygon = index);
            },
          ),
        ),
      );
  }

  Future<void> _clearPolygons() async {
    if (widget.polygons.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm çizimler silinsin mi?'),
        content: const Text(
          'Araç üzerindeki kayıtlı çizimlerin tamamı kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Tümünü Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onPolygonsChanged(<dynamic>[]);
    if (mounted) setState(() => selectedPolygon = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loaded = backgroundImage != null && maskImage != null;
    final selected =
        selectedPolygon != null && selectedPolygon! < widget.polygons.length
            ? widget.polygons[selectedPolygon!]
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Çizim Aracı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${widget.polygons.length} çizim',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _modeButton(
                value: 'part',
                icon: Icons.touch_app_rounded,
                label: 'Parça',
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _modeButton(
                value: 'draw',
                icon: Icons.polyline_rounded,
                label: 'Yeni Çiz',
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _modeButton(
                value: 'edit',
                icon: Icons.open_with_rounded,
                label: 'Düzenle',
              ),
            ),
          ],
        ),
        if (mode == 'draw') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['lokal', 'boyali', 'degisen']
                .map(
                  (status) => ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: polygonColor(status)),
                    selected: drawType == status,
                    label: Text(_label(status)),
                    onSelected: (_) => setState(() => drawType = status),
                  ),
                )
                .toList(),
          ),
        ],
        if (mode == 'edit' && widget.polygons.isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearPolygons,
              icon: const Icon(Icons.delete_sweep_outlined, size: 19),
              label: const Text('Tüm çizimleri temizle'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _legend('Orijinal', const Color(0xFF22C55E)),
            _legend('Lokal Boyalı', const Color(0xFFEAB308)),
            _legend('Boyalı', const Color(0xFF3B82F6)),
            _legend('Değişen', const Color(0xFFF97316)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: AspectRatio(
            aspectRatio: logicalSize.width / logicalSize.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (!loaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                final canvas = CustomPaint(
                  painter: _BodyPainter(
                    backgroundImage: backgroundImage!,
                    maskImage: maskImage!,
                    parts: widget.parts,
                    polygons: widget.polygons,
                    drawing: drawing,
                    selectedPolygon: selectedPolygon,
                    colorFor: colorFor,
                    polygonColor: polygonColor,
                  ),
                );
                if (mode == 'edit') {
                  return RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      EagerGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                              EagerGestureRecognizer>(
                        EagerGestureRecognizer.new,
                        (_) {},
                      ),
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) =>
                          editPointerDown(event.localPosition, size),
                      onPointerMove: (event) =>
                          editPointerMove(event.localPosition, size),
                      onPointerUp: (_) => editPointerUp(),
                      onPointerCancel: (_) => editPointerUp(),
                      child: canvas,
                    ),
                  );
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => handleTap(details, size),
                  child: canvas,
                );
              },
            ),
          ),
        ),
        if (mode == 'edit') ...[
          const SizedBox(height: 10),
          if (selected is Map)
            _selectionPanel(selected)
          else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.tertiary.withValues(alpha: .32),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: colors.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.polygons.isEmpty
                          ? 'Henüz kayıtlı çizim yok. “Yeni Çiz” ile ekleyebilirsiniz.'
                          : 'Taşımak veya silmek için araç üzerindeki renkli çizime dokunun.',
                      style: TextStyle(
                        color: colors.onTertiaryContainer,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (mode == 'draw' && drawing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    if (drawing.isNotEmpty) drawing.removeLast();
                  }),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text('Geri Al (${drawing.length})'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: drawing.length >= 3 ? finishDrawing : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Alanı Tamamla'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          mode == 'part'
              ? 'Araç parçasına dokunup durumunu seçin.'
              : mode == 'draw'
                  ? 'Hasarın köşelerine tek tek dokunun; en az 3 noktadan sonra alanı tamamlayın.'
                  : 'Bir çizime dokunarak seçin; seçili alanı parmağınızla sürükleyerek taşıyın.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: .66),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String value,
    required IconData icon,
    required String label,
  }) {
    final selected = mode == value;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        mode = value;
        drawing.clear();
        draggingPolygon = null;
        dragStartPoint = null;
        if (value != 'edit') selectedPolygon = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? colors.onPrimary : colors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionPanel(Map polygon) {
    final type = '${polygon['type'] ?? 'lokal'}';
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFFFF9D0A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Çizim seçildi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '#${selectedPolygon! + 1}',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: .56),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Taşımak için seçili alanı sürükleyin. Durumunu aşağıdan değiştirebilirsiniz.',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: .56),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['lokal', 'boyali', 'degisen']
                .map(
                  (status) => ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: polygonColor(status)),
                    selected: type == status,
                    label: Text(_label(status)),
                    onSelected: (_) => _changeSelectedType(status),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Seçili Çizimi Sil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD92D20),
              side: const BorderSide(color: Color(0xFFF2B8B5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 17, height: 17, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.backgroundImage,
    required this.maskImage,
    required this.parts,
    required this.polygons,
    required this.drawing,
    required this.selectedPolygon,
    required this.colorFor,
    required this.polygonColor,
  });

  final ui.Image backgroundImage;
  final ui.Image maskImage;
  final Map<String, String> parts;
  final List<dynamic> polygons;
  final List<Offset> drawing;
  final int? selectedPolygon;
  final Color Function(String) colorFor;
  final Color Function(String) polygonColor;

  static const sourceRects = <String, Rect>{
    'front-bumper': Rect.fromLTWH(532, 252, 105, 22),
    'front-left-mudguard': Rect.fromLTWH(872, 43, 28, 43),
    'front-right-mudguard': Rect.fromLTWH(900, 0, 28, 43),
    'front-hood': Rect.fromLTWH(0, 682, 110, 80),
    'front-left-door': Rect.fromLTWH(190, 473, 80, 104),
    'front-right-door': Rect.fromLTWH(110, 577, 80, 105),
    'rear-left-door': Rect.fromLTWH(349, 304, 79, 84),
    'rear-right-door': Rect.fromLTWH(270, 388, 79, 85),
    'roof': Rect.fromLTWH(742, 177, 74, 53),
    'rear-bumper': Rect.fromLTWH(637, 230, 105, 22),
    'rear-hood': Rect.fromLTWH(428, 274, 104, 30),
    'rear-left-mudguard': Rect.fromLTWH(816, 131, 28, 46),
    'rear-right-mudguard': Rect.fromLTWH(844, 86, 28, 45),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 311, size.height / 391);
    canvas.drawImage(backgroundImage, Offset.zero, Paint());

    for (final entry in sourceRects.entries) {
      final destination = BodyMapEditorState.partRects[entry.key]!;
      final color = colorFor(parts[entry.key] ?? 'orijinal');
      canvas.drawImageRect(
        maskImage,
        entry.value,
        destination,
        Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    final outline = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < polygons.length; index++) {
      final raw = polygons[index];
      if (raw is! Map) continue;
      final points = BodyMapEditorState._points(raw);
      if (points.length < 3) continue;
      final offset = Offset(
        BodyMapEditorState._number(raw['dx']),
        BodyMapEditorState._number(raw['dy']),
      );
      final path = Path()
        ..addPolygon(points.map((point) => point + offset).toList(), true);
      canvas.drawPath(path, Paint()..color = polygonColor('${raw['type']}'));
      final selected = selectedPolygon == index;
      canvas.drawPath(
        path,
        Paint()
          ..color = selected ? const Color(0xFFFF9D0A) : const Color(0xFF111827)
          ..strokeWidth = selected ? 3 : 1
          ..style = PaintingStyle.stroke,
      );
      if (selected) {
        for (final point in points.map((value) => value + offset)) {
          canvas.drawCircle(point, 4.5, Paint()..color = Colors.white);
          canvas.drawCircle(
            point,
            4.5,
            Paint()
              ..color = const Color(0xFFFF9D0A)
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }

    if (drawing.isNotEmpty) {
      final path = Path()..moveTo(drawing.first.dx, drawing.first.dy);
      for (final point in drawing.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF111827)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(drawing.first, 6, Paint()..color = Colors.red);
      canvas.drawCircle(
        drawing.first,
        6,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      for (final point in drawing.skip(1)) {
        canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 3.5, outline);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) => true;
}
