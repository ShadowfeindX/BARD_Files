# Firebase configuration

Realtime Database (RTDB) rules for live play and the checks that prove them. The design is in [docs/architecture/06-accounts-backend.md](../docs/architecture/06-accounts-backend.md#realtime-database-model-live-play) (P10c).

| File | What it is |
|---|---|
| `database.rules.json` | RTDB security rules. Started from probe 8.6's prototype, with R's P10c rulings 1-3 applied, the `phoneDraft` path removed (P23) and R's 2026-10-21 rulings on presence, `meta` validation, anonymous members and phone message shape. |
| `firebase.json` | Emulator configuration: Database emulator on `127.0.0.1:9000`, no UI. |
| `rtdb_rules_test/` | SDK-only Dart program (no packages) that checks the rules through the emulator's REST API. |
| `run_rtdb_rules_test.sh` | Starts the Database emulator, runs the checks, stops the emulator. |

## Running the checks

Needs the Dart SDK, Java, and `firebase-tools` from npm (`npm install -g firebase-tools`). From Git Bash:

```
bash firebase/run_rtdb_rules_test.sh
```

The project id `demo-bard` is a `demo-` project: the emulator runs fully offline and touches no real Firebase project. The program prints one PASS or FAIL line per check, then a total, and exits non-zero if any check fails.

## Changing the rules

Every rule change comes with checks for it in `rtdb_rules_test/bin/rtdb_rules_test.dart`, in the same PR. Checks build unsigned ID tokens (the emulator accepts them) and set `firebase.sign_in_provider` per user, so anonymous and full accounts can be told apart. Admin requests (`Bearer owner`) stand in for functions using admin REST, which bypass rules.

Not covered here: rules deployed to a real project with signed tokens, custom claims, payload size limits (beyond the phone text cap) and load. The phone text cap (2,000) uses `.length`, which counts UTF-16 code units (confirmed on a real RTDB, V-55), so an emoji counts as 2; the emulator checks pin that.

Only admin REST may set `meta/status` to `archived`; the rules refuse it from every client.
