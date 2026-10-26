/// 电话号码 / 身份证号的实时校验与派生信息（位数格子条、省份）。
///
/// 【v1.1.2 修复】1.1.1 的实现把校验码表写成
/// `check = [1,0,9,8,7,6,5,4,3,2]`——只有 10 项、漏了 `X` 那一档，导致
/// ① 余数为 10 时 `check[10]` 越界抛 RangeError，而这段逻辑跑在
///   `build()` 里 → 整个编辑房间页被 ErrorWidget 灰屏盖住（真机必现）；
/// ② 表整体错位一位，标准身份证会被判「不符」。
///
/// 这里统一成标准 ISO 7064:1983 MOD 11-2 码表（11 项），并加了三道
/// 硬性保护：正则先把关、下标越界直接返回 false，任何输入都不会抛。
class IdValidator {
  IdValidator._();

  /// 11 位、1 开头
  static final RegExp _phoneRe = RegExp(r'^1\d{10}$');

  /// 只要已经输进来的前缀没违背 1 开头 / 11 位，就还没输错方向
  static final RegExp _phoneProgressRe = RegExp(r'^1?\d{0,10}$');

  /// 18 位，末位可为 X/x
  static final RegExp _idRe = RegExp(r'^\d{17}[\dXx]$');

  static final RegExp _idProgressRe = RegExp(r'^\d{0,17}[\dXx]?$');

  /// ISO 7064:1983 MOD 11-2 校验码（余数 0..10 → 1,0,X,9,8,7,6,5,4,3,2）
  static const List<String> _idCheck = <String>[
    '1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2',
  ];

  /// 加权因子（身份证前 17 位）
  static const List<int> _idWeights = <int>[
    7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2,
  ];

  /// 身份证前 2 位 → 省级简称（用于格子条下方提示，如「浙江」）
  static const Map<String, String> _provinces = <String, String>{
    '11': '北京', '12': '天津', '13': '河北', '14': '山西', '15': '内蒙古',
    '21': '辽宁', '22': '吉林', '23': '黑龙江',
    '31': '上海', '32': '江苏', '33': '浙江', '34': '安徽', '35': '福建',
    '36': '江西', '37': '山东',
    '41': '河南', '42': '湖北', '43': '湖南', '44': '广东', '45': '广西',
    '46': '海南',
    '50': '重庆', '51': '四川', '52': '贵州', '53': '云南', '54': '西藏',
    '61': '陕西', '62': '甘肃', '63': '青海', '64': '宁夏', '65': '新疆',
    '71': '台湾', '81': '香港', '82': '澳门',
  };

  /// 电话号码是否完整合规（11 位、1 开头）
  static bool phoneOk(String v) => _phoneRe.hasMatch(v.trim());

  /// 已输入的前缀是否仍可能拼成合法号码（格子条配色用）
  static bool phoneProgress(String v) =>
      _phoneProgressRe.hasMatch(v.trim());

  /// 身份证是否完整合规（18 位 + 校验位）
  static bool idOk(String v) {
    final String t = v.trim();
    if (!_idRe.hasMatch(t)) return false;
    int sum = 0;
    for (int i = 0; i < 17 && i < _idWeights.length; i++) {
      sum += (t.codeUnitAt(i) - 48) * _idWeights[i];
    }
    final int r = sum % 11;
    // 码表长度 11，余数恒在范围内；仍兜底判断，杜绝越界进 build
    if (r < 0 || r >= _idCheck.length) return false;
    return t[17].toUpperCase() == _idCheck[r];
  }

  /// 已输入的前缀是否仍可能拼成合法身份证
  static bool idProgress(String v) => _idProgressRe.hasMatch(v.trim());

  /// 身份证前 2 位对应的省份简称；前缀不足 / 不是已知行政区划则返回 null
  static String? idProvince(String v) {
    final String t = v.trim();
    if (t.length < 2) return null;
    return _provinces[t.substring(0, 2)];
  }
}
