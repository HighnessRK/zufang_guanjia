import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/ui/transitions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final cfg = AppConfig.instance;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('personalization-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await cfg.init();
  });
  tearDownAll(() async => dir.delete(recursive: true));

  test('主题默认跟随系统，图标与个性化保存重载且兼容旧配置', () async {
    expect(cfg.themeMode, 'system');
    cfg.themeMode = 'dark';
    cfg.iconStyle = 'ocean';
    cfg.backgroundStyle = 'jade';
    cfg.motionStyle = 'off';
    cfg.haptics = false;
    cfg.clearGlass = false;
    cfg.ocrAcceleration = 'cpu';
    await cfg.save();
    cfg.themeMode = 'light';
    cfg.iconStyle = 'mono';
    cfg.backgroundStyle = 'none';
    cfg.motionStyle = 'standard';
    cfg.haptics = true;
    cfg.clearGlass = true;
    cfg.ocrAcceleration = 'auto';
    await cfg.load();
    expect([cfg.themeMode, cfg.iconStyle, cfg.backgroundStyle, cfg.motionStyle],
        ['dark', 'ocean', 'jade', 'off']);
    expect([cfg.haptics, cfg.clearGlass], [false, false]);
    expect(cfg.ocrAcceleration, 'cpu');
    await File(cfg.configPath!)
        .writeAsString('theme_mode=invalid\nicon_style=invalid\n');
    await cfg.load();
    expect([cfg.themeMode, cfg.iconStyle, cfg.backgroundStyle, cfg.motionStyle],
        ['system', 'aurora', 'aurora', 'standard']);
    expect(cfg.ocrAcceleration, 'auto');
  });

  test('减少动效时页面没有等待，舒缓模式提供更长过渡', () {
    cfg.motionStyle = 'off';
    final off = AppPageRoute<void>(builder: (_) => const SizedBox());
    expect(off.transitionDuration, Duration.zero);
    expect(off.reverseTransitionDuration, Duration.zero);
    cfg.motionStyle = 'gentle';
    expect(
        AppPageRoute<void>(builder: (_) => const SizedBox())
            .transitionDuration
            .inMilliseconds,
        greaterThan(240));
    cfg.motionStyle = 'standard';
  });
}
