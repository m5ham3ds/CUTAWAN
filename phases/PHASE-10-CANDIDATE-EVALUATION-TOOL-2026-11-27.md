# Phase 10 — candidate quality and human-selection evaluator

**Prepared:** 2026-11-27  
**Status:** Automated evaluator implemented; physical candidate measurements remain uncollected.

## Purpose

The evaluator compares a CUTAWAN candidate-discovery run with a set of editorial moments identified and reviewed by a human for the exact same source fixture. It reports temporal candidate precision/recall, redundant candidate ratio, temporal source coverage, and human editorial selection outcomes. It does not run candidate discovery, create reference labels, decide publishability or accept any development phase.

## Run

From `mobile/flutter_app/`:

```bash
dart run lib/tooling/phase10/evaluate_candidates.dart --input /path/to/candidate-evaluation.json --output /path/to/candidate-metrics.json
```

Omit `--output` to write the report to stdout. Invalid or incomplete evidence returns a non-zero exit status; no metrics report is written.

## Input schema

Schema: `org.cutawan.phase10.candidate-evaluation`, version 1.

```json
{
  "schema": "org.cutawan.phase10.candidate-evaluation",
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
    "id": "arabic-interview-01",
    "sha256": "64-character source media SHA-256",
    "durationMs": 180000
  },
  "reference": {
    "reviewStatus": "human-reviewed",
    "reviewerId": "gold-reviewer-01",
    "reviewedAtUtc": "2026-11-27T09:00:00.000Z",
    "moments": [
      {
        "id": "gold-01",
        "startMs": 12000,
        "endMs": 35000,
        "label": "complete explanation with context and payoff"
      }
    ]
  },
  "candidateRun": {
    "runId": "run-01",
    "rankingEngine": "deterministic-evidence-v1",
    "candidates": [
      { "id": "clip_12000_35000", "startMs": 12000, "endMs": 35000, "score": 92.5 }
    ]
  },
  "humanReview": {
    "reviewStatus": "human-reviewed",
    "reviewerId": "editor-01",
    "reviewedAtUtc": "2026-11-27T09:30:00.000Z",
    "decisions": [
      { "candidateId": "clip_12000_35000", "decision": "keep" }
    ]
  },
  "settings": {
    "matchIouThreshold": 0.5,
    "duplicateOverlapThreshold": 0.85,
    "sourceCoverageBucketCount": 10
  }
}
```

The example is a data-shape illustration only. It is not a CUTAWAN measurement and must not be included as acceptance evidence. Each reference moment needs a short human-authored label and each source interval uses integer milliseconds relative to the same source. IDs must be unique and use only letters, digits, dot, underscore or hyphen.

The source SHA-256 and exact application build SHA are mandatory. Device identity must be manually confirmed; a device-fingerprint heuristic is not proof. Both the gold moments and candidate editor decisions must be human reviewed. An omitted candidate decision is counted as unreviewed, not rejected. Every decision must identify a candidate present in the supplied run.

## Metric definitions

- **Candidate precision / recall / F1:** candidate and gold intervals are matched one-to-one when temporal intersection-over-union (IoU) meets the configured threshold (default 0.50). Each candidate and each gold moment can be matched at most once. Pairs are processed by descending IoU, then candidate score, then stable IDs. This versioned greedy policy is deterministic, but it is not a claim of optimal bipartite assignment.
- **False positives / false negatives:** unmatched generated candidates and unmatched gold moments, respectively.
- **Duplicate candidate ratio:** the number of redundant members beyond the first in each connected overlap cluster divided by the total candidate count. Two candidates are connected when their overlap divided by the shorter candidate duration meets the configured threshold (default 0.85).
- **Source temporal coverage:** union duration of all candidate intervals divided by source duration. In addition, the source is split into ten equal-duration buckets by default; the report records which buckets contain at least one candidate. This measures temporal coverage, not semantic topic diversity.
- **Human selection:** `keep` means selected as suggested, `repair` means selected after editing, and `reject` means not selected. Unreviewed candidates are reported separately and never treated as rejects. Selection rates use only reviewed candidates as their denominator.

Precision is `null` when there are no generated candidates; recall is `null` when the gold set is empty; F1 is `null` when either denominator is undefined. Null is not converted to a passing score.

## Resource and privacy limits

- Maximum 2,000 candidates and 1,000 gold moments.
- Candidate/reference comparison product is capped at 250,000 pairs.
- Duplicate-pair comparisons are capped at 1,000,000.
- The report contains IDs, time intervals and aggregate counts only. It does not include transcript text, titles, source filenames, personal paths, media contents or provider credentials.
- The evaluator defines no quality threshold and never updates phase acceptance state automatically.

No reference set or candidate result is populated by this implementation. Use it only with a hash-locked source, confirmed physical handset, pinned APK and independent human review. See [Phase 10 acceptance requirements](10-physical-device-acceptance.md).
