# Phase 4 — Candidate discovery, ranking and editorial annotations

**Current state:** deterministic candidate discovery and project-scoped evidence are implemented. Real-media editorial quality and human-selection acceptance remain open.

## Implemented scope

- Versioned transcript, word, audio-evidence, visual-sample, clip-candidate and candidate-set contracts validate timestamps, source boundaries and scores.
- Candidate windows are derived from transcript sentence punctuation, pauses and word timing. Invalid ranges and ranges outside the configured duration band/source duration are rejected.
- Ranking combines available speech density, audio RMS and sampled visual frame-change evidence. Missing signals are omitted and remaining weights are normalized.
- Candidate selection applies overlap/text-similarity deduplication and source-coverage balancing. The engine may return fewer clips rather than fabricate candidates to satisfy a requested count.
- The native bridge samples bounded, low-resolution luma/frame changes. This is visual-change evidence only; it is not semantic scene understanding, object recognition, diarization or active-speaker detection.
- Optional local Qwen annotation can provide editorial text (title, hook, summary and explanation) for existing candidate IDs. It cannot change IDs, timestamps, scores or source evidence. Invalid/unknown model output falls back to deterministic candidates.
- Transcript and candidate artifacts are stored per project, separate from the project index, and are removed with the owning project.

## Source map

- `lib/services/candidate_discovery_service.dart`
- `lib/services/local_editorial_annotation_service.dart`
- `lib/domain/transcript_contract.dart`
- `lib/domain/clip_candidate.dart`
- `lib/services/local_project_repository.dart`
- `lib/services/project_analysis_repository.dart`

## Automated coverage

- `candidate_discovery_test.dart`, `local_editorial_annotation_test.dart`, `project_analysis_repository_test.dart`, `transcript_contract_test.dart`.
- Tests cover source/duration constraints, reliable timing, no-fabricated-result behavior, sentence/word boundaries, deduplication, coverage and the model annotation allow-list.

## Limits and required field tests

- Frame-change signals do not establish that a scene is semantically relevant or that a face is speaking.
- Qwen annotation is optional text assistance, not a replacement for deterministic candidate selection or human editorial review.
- On the physical Arabic/English corpus, record candidate completeness, editorial precision, duplicate ratio, source coverage, boundary correctness and human keep/reject outcomes. Include difficult footage (music-heavy, sparse speech, gaming/webcam and screen demonstrations).
- Keep each fixture SHA and review protocol with the results. Candidate quality must not be inferred from a green unit suite.

**Related:** [Phase register](README.md), [Phase 3–4 integration record](../docs/mobile/PHASES_3_4_INTEGRATION.md), [Phase 10 evidence protocol](10-physical-device-acceptance.md).
