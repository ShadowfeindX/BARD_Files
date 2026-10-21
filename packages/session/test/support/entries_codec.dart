import 'package:protocol/protocol.dart';

import 'test_codec.dart';

/// Wraps [TestCodec] for tests that only need an [EngineCodec] value.
final class TestCodecForEntries {
  const TestCodecForEntries();

  EngineCodec get codec => const TestCodec();
}
