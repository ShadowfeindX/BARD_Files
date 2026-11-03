# R-A2 explained: which level owns the live game record?

Short version: the question is only about **naming and where the data lives**. Nothing about how the game plays changes.

## Two meanings of the word "operation"

Before D's meeting, "operation" meant the **whole campaign**, and the code (`packages/engine`, `packages/session`: `OperationSystem`, `OperationState`, `OperationHost`) was built on that. In practice the code's "operation" is the **one live game that is running right now**: one event log, one live RTDB tree, one local sembast file, one host.

D has now defined four levels, and in D's words an *operation* is a story arc made of several missions. So the code's "operation" does not match D's "operation" any more. The live thing the code manages is closest to D's **session**.

## D's four levels

```
CAMPAIGN   one GM, one group of players, runs for months
 |         holds: base settings, pack version pin, players, Handler personas,
 |                phone contact list, join links
 |
 +-- OPERATION 1  (story arc)      -- operations happen one after another -->  OPERATION 2 ...
      |           holds: phone box messages
      |
      +-- MISSION A (scenario) ----+   missions may run in parallel
      +-- MISSION B (scenario) ----+   (settings per mission, copied from base)
           |
           +-- SESSION 1 --> SESSION 2 --> SESSION 3 ...   sessions are one after another
                 |
                 +-- event log, live state, dice results  <- THIS is what the code calls "operation"
```

## What "owns the log" means

Whatever level owns the log is the unit that has:

1. one **event log** (every roll, message, change),
2. one **live tree** in the online database while people are playing,
3. one **local save file** on the GM's machine,
4. one **host** (the GM's running app).

## The options

| | A. Session owns it (my recommendation) | B. Mission owns it | C. Operation owns it (keep current meaning) |
|---|---|---|---|
| What the log covers | one sitting | all sittings of a mission | all missions of an arc |
| Fits D's "archive log and snapshot at every session end, keep until mission ends, allow rollback" | **Yes, exactly** | No: rollback to a session would mean cutting a long log in the middle | No |
| Parallel missions | Fine, each is its own log | Fine | Awkward: two missions write to one log |
| Rename work | Rename `Operation` to `Session` in code and spec | Rename to `Mission` | None, but the code's "operation" then disagrees with D's word |
| Character carry-over | Final snapshot of a session carries forward | Snapshot at mission end | Snapshot at operation end |

Why A fits: D said that when a session ends, its log is archived and a **snapshot** is kept ready to start the next session, and that Handlers can roll back to an earlier session. That is how our engine already behaves per live game: log plus a head snapshot. So the session is the natural unit, and the higher levels (mission, operation, campaign) are just labels and shared records above it.

## What would change under A

- Docs: one rename pass over the spec chapters (01 to 08 and 12): "operation" becomes "session" where it means live play.
- Code: one mechanical `refactor/` PR (`OperationState` to `SessionState`, and so on), no behaviour change, tests unchanged apart from names.
- Until then both words keep working in code; the docs already use D's four terms.
- Because you ruled R-A3 (see below), the archive keeps one record per session while the mission is open and prunes after completion.

## What I need from you

Tick one in the follow-up sheet (R-A2): Agree to A, pick B or C, or ask for more. You have left it as Later pending this explanation.
