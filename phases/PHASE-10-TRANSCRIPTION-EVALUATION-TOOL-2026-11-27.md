# Phase 10 — word-error-rate and word-timing evaluator

**Prepared:** 2026-11-27  
**Status:** Automated evaluator added; field measurements still not collected.

## Purpose

This tool provides repeatable transcription measurements for a manually reviewed Arabic or English reference transcript and the CUTAWAN output generated from a hash-locked source on a confirmed physical handset. It does not run Whisper, select a model, infer device identity, or accept any phase.

## Run

From `mobile/flutter_app/`:

```bash
dart run lib/tooling/phase10/evaluate_transcript.dart --input /path/to/transcription-evaluation.json --output /path/to/transcription-metrics.json
```

The output can be written to stdout by omitting `--output`. Errors return a non-zero exit status and do not create a metrics report.

## Input contract

Schema: `org.cutawan.phase10.transcription-evaluation`, version 1.

```json
{
  "schema": "org.cutawan.phase10.transcription-evaluation",
  "schemaVersion": 1,
  "measuredAtUtc": "2026-11-27T10:10:00.000Z",
  "application": {
    "buildSha": "40-character Git commit SHA"
  },
  "device": {
    "manufacturer": "HONOR",
    "model": "X9c",
    "androidRelease": "16",
    "androidSdk": 36,
    "physicalDeviceConfirmationStatus": "confirmed"
  },
  "fixture": {
    "id": "arabic-single-speaker-01",
    "sha256": "64-character SHA-256 of the source fixture",
    "language": "ar",
    "durationMs": 120000
  },
  "reference": {
    "reviewStatus": "human-reviewed",
    "reviewerId": "reviewer-01",
    "reviewedAtUtc": "2026-11-27T09:00:00.000Z",
    "words": [
      { "text": "مرحبا", "startMs": 250, "endMs": 620 },
      { "text": "بكم", "startMs": 640, "endMs": 900 }
    ]
  },
  "hypothesis": {
    "engine": "whisper.cpp",
    "model": "base",
    "language": "ar",
    "words": [
      { "text": "مرحبا", "startMs": 270, "endMs": 630 },
      { "text": "بكم", "startMs": 650, "endMs": 920 }
    ]
  }
}
```

The sample words above illustrate the data shape only; they are not CUTAWAN measurements and must not be used as acceptance evidence. Every word array must be ordered by start time and contain one token per entry. Times are integer milliseconds relative to the fixture duration. The reference must be manually reviewed and include a pseudonymous reviewer ID and review timestamp. The source fixture SHA-256 and the exact application build SHA are mandatory. Device confirmation must be manually set to `confirmed`; the Android fingerprint heuristic is not accepted by this tool.

## Output metrics

- Word error rate (WER) and percentage, with substitutions, deletions and insertions reported separately.
- Reference and hypothesis word counts, exact normalized matches, matched-word coverage and precision.
- Median and P95 absolute start-time and end-time error, calculated only on exact normalized word matches.
- Build, device and fixture identity, along with the scoring/normalization version.

Normalization version `cutawan-ar-en-v1` lowercases Latin text, removes Arabic harakat and tatweel, normalizes alef variants and alef maqsura, and trims leading/trailing Arabic and Latin punctuation. Do not compare scores generated with different normalization versions as if they were identical. Timing metrics deliberately exclude substitutions, insertions and deletions; they are not zero when no exact words match, but `null`.

The P95 uses the nearest-rank percentile. The evaluator caps the dynamic-programming alignment at 8,000,000 cells (one byte per traceback cell plus two cost rows). Larger transcripts must be evaluated in shorter consecutive source-time windows; keep the original source SHA and record each window's source range in the field notes. This prevents unbounded memory growth on long media.

## Acceptance boundary

- The script computes metrics only. It does not provide a WER pass threshold, timing threshold, or quality verdict.
- It does not attach the results to the Phase 10 evidence template automatically. A reviewer must inspect the report and record it in the field evidence record.
- No Arabic/English device measurement is included with this implementation. No synthetic sample in this document is valid reference evidence.
- Phase 10 remains incomplete until the media corpus is hash-locked, reference transcripts are human-reviewed, measurements come from the physical device and are independently reviewed, and Phase 8/9 field prerequisites are satisfied.
