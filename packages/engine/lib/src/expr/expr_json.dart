/// The JSON form of [Expr] trees, as packs write them.
///
/// ```json
/// {"type": "const", "value": 10}
/// {"type": "attr", "key": "END"}
/// {"type": "var", "key": "newScore"}
/// {"type": "dice", "count": 1, "sides": 6, "explode": true}
/// {"type": "sum", "terms": [ ... ]}
/// {"type": "keepHighest", "pool": [ ... ], "keep": 1}
/// {"type": "op", "op": "mul", "args": [ ... ]}
/// ```
///
/// `op` is one of `add sub mul div min max floor`. In a dice node `explode`
/// may be `true`, `false`, `null` or absent; `null` and absent both mean "not
/// ruled". Unknown keys are errors (02 §Loading and validation), so authoring
/// annotations must be stripped first.
library;

import 'evaluate.dart' show normalizeNumber;
import 'expr.dart';
import 'vars.dart';

/// Decodes an expression from its JSON form.
///
/// [allowedVars] lists the `var` keys this placement may read; any other key
/// is an error, because each key is approved for one placement only
/// (see `VarKeys`). [path] names the location in error messages, for example
/// `derived.json: derived[0].formula`.
///
/// Throws an [ArgumentError] if [allowedVars] names a key outside
/// `VarKeys.all`. Throws a [FormatException] describing the first problem found.
Expr decodeExpr(
  Object? json, {
  Set<String> allowedVars = const {},
  String path = r'$',
}) {
  final unknown = allowedVars.difference(VarKeys.all);
  if (unknown.isNotEmpty) {
    throw ArgumentError.value(
      allowedVars,
      'allowedVars',
      'contains keys that are not approved: ${unknown.join(', ')}',
    );
  }
  return _Decoder(allowedVars).decode(json, path);
}

/// Encodes [expr] in the JSON form [decodeExpr] reads.
///
/// A dice node with `explode == null` is written with `"explode": null`, as
/// the provisional pack does.
Map<String, Object?> encodeExpr(Expr expr) => switch (expr) {
  Const(:final value) => {'type': 'const', 'value': normalizeNumber(value)},
  Attr(:final key) => {'type': 'attr', 'key': key},
  Var(:final key) => {'type': 'var', 'key': key},
  Dice(:final count, :final sides, :final explode) => {
    'type': 'dice',
    'count': count,
    'sides': sides,
    'explode': explode,
  },
  Sum(:final terms) => {
    'type': 'sum',
    'terms': [for (final t in terms) encodeExpr(t)],
  },
  KeepHighest(:final pool, :final keep) => {
    'type': 'keepHighest',
    'pool': [for (final t in pool) encodeExpr(t)],
    'keep': keep,
  },
  Op(:final op, :final args) => {
    'type': 'op',
    'op': op.name,
    'args': [for (final t in args) encodeExpr(t)],
  },
};

final class _Decoder {
  _Decoder(this.allowedVars);

  final Set<String> allowedVars;

  Expr decode(Object? json, String path) {
    if (json is! Map<String, Object?>) {
      throw FormatException('$path: expected an expression object.');
    }
    final type = json['type'];
    return switch (type) {
      'const' => _const(json, path),
      'attr' => _wrap(
        path,
        () => Attr(_string(json, 'key', path, {'type', 'key'})),
      ),
      'var' => _var(json, path),
      'dice' => _dice(json, path),
      'sum' => Sum(_list(json, 'terms', path, {'type', 'terms'})),
      'keepHighest' => _keepHighest(json, path),
      'op' => _op(json, path),
      _ => throw FormatException('$path: unknown expression type "$type".'),
    };
  }

  Const _const(Map<String, Object?> json, String path) {
    _checkKeys(json, {'type', 'value'}, path);
    final value = json['value'];
    if (value is! num) {
      throw FormatException('$path.value: expected a number.');
    }
    return _wrap(path, () => Const(normalizeNumber(value)));
  }

  Var _var(Map<String, Object?> json, String path) {
    final key = _string(json, 'key', path, {'type', 'key'});
    if (!allowedVars.contains(key)) {
      final allowed = allowedVars.isEmpty
          ? 'no var keys are allowed here'
          : 'allowed here: ${allowedVars.join(', ')}';
      throw FormatException('$path.key: var "$key" is not allowed ($allowed).');
    }
    return Var(key);
  }

  Dice _dice(Map<String, Object?> json, String path) {
    _checkKeys(json, {'type', 'count', 'sides', 'explode'}, path);
    final explode = json['explode'];
    if (explode != null && explode is! bool) {
      throw FormatException('$path.explode: expected true, false or null.');
    }
    return _wrap(
      path,
      () => Dice(
        count: _int(json, 'count', path),
        sides: _int(json, 'sides', path),
        explode: explode as bool?,
      ),
    );
  }

  KeepHighest _keepHighest(Map<String, Object?> json, String path) {
    final pool = _list(json, 'pool', path, {'type', 'pool', 'keep'});
    return _wrap(path, () => KeepHighest(pool, _int(json, 'keep', path)));
  }

  Op _op(Map<String, Object?> json, String path) {
    final args = _list(json, 'args', path, {'type', 'op', 'args'});
    final name = json['op'];
    final op = OpKind.values.where((k) => k.name == name).firstOrNull;
    if (op == null) {
      final names = OpKind.values.map((k) => k.name).join(', ');
      throw FormatException('$path.op: unknown operator "$name" ($names).');
    }
    return _wrap(path, () => Op(op, args));
  }

  void _checkKeys(Map<String, Object?> json, Set<String> allowed, String path) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('$path: unknown key "$key".');
      }
    }
  }

  String _string(
    Map<String, Object?> json,
    String key,
    String path,
    Set<String> allowed,
  ) {
    _checkKeys(json, allowed, path);
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$path.$key: expected a non-empty string.');
    }
    return value;
  }

  int _int(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    // A JSON number like 2.0 decodes as a double on the VM and as an int on
    // the web; accept whole doubles so both platforms agree.
    if (value is num &&
        value.isFinite &&
        value == value.truncate() &&
        value.abs() <= maxSafeInteger) {
      return value.toInt();
    }
    throw FormatException('$path.$key: expected a whole number.');
  }

  List<Expr> _list(
    Map<String, Object?> json,
    String key,
    String path,
    Set<String> allowed,
  ) {
    _checkKeys(json, allowed, path);
    final value = json[key];
    if (value is! List<Object?>) {
      throw FormatException('$path.$key: expected a list of expressions.');
    }
    return [
      for (var i = 0; i < value.length; i++) decode(value[i], '$path.$key[$i]'),
    ];
  }

  /// Turns a constructor's [ArgumentError] into a [FormatException] at [path].
  T _wrap<T>(String path, T Function() build) {
    try {
      return build();
    } on ArgumentError catch (e) {
      throw FormatException('$path: ${e.message}');
    }
  }
}
