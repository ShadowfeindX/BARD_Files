import 'package:session/session.dart';
import 'package:test/test.dart';

DiagnosticLog newLog() => DiagnosticLog(
  clock: FakeClock(),
  redactor: Redactor(salt: 's'),
);

void main() {
  group('Redactor', () {
    final r = Redactor(salt: 's');

    test('hides text, notes, names and codes', () {
      final out = r.redactMap({
        'text': 'meet me at the pier',
        'notes': 'the butler did it',
        'joinCode': '1234',
        'authProof': 'secret',
        'name': 'Vale',
        'seq': 4,
      });
      expect(out['text'], Redactor.hidden);
      expect(out['notes'], Redactor.hidden);
      expect(out['joinCode'], Redactor.hidden);
      expect(out['authProof'], Redactor.hidden);
      expect(out['name'], Redactor.hidden);
      expect(out['seq'], 4);
    });

    test('pseudonyms are stable, differ per value and per salt', () {
      final a = r.redact('agentId', 'ann');
      expect(a, r.redact('agentId', 'ann'));
      expect(a, isNot(r.redact('agentId', 'bob')));
      expect(a, isNot('ann'));
      expect(a, startsWith('agent-'));
      expect(Redactor(salt: 'other').redact('agentId', 'ann'), isNot(a));
    });

    test('a request id does not reveal the agent id inside it', () {
      final out = r.redact('requestId', 'ann-xyz-1') as String;
      expect(out, isNot(contains('ann')));
    });

    test('long strings are cut; objects and nested values are not kept', () {
      expect(
        (r.redact('type', 'x' * 200) as String).length,
        Redactor.maxStringLength + 1,
      );
      expect(r.redact('seqs', [1, 2]), [1, 2]);
      expect(r.redact('x', Object()), startsWith('[unsupported'));
      expect(r.redact('notes', null), isNull);
    });
  });

  group('DiagnosticLog', () {
    test('keeps every entry in order and numbers them from 1', () {
      final log = newLog();
      for (var i = 0; i < 1000; i++) {
        log.record(DiagnosticCategory.network, 'k', {'seq': i});
      }
      expect(log.entries, hasLength(1000));
      expect(log.entries.first.index, 1);
      expect(log.entries.last.index, 1000);
    });

    test('redacts before keeping and before the sink hears it', () {
      final log = newLog();
      final heard = <DiagnosticEntry>[];
      log.addSink(_Sink(heard.add));
      log.record(DiagnosticCategory.request, 'k', {'text': 'secret'});
      expect(log.entries.single.fields['text'], Redactor.hidden);
      expect(heard.single.toJsonLine(), isNot(contains('secret')));
    });

    test('where filters by category', () {
      final log = newLog()
        ..record(DiagnosticCategory.network, 'a')
        ..record(DiagnosticCategory.error, 'b')
        ..record(DiagnosticCategory.network, 'c');
      expect(log.where({DiagnosticCategory.network}).map((e) => e.kind), [
        'a',
        'c',
      ]);
    });
  });
}

final class _Sink implements DiagnosticSink {
  _Sink(this.onWrite);
  final void Function(DiagnosticEntry) onWrite;
  @override
  void write(DiagnosticEntry entry) => onWrite(entry);
}
