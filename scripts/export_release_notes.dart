import 'dart:io';
import 'package:zufang_guanjia/core/constants/app_changelog.dart';

// Generate the release body from the same entries displayed in About.
void main(List<String> args) {
  final version = AppChangelog.versions.first;
  final notes = version.entries.map((e) => '- ${e.type}：${e.text}').join('\n');
  final output = File(args.isEmpty ? 'build/release-notes.md' : args.first);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('$notes\n');
  stdout.writeln(
      'Exported V${version.version}: ${version.entries.length} entries');
}
