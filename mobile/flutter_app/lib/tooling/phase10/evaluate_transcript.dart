import 'dart:convert';
import 'dart:io';

import 'transcript_evaluation.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.isEmpty) {
    stdout.writeln(
      'Usage: dart run lib/tooling/phase10/evaluate_transcript.dart '
      '--input <evaluation.json> [--output <metrics.json>]',
    );
    exitCode = args.isEmpty ? 64 : 0;
    return;
  }

  try {
    final inputPath = _option(args, '--input');
    if (inputPath == null) {
      throw const FormatException('Missing required --input argument.');
    }
    final outputPath = _option(args, '--output');
    final decoded = jsonDecode(await File(inputPath).readAsString());
    if (decoded is! Map) {
      throw const FormatException('Evaluation input must be a JSON object.');
    }
    final input = decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final report = evaluatePhase10Transcription(input);
    final encoded = const JsonEncoder.withIndent('  ').convert(report);

    if (outputPath == null) {
      stdout.writeln(encoded);
    } else {
      await File(outputPath).writeAsString('$encoded\n');
      stdout.writeln('Wrote Phase 10 transcript metrics to $outputPath');
    }
  } on Object catch (error) {
    stderr.writeln('Phase 10 transcript evaluation failed: $error');
    exitCode = 65;
  }
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0) {
    return null;
  }
  if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
    throw FormatException('$name requires a value');
  }
  return args[index + 1];
}
