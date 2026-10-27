import 'dart:convert';

String canonicalJson(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map) {
      return {for (final k in v.keys.map((e) => e.toString()).toList()..sort()) k: normalize(v[k])};
    }
    if (v is List) return v.map(normalize).toList();
    return v;
  }
  return jsonEncode(normalize(value));
}

/// Three-way merge; a missing row means deletion. No silent last-writer-wins.
Map<String, String> mergeSync(Map<String, String> base,
    Map<String, String> local, Map<String, String> remote) {
  final result = <String, String>{};
  for (final key in {...base.keys, ...local.keys, ...remote.keys}) {
    final b = base[key], l = local[key], r = remote[key];
    if (l != b && r != b && l != r) {
      throw StateError('同步冲突：$key 在本地与飞书均有修改，已停止覆盖。请备份后核对');
    }
    final value = l != b ? l : r;
    if (value != null) result[key] = value;
  }
  return result;
}
