// Kill-test writer (V-31): appends batches to episode `e` in the directory
// given as the first argument until it is killed. After each append it prints
// `DONE <seq>`, so the checker knows which batches were reported committed.
import 'dart:io';

import 'package:backend/backend.dart';
import 'package:sembast/sembast_io.dart';
import 'package:session/session.dart';

Future<void> main(List<String> args) async {
  final store = SembastEventStore.inDirectory(databaseFactoryIo, args[0]);
  var seq = (await store.headSnapshot('e'))?.seq ?? 0;
  while (true) {
    seq++;
    final time = DateTime.utc(2026);
    await store.append(
      'e',
      [
        StoredEvent(
          seq: seq,
          time: time,
          engineVersion: '1',
          event: {'pad': 'x' * 2000},
        ),
      ],
      [
        TextLogLine(seq: seq, time: time, variants: {'gm': 'line $seq'}),
      ],
      HeadSnapshot(seq: seq, state: {'pad': 'y' * 20000}, rngDrawCount: seq),
    );
    stdout.writeln('DONE $seq');
  }
}
