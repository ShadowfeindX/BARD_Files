# The bard app

`apps/bard` is the GM and player app. This page covers the D demo slice: one device with all panels on screen, hosting over the LAN, and joining a LAN host as a player.

## Layout

| Folder | Holds |
|---|---|
| `lib/data/models.dart` | Plain display data: `AgentSheet`, `ActionRequestItem`, `ReviewItem`, `LogEntry` (`TextEntry`, `RollEntry`), skill and difficulty options |
| `lib/data/services/episode_service.dart` | The interface view models use. Reads are `signals_flutter` signals already filtered for one perspective; commands return `Future<void>` |
| `lib/data/services/session_episode_service.dart` | The host's service: an `EpisodeHost` over the shipped pack, in memory for one-device play or over the sembast store when hosting. Logs are built per perspective from the stored events and text-log variants (`deliveryFor`, `projectFor`) |
| `lib/data/services/participant_episode_service.dart` | A joined player's service: an `EpisodeParticipant` kept connected by a `Reconnector`; narrates the player's log from the entries it receives |
| `lib/data/services/episode_projection.dart` | Display data shared by both services: agent sheets, roll breakdowns, phone threads |
| `lib/data/lan_access.dart` | Who may join a LAN host and what a player may send (`LanVerifier`, `LanAdmission`, `lanAuthorizer`) |
| `lib/data/report_saver.dart` | `ReportSaver`: builds a report bundle and writes it to the reports folder |
| `test/support/fake_episode_service.dart` | Test-only in-memory stand-in with scripted dice, used by widget tests of the UI alone. Its fixture arithmetic exists only there |
| `lib/data/protocol_engine_codec.dart` | `EngineCodec` over the `protocol` codecs. State snapshots are not decoded yet |
| `lib/data/pack_assets.dart` | Reads the generated pack from the asset bundle |
| `lib/ui/console`, `dossier`, `table`, `home` | GM console, player dossier, table panel, and the home screen that shows them side by side; `home/lan_dialogs.dart` holds the consent, join and report dialogs |
| `lib/data/appearance_repository.dart` | `AppearanceRepository`: where the player's theme and variant are kept (client-side only). `LocalAppearanceRepository` keeps them in `settings.db`; the in-memory version, for tests and a machine without a local folder, holds them for the life of the process |
| `lib/app/` | `composition.dart` (the one place services are built: `inProcess`, `host`, `join`) and `routes.dart` (`/` the home screen; `/gm`, `/player/:agentId`, `/table` for a second window) |

## Rules

- View models forward intents and never compute outcomes; every number shown comes from the engine through the service.
- A held consequence (the GM review gate) appears only in the GM's review tray. The player's log gets the line after the GM confirms, without the `overriddenFrom` detail.
- GM notes are kept in the service only: the engine has no GM-note event yet, so they are not stored or replayed.
- The two demo agents, their score spread and skills are demo data created through `CreateAgent`; the creation limits come from the pack.

## Running

```bash
bash tool/build_pack.sh        # the pack is generated, not committed
cd apps/bard && flutter run -d linux   # or -d windows
cd apps/bard && flutter test           # includes the flow tests on a real host
```

## Look and appearance

The app shell is themed fixed panels on the one-device layout. `main.dart` loads a `ThemeController` (ui_kit) from the built-in themes and hands `controller.themeData` to `MaterialApp`; `BardApp` keeps `controller.osBrightness` current from the platform so System follows the OS. The controller outlives a new episode. **Appearance** in the app bar opens the theme and variant drop-down; the setting is saved through `AppearanceRepository` into `settings.db`, so it survives a restart. When the local data folder cannot be opened the app still runs, with the setting kept until exit. Windows are `ShellWindow`; the player's dossier shows a `RecordCard` (attributes, vitals, conditions) under the action request.

- **Conditions.** The console's **Conditions** window picks an agent and a pack condition (`EpisodeService.conditions`) and sends `ApplyCondition`; the result waits in the review tray like a Sanity loss and the player sees it after the Handler confirms. Chips under the picker clear a condition the agent has (`ClearCondition`, direct). The record card lists the agent's conditions.
- **Whisper.** A stat-gated whisper the player receives stays a log line and also raises a **Whisper** alert at the top of the dossier, outside the phone, until dismissed (`TextEntry.whisper`, `DossierViewModel.whisper`).
- **Review.** While a consequence waits for the Handler, the player's view shows nothing.
- **NPC notes slot.** `ConsoleView(npcNotes: ...)` shows a widget after the whisper window. `NpcNotesPanel` (`lib/ui/console/npc_notes_panel.dart`, state in `NpcNotesViewModel`) plugs in there: an NPC picker, then free-text notes, pinned details and prepared messages kept in `backend`'s `NpcNotesStore` on the Handler's machine. Notes are Handler-only and are never events. A prepared message's send button appears only when the view model has a `SendAsNpc(npcId, toAlias, text)`, which the host composition wires to `SendPhoneMessage(from: entity, to: alias, ...)` (the engine allows NPC to alias messages only, so the panel has a "Send to" picker over the episode's aliases and the NPC must exist as an entity with no owner alias, which the composition arranges before the first send); without one the panel edits notes only. The host composition opens the store, supplies the pack's NPC list and decides whether notes join a report bundle.
- **Placeholder labels.** The record card's section labels (Attributes, Vitals, Conditions) are generic. The table label of the design's record card (DEC-24) is not used and no other field is shown until D decides the record's content.

## New episode

`New episode` (app bar) closes the active host, opens an empty one from the shipped pack, rebuilds the router so it restarts at `/`, and leaves the GM to add agents. One host is active at a time. The first launch still seeds two demo agents. While hosting, `New episode` starts a fresh, empty hosted episode under a new id; the first time this machine hosts, the episode gets the two demo agents.

## Local data

`LocalData` (`backend`) opens this machine's files once at start-up, in one folder per user account found from the process environment, with no plugin:

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\BARD` (or `%USERPROFILE%\AppData\Roaming\BARD`) |
| Linux | `$XDG_DATA_HOME/bard`, or `~/.local/share/bard` when that is unset or relative |

Inside it:

| File | Holds |
|---|---|
| `settings.db` | `AppSettingsStore` (appearance, this machine's agent id for joining, the last hosted episode with its join code and port) and `HostSettingsStore` (snapshot interval) |
| `notes.db` | `NpcNotesStore` |
| `episodes/<id>.db`, `episodes/<id>.diagnostic.jsonl` | Each hosted episode's sembast store and diagnostic log |
| `joined/joined-<time>.diagnostic.jsonl` | The diagnostic log of each join as a player |
| `reports/bard-report-<id>-<time>/` | Saved report bundles |

To start over on a machine, quit the app and delete the folder.

## Play over the LAN

The app bar offers **Host on LAN** and **Join on LAN** in one-device play, and **Stop hosting** or **Leave** once networked. Each shows the log-collection notice first (`consentText`, PLACEHOLDER wording); declining changes nothing. `BardApp` swaps the composition: a networked one is closed before the next opens, so the port is free. If the next one fails to open, the app falls back to one-device play and says why.

- **Hosting.** `Composition.host` reopens the episode this machine hosted last (`AppSettingsStore.lastHostedEpisode`), so a host that was killed resumes from its store. It listens on every IPv4 interface, with the saved join code and, when free, the saved port, so players already in reconnect by themselves. The console shows a line with this machine's addresses, the port, the join code and the agent codes (each agent's alias id).
- **Joining.** The player types the host address (`host:port`), the join code and their agent code. `LanVerifier` takes the hello's agent and alias (the code was checked before the link opened) and never accepts the GM's id; `LanAdmission` admits a known agent code and keeps it for the first machine that uses it until the host stops. Players may send `RequestAction` and `SendPhoneMessage` as their own alias (`lanAuthorizer`). The joined screen shows only that player's dossier and a status line (connecting, joined, reconnecting, refused).
- **What a player may send.** `LanAuthorizer` adds to the default rules that a `RequestAction` names the entity the player's own alias owns.
- **The player's log.** The host sends events, never text, so `ParticipantEpisodeService` narrates each full entry with the engine's `Narrator` (the player line) and shows `EpisodeProjection.redactedLine` for a redacted one.
- **Tests.** `test/lan_play_test.dart` runs host and players over loopback sockets with the store on disk: join, a request and roll, phone both ways, a prepared NPC message, refusals (wrong code, unknown agent, taken agent), a killed host that resumes on the same port while the player resyncs, and reports. It runs without the widget binding, whose mock `HttpClient` would stop the LAN client, so it reads the pack from the generated files.

## Where the NPC notes panel is placed

`buildNpcNotes` in `routes.dart` builds the panel's view model next to the console's, and places `NpcNotesPanel` in the console's slot on `/` and `/gm`. It uses the store `Composition.local!.notes` (through `NpcNotesService`), the campaign `demoCampaignId`, the pack's NPCs as `NpcOption`s, the episode's agents as the "Send to" aliases, and `SessionEpisodeService.sendAsNpc(npcId, toAlias, text)` as `SendAsNpc`. The panel shows in one-device play and while hosting, whenever the local folder is open; a joined machine and a machine without local data have no panel (`Composition.hasNpcNotes`). One model serves both routes, so open the panel in one window at a time: a second window's text box does not refresh while it shows the same NPC.

## Reports

**Save a report** (app bar, when the local folder is open) writes a report bundle into `reports/` and shows the folder to send by hand. On the Handler's machine the dialog has an **Include notes** tick, off by default, that adds the NPC notes of `demoCampaignId`. A joined player keeps no store, so its report has an empty `game-log.jsonl` and instead `received-entries.jsonl`: every entry the host sent it, as on the wire (its own view of the game log). `appVersion` in `lib/data/report_saver.dart` is set by hand and is raised with the pubspec version at each release.

## Adding agents

`Add agent` in the console opens a dialog with the pack's creation limits (`EpisodeService.creationLimits`). The UI sends the scores through `CreateAgent` and shows the engine's refusal text; it checks only that each score is a whole number and leaves every rule to the engine. Note the engine currently checks only the per-attribute range, not the total points.

## Broadcast and phone

The console's **Stat-gated whisper** window builds a `Compare(op, Attr(key), Const(n))` condition from the attribute, comparison and value the GM picks (`BroadcastOp` mirrors the engine's `CompareOp`). **Preview** calls `engine.broadcastPreview` and lists each agent, whether they qualify and the score it read; it sends nothing. **Send** submits `BroadcastToQualifying`, so the engine decides again at send time. Only qualifying players get the line; the GM log names the recipients.

Phones use the ui_kit `PhonePanel`. Thread ids name the counterpart: `gm` for the Handler, `alias:<id>` for an agent's alias. The Handler's phone has one thread per agent (messages between the Handler and that alias); messages between two agents show in the GM log, not in the Handler's phone. A player's phone has the Handler and every other agent, built from the events that player may see. A thread with an NPC is `npc:<entity>`. `sendAsNpc` brings a pack NPC into the episode on its first message as a GM-only agent with no owner, the template's name and the pack's minimum in every attribute (PLACEHOLDER scores), and reuses it by name after that, so two NPCs with the same name share one entity. Because that identity is GM-only, a player's thread with the NPC is titled `Unknown number`.

## Demo data to replace

`SessionEpisodeService` seeds two agents with a score spread and `proficient` skills, and uses the fixed `demoSeed`, so every launch rolls the same dice. These are demo values, not rules; a real new-episode flow and a per-episode seed replace them. The minimum scores `sendAsNpc` gives an NPC are PLACEHOLDER too, until the engine introduces NPCs from their template.
