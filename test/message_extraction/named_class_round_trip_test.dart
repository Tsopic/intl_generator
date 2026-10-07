import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'extracts and generates a translated message from a named class',
    () async {
      final fixture = await Directory.systemTemp.createTemp(
        'intl-named-class-',
      );
      addTearDown(() => fixture.delete(recursive: true));
      final source = File('${fixture.path}/named_messages.dart');
      await source.writeAsString('''
import 'package:intl/intl.dart';
class NamedMessages {
  static String hello() => Intl.message('Hello', name: 'NamedMessages_hello');
}
''');
      final packages = File('.dart_tool/package_config.json').absolute.path;
      Future<ProcessResult> run(String script, List<String> args) =>
          Process.run(Platform.resolvedExecutable, [
            '--packages=$packages',
            script,
            ...args,
          ]);
      final extraction = await run('bin/extract_to_arb.dart', [
        '--output-dir=${fixture.path}',
        source.path,
      ]);
      expect(
        extraction.exitCode,
        0,
        reason: '${extraction.stdout}\n${extraction.stderr}',
      );
      final extracted =
          jsonDecode(
                await File('${fixture.path}/intl_messages.arb').readAsString(),
              )
              as Map<String, dynamic>;
      expect(extracted['NamedMessages_hello'], 'Hello');
      final translated = File('${fixture.path}/intl_et.arb');
      await translated.writeAsString(
        jsonEncode({'@@locale': 'et', 'NamedMessages_hello': 'Tere'}),
      );
      final generation = await run('bin/generate_from_arb.dart', [
        '--output-dir=${fixture.path}',
        source.path,
        translated.path,
      ]);
      expect(
        generation.exitCode,
        0,
        reason: '${generation.stdout}\n${generation.stderr}',
      );
      final runner = File('${fixture.path}/run.dart');
      await runner.writeAsString('''
import 'package:intl/intl.dart';
import 'named_messages.dart';
import 'messages_all.dart';
Future<void> main() async {
  await initializeMessages('et');
  Intl.defaultLocale = 'et';
  print(NamedMessages.hello());
}
''');
      final output = await run(runner.path, []);
      expect(output.exitCode, 0, reason: '${output.stdout}\n${output.stderr}');
      expect(output.stdout.toString().trim(), 'Tere');
    },
  );
}
