import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivpn_installer/main.dart';

void main() {
  testWidgets('installer advances from welcome to options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(940, 660));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const InstallerApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });
}
