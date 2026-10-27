import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/sync_merge.dart';

void main() {
  test('canonical JSON ignores key insertion order', () {
    expect(canonicalJson({'b': 2, 'a': 1}), canonicalJson({'a': 1, 'b': 2}));
  });
  test('local and remote independent changes merge', () {
    expect(mergeSync({'a': '1', 'b': '1'}, {'a': '2', 'b': '1'}, {'a': '1', 'b': '3'}),
        {'a': '2', 'b': '3'});
  });
  test('same-row conflict never silently overwrites', () {
    expect(() => mergeSync({'a': '1'}, {'a': '2'}, {'a': '3'}), throwsStateError);
  });
  test('deletions propagate but deletion against modification conflicts', () {
    expect(mergeSync({'a': '1'}, {}, {'a': '1'}), isEmpty);
    expect(() => mergeSync({'a': '1'}, {}, {'a': '2'}), throwsStateError);
  });
}
