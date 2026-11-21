import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivpn_installer/main.dart';

void main() {
  testWidgets('installer advances from welcome to options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(940, 660));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const InstallerApp());
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Параметры установки'), findsOneWidget);
    expect(find.text('Установить'), findsOneWidget);
  });
}
