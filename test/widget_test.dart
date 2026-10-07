import 'package:annotate_picture/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('démarre sur le bouton Ouvrir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Editor()));
    expect(find.text('Ouvrir une image'), findsOneWidget);
  });
}
