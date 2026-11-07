// Host and players over real loopback sockets, with the episode on disk.
//
// No widget binding here on purpose: flutter_test's binding replaces
// HttpClient with a mock, which would stop the LAN client from connecting.
// So the pack is read from its generated files, not from the asset bundle.
// Needs `bash tool/build_pack.sh` first.
import 'dart:io';

import 'package:backend/backend.dart';
import 'package:bard/app/composition.dart';
import 'package:bard/data/models.dart';
import 'package:bard/data/services/episode_projection.dart';
import 'package:bard/data/services/participant_episode_service.dart';
import 'package:bard/data/services/session_episode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

Map<String, String> _packFiles() {
  final root = Directory(
    '../../packages/content_core/assets/generated/example-core',
  );
  return {
    for (final f in root.listSync(recursive: true).whereType<File>())
      f.path.substring(root.path.length + 1).replaceAll(r'\', '/'): f
          .readAsStringSync(),
  };
}

/// Waits until [check] holds, or fails after [limit].
Future<void> _until(
  bool Function() check, {
  Duration limit = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(limit);
  while (!check()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory dir;
  late LocalData hostData;
  late LocalData playerData;
  final packFiles = _packFiles();
  final opened = <Composition>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bard_lan');
    hostData = await LocalData.open(LocalDataPaths('${dir.path}/host'));
    playerData = await LocalData.open(LocalDataPaths('${dir.path}/player'));
  });

  tearDown(() async {
    for (final c in opened.reversed) {
      await c.dispose();
    }
    opened.clear();
    await hostData.close();
    await playerData.close();
    // A closed link may still log its last diagnostic line a moment later
    // (its sink recreates the file), so the folder is deleted with retries.
    for (var attempt = 0; ; attempt++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  Future<Composition> host({bool newEpisode = false, int port = 0}) async {
    final c = await Composition.host(
      packFiles,
      hostData,
      newEpisode: newEpisode,
      bindAddress: InternetAddress.loopbackIPv4,
      port: port,
    );
    opened.add(c);
    return c;
  }

  Future<Composition> join(
    Composition host,
    String alias, {
    LocalData? data,
    String? code,
  }) async {
    final c = await Composition.join(
      packFiles,
      data ?? playerData,
      info: LanJoinInfo(
        host: '127.0.0.1',
        port: host.hosting!.port,
        joinCode: code ?? host.hosting!.joinCode,
      ),
      aliasId: alias,
    );
    opened.add(c);
    return c;
  }

  ParticipantEpisodeService player(Composition c) =>
      c.episode as ParticipantEpisodeService;

  test(
    'a player joins, requests, and sees the roll and a phone message',
    () async {
      final h = await host(newEpisode: true);
      final gm = h.episode as SessionEpisodeService;
      final p = await join(h, 'vale');
      await _until(() => player(p).status.value == JoinStatus.joined);
      await _until(() => p.episode.agents.value.isNotEmpty);
      expect(p.episode.agents.value.map((a) => a.id), ['vale']);

      await p.episode.requestAction('vale', 'Search the desk');
      await _until(() => gm.requests.value.isNotEmpty);
      final request = gm.requests.value.single;
      await gm.resolveRequest(
        request.id,
        gm.skills.first.id,
        gm.difficulties.first.key,
      );
      await _until(
        () => p.episode.playerLog('vale').value.any((e) => e is RollEntry),
      );

      await gm.sendPhone(null, 'alias:vale', 'Meet me at the docks.');
      await _until(
        () => p.episode
            .playerPhone('vale')
            .value
            .first
            .messages
            .any((m) => m.text == 'Meet me at the docks.'),
      );
      await p.episode.sendPhone('vale', 'gm', 'On my way.');
      await _until(
        () => gm.gmPhone.value
            .firstWhere((t) => t.id == 'alias:vale')
            .messages
            .any((m) => m.text == 'On my way.'),
      );
    },
  );

  test('a prepared message reaches the player as the NPC', () async {
    final h = await host(newEpisode: true);
    final gm = h.episode as SessionEpisodeService;
    final p = await join(h, 'vale');
    await _until(() => player(p).status.value == JoinStatus.joined);
    final npc = gm.pack.npcs.first;
    expect(await gm.sendAsNpc(npc.id, 'vale', 'You were seen.'), isNull);
    expect(await gm.sendAsNpc(npc.id, 'vale', 'Twice.'), isNull);
    await _until(
      () => p.episode
          .playerPhone('vale')
          .value
          .any((t) => t.messages.length == 2),
    );
    final thread = p.episode
        .playerPhone('vale')
        .value
        .firstWhere((t) => t.messages.length == 2);
    // NPC identities are GM-only, so the player cannot read the name.
    expect(thread.title, EpisodeProjection.unknownNumber);
    expect(
      gm.gmLog.value.whereType<TextEntry>().any(
        (e) => e.text.contains(npc.name),
      ),
      isTrue,
    );
    expect(await gm.sendAsNpc('nobody', 'vale', 'x'), isNotNull);
  });

  test(
    'a wrong code, an unknown agent and a taken agent are refused',
    () async {
      final h = await host(newEpisode: true);
      final wrong = await join(h, 'vale', code: 'WRONG1');
      final unknown = await join(h, 'nobody');
      await _until(() => player(wrong).status.value == JoinStatus.refused);
      await _until(() => player(unknown).status.value == JoinStatus.refused);
      expect(player(wrong).refusal.value, contains('join code'));
      expect(player(unknown).refusal.value, contains('no agent'));

      final first = await join(h, 'quill');
      await _until(() => player(first).status.value == JoinStatus.joined);
      final otherData = await LocalData.open(
        LocalDataPaths('${dir.path}/other'),
      );
      addTearDown(otherData.close);
      final second = await join(h, 'quill', data: otherData);
      await _until(() => player(second).status.value == JoinStatus.refused);
      expect(player(second).refusal.value, contains('already joined'));
    },
  );

  test('a killed host resumes from its store and the player resyncs', () async {
    var h = await host(newEpisode: true);
    final port = h.hosting!.port;
    final p = await join(h, 'vale');
    await _until(() => player(p).status.value == JoinStatus.joined);
    final gm = h.episode as SessionEpisodeService;
    await gm.addAgent('Agent Rook', {
      for (final a in gm.creationLimits.attributes)
        a.key: gm.creationLimits.min,
    });
    final before = gm.lastSeq;
    final episodeId = gm.episodeId;

    await h.dispose();
    opened.remove(h);
    await _until(() => player(p).status.value == JoinStatus.reconnecting);

    h = await host();
    expect(h.hosting!.port, port, reason: 'the saved port is reused');
    final resumed = h.episode as SessionEpisodeService;
    expect(resumed.episodeId, episodeId);
    expect(resumed.lastSeq, before);
    expect(resumed.agents.value.map((a) => a.name), contains('Agent Rook'));

    await resumed.sendPhone(null, 'alias:vale', 'Back online.');
    await _until(
      () => player(p).status.value == JoinStatus.joined,
      limit: const Duration(seconds: 20),
    );
    await _until(
      () => p.episode
          .playerPhone('vale')
          .value
          .first
          .messages
          .any((m) => m.text == 'Back online.'),
    );
    expect(player(p).lastSeq, resumed.lastSeq);
  });

  test(
    'a report bundle holds the log, the health and, if ticked, the notes',
    () async {
      final h = await host(newEpisode: true);
      await hostData.notes.setText(demoCampaignId, 'mara', 'Lies.');
      final plain = Directory(await h.reports!.save());
      final names = plain
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, containsAll(['game-log.jsonl', 'store-health.json']));
      expect(names, isNot(contains('notes.json')));
      final withNotes = Directory(await h.reports!.save(includeNotes: true));
      expect(
        File('${withNotes.path}/notes.json').readAsStringSync(),
        contains('Lies.'),
      );
      expect(withNotes.path, startsWith(hostData.paths.reportsFolder));

      final p = await join(h, 'vale');
      expect(p.reports!.canIncludeNotes, isFalse);
      await _until(() => player(p).status.value == JoinStatus.joined);
      final playerReport = Directory(await p.reports!.save(includeNotes: true));
      expect(File('${playerReport.path}/notes.json').existsSync(), isFalse);
      expect(
        File('${playerReport.path}/network-trace.jsonl').readAsStringSync(),
        contains('hello.welcomed'),
      );
      final received = File('${playerReport.path}/received-entries.jsonl')
          .readAsLinesSync();
      expect(received, isNotEmpty);
      expect(received.first, contains('"seq":1'));
    },
  );

  test('a resumed host whose port is taken listens on another one', () async {
    var h = await host(newEpisode: true);
    final port = h.hosting!.port;
    final code = h.hosting!.joinCode;
    final id = (h.episode as SessionEpisodeService).episodeId;
    await h.dispose();
    opened.remove(h);
    final squatter = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    addTearDown(squatter.close);

    h = await host();
    expect(h.hosting!.port, isNot(port));
    expect(h.hosting!.joinCode, code);
    expect((h.episode as SessionEpisodeService).episodeId, id);
    expect(
      (await hostData.settings.lastHostedEpisode())?.port,
      h.hosting!.port,
    );
  });

  test('signals stay readable after the player leaves', () async {
    final h = await host(newEpisode: true);
    final p = await join(h, 'vale');
    await _until(() => player(p).status.value == JoinStatus.joined);
    await p.dispose();
    opened.remove(p);
    expect(player(p).status.value, JoinStatus.closed);
    expect(untracked(() => p.episode.agents.value).map((a) => a.id), ['vale']);
  });
}
