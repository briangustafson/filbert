import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import '../clock/clock.dart';

part 'id_generator.g.dart';

/// Generates record ids. Every record id is a UUIDv7 (engineering guidelines).
abstract interface class IdGenerator {
  String newId();
}

/// UUIDv7 ids whose timestamp comes from [Clock], so ids sort by creation
/// time across milliseconds.
class UuidV7IdGenerator implements IdGenerator {
  UuidV7IdGenerator(this._clock);

  final Clock _clock;
  static const _uuid = Uuid();

  @override
  String newId() =>
      _uuid.v7(config: V7Options(_clock.now().millisecondsSinceEpoch, null));
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidV7IdGenerator(ref.watch(clockProvider));
