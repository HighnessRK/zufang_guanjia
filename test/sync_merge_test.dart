import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/sync_merge.dart';

void main() {
  test('云端更新不上传本地修改，后续双向同步仍能上传', () {
    final base = {'local': 'old', 'cloud': 'old'};
    final local = {'local': 'edited', 'cloud': 'old'};
    final remote = {'local': 'old', 'cloud': 'updated', 'new': 'from-cloud'};
    final pull = planSync(base, local, remote, pullOnly: true);
    expect(pull.writes, isEmpty);
    expect(pull.values,
        {'local': 'edited', 'cloud': 'updated', 'new': 'from-cloud'});
    expect(pull.baseline, remote);
    final sync = planSync(pull.baseline, pull.values, remote);
    expect(sync.writes, {'local'});
    expect(sync.values['local'], 'edited');
  });
  test('云端删除能下载；本地与云端冲突时拉取也停止', () {
    expect(
        planSync({'room': 'old'}, {'room': 'old'}, {}, pullOnly: true).values,
        isEmpty);
    expect(
        () => planSync({'room': 'old'}, {'room': 'local'}, {'room': 'cloud'},
            pullOnly: true),
        throwsStateError);
  });
  test('canonical JSON ignores key insertion order', () {
    expect(canonicalJson({'b': 2, 'a': 1}), canonicalJson({'a': 1, 'b': 2}));
  });
  test('local and remote independent changes merge', () {
    expect(
        mergeSync(
            {'a': '1', 'b': '1'}, {'a': '2', 'b': '1'}, {'a': '1', 'b': '3'}),
        {'a': '2', 'b': '3'});
  });
  test('same-row conflict never silently overwrites', () {
    expect(
        () => mergeSync({'a': '1'}, {'a': '2'}, {'a': '3'}), throwsStateError);
  });
  test('deletions propagate but deletion against modification conflicts', () {
    expect(mergeSync({'a': '1'}, {}, {'a': '1'}), isEmpty);
    expect(() => mergeSync({'a': '1'}, {}, {'a': '2'}), throwsStateError);
  });
}
