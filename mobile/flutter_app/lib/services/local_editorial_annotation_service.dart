import 'dart:convert';

import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../domain/clip_candidate.dart';

class LocalEditorialAnnotationService {
  const LocalEditorialAnnotationService();

  Future<CandidateSet> annotate(
    CandidateSet candidateSet, {
    required String modelPath,
  }) async {
    if (candidateSet.candidates.isEmpty) return candidateSet;
    final controller = LlamaController();
    try {
      await controller.loadModel(
        modelPath: modelPath,
        threads: 2,
        contextSize: 2048,
        gpuLayers: 0,
      );
      final input = candidateSet.candidates.take(6).map((candidate) => {
        'id': candidate.id,
        'text': candidate.transcriptText.substring(
          0,
          candidate.transcriptText.length > 1000
              ? 1000
              : candidate.transcriptText.length,
        ),
      }).toList();
      final prompt = '''
Return one JSON object only, with this exact shape:
{"items":[{"id":"existing id","title":"short title","hook":"opening hook","summary":"one factual sentence","explanations":["brief editorial observation"]}]}
Annotate only the supplied moments. Do not invent facts, change IDs or timestamps, assign scores, make virality promises, or output Markdown.
Keep title and hook concise. Write in the transcript language when clear.
INPUT:
${jsonEncode(input)}
''';
      final output = StringBuffer();
      await for (final token in controller.generateChat(
        messages: [
          ChatMessage(
            role: 'system',
            content: 'You are a cautious local video editor. Return valid JSON only.',
          ),
          ChatMessage(role: 'user', content: prompt),
        ],
        template: 'chatml',
        maxTokens: 420,
        temperature: 0.1,
        topP: 0.85,
        topK: 20,
        seed: 42,
      )) {
        output.write(token);
      }
      return applyJsonAnnotations(candidateSet, output.toString());
    } finally {
      await controller.dispose();
    }
  }

  static CandidateSet applyJsonAnnotations(
    CandidateSet candidateSet,
    String rawOutput,
  ) {
    final start = rawOutput.indexOf('{');
    final end = rawOutput.lastIndexOf('}');
    if (start < 0 || end <= start) return candidateSet;
    try {
      final decoded = jsonDecode(rawOutput.substring(start, end + 1));
      if (decoded is! Map<String, dynamic> || decoded['items'] is! List<dynamic>) {
        return candidateSet;
      }
      final known = {
        for (final candidate in candidateSet.candidates) candidate.id: candidate,
      };
      final annotations = <String, Map<String, dynamic>>{};
      for (final raw in decoded['items'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        final item = raw;
        final id = item['id'];
        if (id is! String ||
            !known.containsKey(id) ||
            annotations.containsKey(id)) {
          continue;
        }
        annotations[id] = item;
      }
      if (annotations.isEmpty) return candidateSet;
      final updated = candidateSet.candidates.map((candidate) {
        final annotation = annotations[candidate.id];
        if (annotation == null) return candidate;
        String textField(String key, String fallback, int maximum) {
          final value = annotation[key];
          if (value is! String || value.trim().isEmpty) return fallback;
          final normalized = value.trim();
          return normalized.substring(
            0,
            normalized.length > maximum ? maximum : normalized.length,
          );
        }

        final rawReasons = annotation['explanations'];
        final reasons = rawReasons is List
            ? rawReasons
                .whereType<String>()
                .map((reason) => reason.trim())
                .where((reason) => reason.isNotEmpty)
                .take(3)
                .toList()
            : candidate.explanations;
        return candidate.copyWith(
          title: textField('title', candidate.title, 80),
          hook: textField('hook', candidate.hook, 100),
          summary: textField('summary', candidate.summary, 240),
          explanations: reasons.isEmpty ? candidate.explanations : reasons,
          modelAnnotated: true,
        );
      }).toList(growable: false);
      return candidateSet.copyWith(
        candidates: updated,
        rankingEngine: 'deterministic-evidence-v1+qwen-local-annotation',
      );
    } on FormatException {
      return candidateSet;
    } on TypeError {
      return candidateSet;
    }
  }
}
