import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/widgets/model_download_progress.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.1, 1.25]) {
      testWidgets('模型下载显示总量而非40MB分片 $brightness / $scale', (tester) async {
        await tester.pumpWidget(MiuixSystemTheme(
            child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const Scaffold(
              body: SizedBox(
                  width: 280,
                  child: ModelDownloadProgress(
                      received: 650000000,
                      total: 1040937440,
                      detail: '主模型 · 分片 16/20'))),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('650.0 MB / 1.04 GB'), findsOneWidget);
        expect(find.text('62.4%'), findsOneWidget);
        expect(find.textContaining('40.0 MB'), findsNothing);
      });
    }
  }
}
