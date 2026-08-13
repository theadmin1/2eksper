import 'package:eksper_mobile/widgets/body_map_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kayıtlı çizim seçilir, taşınır ve silinir', (tester) async {
    var polygons = <dynamic>[
      {
        'type': 'lokal',
        'points': [
          {'x': 100, 'y': 100},
          {'x': 150, 'y': 100},
          {'x': 150, 'y': 150},
          {'x': 100, 'y': 150},
        ],
        'dx': 0,
        'dy': 0,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 360,
                child: StatefulBuilder(
                  builder: (context, setState) => BodyMapEditor(
                    parts: const {},
                    labels: const {},
                    polygons: polygons,
                    onPartsChanged: (_) {},
                    onPolygonsChanged: (value) => setState(() {
                      polygons = value;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    await tester.tap(find.text('Düzenle'));
    await tester.pump();

    final canvas = find.byWidgetPredicate(
      (widget) => widget is Listener && widget.onPointerMove != null,
    );
    final rect = tester.getRect(canvas);
    Offset actualPoint(double x, double y) => Offset(
          rect.left + (x / 311) * rect.width,
          rect.top + (y / 391) * rect.height,
        );

    await tester.tapAt(actualPoint(125, 125));
    await tester.pump();
    expect(find.text('Çizim seçildi'), findsOneWidget);

    final gesture = await tester.startGesture(actualPoint(125, 125));
    await gesture.moveBy(const Offset(10, 8));
    await tester.pump();
    await gesture.moveBy(const Offset(24, 18));
    await gesture.up();
    await tester.pump();
    expect((polygons.first['dx'] as num).toDouble(), greaterThan(0));
    expect((polygons.first['dy'] as num).toDouble(), greaterThan(0));

    await tester.ensureVisible(find.text('Seçili Çizimi Sil'));
    await tester.pump();
    await tester.tap(find.text('Seçili Çizimi Sil'));
    await tester.pump();
    expect(polygons, isEmpty);
    expect(find.text('Çizim silindi.'), findsOneWidget);
  });
}
