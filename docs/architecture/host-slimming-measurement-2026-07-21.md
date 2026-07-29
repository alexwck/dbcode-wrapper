---
title: Host slimming measurement - 21 July 2026
description: Historical size and startup measurements from the first compatible-host slimming pass.
tags:
  - architecture
  - measurement
  - host
source_commit: d7f504fc47d6fc2c7ff7691f3c680f22988e9742
---
# Host slimming measurement — 21 July 2026

This page preserves the dated measurement that was previously mixed into the active slimming policy. It is historical evidence, not a current build input. The active allowlist, size goals, and rollback remain in [`host/slimming-policy.json`](../../host/slimming-policy.json).

## Baseline

| Item | Historical measurement |
| --- | ---: |
| Signed app, installed | 937,596 KiB |
| Signed app, indicative archive | 264,659,573 bytes |
| Electron Framework, installed | 270,980 KiB |
| Code OSS application, installed | 642,436 KiB |
| Built-in extensions | 93 extensions plus shared dependencies |
| Built-in extensions, installed | 167,336 KiB |
| Source maps | 826 files; 364,904,314 logical bytes; 358,596 allocated KiB |

The external unchanged DBCode 1.36.1 package was not bundled in the app. Its expanded installation used 271,444 KiB and 274,298,343 logical bytes. Its VSIX used 43,262,773 bytes.

Removing source maps alone projected an installed app of 579,000 KiB and an indicative archive of 196,286,440 bytes.

## Measured result

| Item | Historical measurement |
| --- | ---: |
| Signed app, installed | 462,100 KiB |
| Signed app, indicative archive | 166,475,377 bytes |
| Installed reduction | 475,496 KiB, or 50.71% |
| Indicative archive reduction | 98,184,196 bytes, or 37.1% |
| Electron Framework, installed | 270,980 KiB |
| Code OSS application, installed | 167,472 KiB |
| Built-in extensions | 9 extensions; no shared dependency directory |
| Built-in extensions, installed | 776 KiB |
| Source maps | 0 files; 0 logical bytes; 0 allocated KiB |

The external unchanged DBCode 1.36.2 package remained outside the app. Its expanded installation used 271,532 KiB and 274,400,008 logical bytes. Its VSIX used 43,297,713 bytes.

The complete seven-extension external runtime also remained outside the app. It used 361,544 KiB when installed, 359,124,746 logical bytes, and 70,858,742 bytes across its VSIX files.

## Startup observation

Three isolated launches reached a stable renderer in 7.18, 7.32, and 6.98 seconds. The median was 7.18 seconds and included static signature and manifest checks. There was no controlled pre-slim startup baseline, so this evidence does not claim a startup speed improvement.

## Measurement method

Installed size used `du -sk`. The indicative archive used `COPYFILE_DISABLE=1 tar -czf`; it was not a release ZIP or DMG. The 93 built-ins did not include the shared `extensions/node_modules` dependency directory as another extension.

The active policy keeps a 614,400 KiB installed-app limit and a 200,000,000-byte indicative-archive limit. DBCode remains external and is never slimmed by that policy.

## Recorded acceptance at the time

The measured signed app was recorded as passing static and rendered checks, real-Keychain use, PostgreSQL, DuckDB, Parquet, SQL-file and result-layout checks, quit, and relaunch. This is dated evidence only. Current release acceptance follows the maintained prompt-free verification policy and does not inherit those older human or external checks.