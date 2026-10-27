import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/update_service.dart';

/// 解析 Release 说明正文为条目列表 —— 覆盖 v1.1.4 乱码修复的各场景。
void main() {
  test('描述性新增标题和带后缀分组保留标签及字段下划线', () {
    final notes = UpdateService.parseUpdateNotes('## 飞书多维表格同步\n- 使用 rental_key / rental_json\n## 修复问题\n- 输入框\n## 优化体验\n- 报表');
    expect(notes.map((e) => e.type), ['新增', '修复', '优化']);
    expect(notes.first.text, contains('rental_key / rental_json'));
  });
  List<UpdateNoteEntry> parse(String s) => UpdateService.parseUpdateNotes(s);

  test('场景1：v1.1.4 之前的乱码（markdown 强调 + 全角引号 + 噪声行）', () {
    const String raw = '''
### 新增
- **电子收据**：选房选账期即生成水电费收据图片，支持保存相册与转发微信，历史收据可查看/重生成/删除
- **租金报表**：按开始-截止日期汇总房租/水费/电费，预设本月/近3月/近6月/近1年，分类型列出应收/实收/欠费

### 优化
- 抄表整层按钮顺序改为 AI拍电表/录电表/录水表（电类相邻），文字完整显示
- 收电日期默认跟随收水日期，新增"独立设置"开关
- 更新日志条目精简，本次版本默认展开、历史版本折叠

### 修复
- 配套与资产计数器数值与"0 = 无"灰提示重叠
- 收据用量为 0 时不再显示矛盾的"0 吨 × 单价"乘式

版本 1.1.3+11
''';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 8);
    expect(out[0].type, '新增');
    expect(out[0].text, '电子收据：选房选账期即生成水电费收据图片，支持保存相册与转发微信，历史收据可查看/重生成/删除');
    expect(out[0].text.contains('**'), false, reason: '强调符必须被剥掉');
    expect(out[0].text.contains('“'), false, reason: '全角引号必须被换成半角');
    expect(out[3].type, '优化');
    expect(out[6].type, '修复');
    expect(out[7].text, '版本 1.1.3+11');
  });

  test('场景2：无列表符号的纯文本行', () {
    const String raw = '修复：更新弹窗内容是乱码\n优化：下载进度条';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 2);
    expect(out[0].type, '修复');
    expect(out[0].text, '更新弹窗内容是乱码');
    expect(out[1].type, '优化');
  });

  test('场景3：数字序号列表', () {
    const String raw = '1. 新增 A\n2、修复 B\n3）优化 C';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 3);
    expect(out[0].text, 'A');
    expect(out[1].type, '修复');
  });

  test('场景4：噪声行（.apk / 下载 / Android 版本）不显示', () {
    const String raw = '''
- 修复 A
- 附件：zufang-guanjia-v1.1.4.apk
- 下载地址：https://example.com
- 适用 Android 7.0 及以上
- 优化 B
''';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 2);
    expect(out[0].text, 'A');
    expect(out[1].text, 'B');
  });

  test('场景5：`###` 非分组标题（更新内容 / 下载）跳过，不产生条目', () {
    const String raw = '## 更新内容\n### 新增\n- A\n### 下载\n- B';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 2);
    expect(out[0].type, '新增');
    expect(out[1].text, 'B');
  });

  test('场景6：零宽字符 / 反引号包裹被清洗', () {
    const String raw = '- 修复 ``零宽​字符`` 与 `代码`';
    final List<UpdateNoteEntry> out = parse(raw);
    expect(out.length, 1);
    expect(out[0].text, '零宽字符 与 代码');
  });

  test('formatSize：字节转可读大小', () {
    expect(UpdateService.formatSize(0), '');
    expect(UpdateService.formatSize(-1), '');
    expect(UpdateService.formatSize(1024), '1 KB');
    expect(UpdateService.formatSize(1024 * 1024), '1.0 MB');
    expect(UpdateService.formatSize(24459940), '23.3 MB');
  });
}
