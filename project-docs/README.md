# Project docs

## Audits

- [audits/state-machines-2026-11-06.md](audits/state-machines-2026-11-06.md): state machines, transition tables and 9 reachable bugs (2 proved by test, 7 code path); repro suite in `audits/state-machines-2026-11-06-repro.swift`.
- [audits/state-machines-2026-11-06-review.md](audits/state-machines-2026-11-06-review.md): independent review of that audit: 4 confirmed, 4 minor, 1 not a bug (B8), 0 unverified; B5 proved by a UI test, repro suite rerun.
- [audits/state-machines-2026-11-06-fixes.md](audits/state-machines-2026-11-06-fixes.md): fixes for that review: 8 of 8 in-scope claims fixed, 0 held, 0 skipped; regression tests in `StateMachineFixTests`, `OnboardingDoubleTapUITests` and `PaywallRestoreUITests`, full suites green.
- [audits/state-machines-2026-11-06-verify.md](audits/state-machines-2026-11-06-verify.md): independent verification of those fixes: PASS, 8 of 8 work, no regression; full suites 73/73 unit and 7/7 UI, every regression test fails with its fix reverted.
- [audits/presubmit-review-2026-11-07.md](audits/presubmit-review-2026-11-07.md): pre-submit review of the 1.0.3 to 1.0.4 app diff: 0 fixes, 0 open P0/P1, 3 P2 noted; unit suite run on gh-sim.
