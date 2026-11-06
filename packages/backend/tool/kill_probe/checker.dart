// Kill-test checker (V-31): opens the episode left by a killed writer and
// checks it. Arguments: the directory and the last `DONE` seq the writer
// reported. Prints `OK ...` and exits 0, or prints `FAIL ...` and exits 1.
import 'dart:io';

import 'package:backend/backend.dart';
import 'package:sembast/sembast_io.dart';

Future<void> main(List<String> args) async {
  final reported = int.parse(args[1]);
  final store = SembastEventStore.inDirectory(databaseFactoryIo, args[0]);
  final events = await store.read('e').toList();
  final text = await store.readText('e').toList();
  final head = await store.headSnapshot('e');
  final problems = <String>[];
  if (events.length < reported) {
    problems.add('lost a reported commit: ${events.length} < $reported');
  }
  for (var i = 0; i < events.length; i++) {
    if (events[i].seq != i + 1) problems.add('gap at index $i');
  }
  if (text.length != events.length) problems.add('text/event count differ');
  if ((head?.seq ?? 0) != events.length) {
    problems.add('head ${head?.seq} != ${events.length} events');
  }
  await store.close();
  stdout.writeln(
    '${problems.isEmpty ? 'OK' : 'FAIL'} events=${events.length} '
    'reported=$reported ${problems.join('; ')}',
  );
  exitCode = problems.isEmpty ? 0 : 1;
}
