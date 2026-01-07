class StockDepletionItem {
  final String partnmCode;
  final String pcCode;
  final String partNo;
  final int stockQty;
  final double? minutesToZero;

  StockDepletionItem({
    required this.partnmCode,
    required this.pcCode,
    required this.partNo,
    required this.stockQty,
    required this.minutesToZero,
  });

  static String _normKey(String k) =>
      k.replaceAll('_', '').replaceAll('-', '').toLowerCase().trim();

  static String _asString(dynamic v) => (v ?? '').toString();

  static int _asInt(dynamic v) =>
      int.tryParse((v ?? 0).toString()) ?? 0;

  static double? _asDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  static dynamic _getByNorm(Map<String, dynamic> j, String wantNorm) {
    for (final entry in j.entries) {
      if (_normKey(entry.key) == wantNorm) return entry.value;
    }
    return null;
  }

  /// 어떤 형태로 와도 파싱
  factory StockDepletionItem.fromAny(dynamic raw) {
    if (raw is! Map) {
      return StockDepletionItem(
        partnmCode: '',
        pcCode: '',
        partNo: '',
        stockQty: 0,
        minutesToZero: null,
      );
    }

    final m = raw as Map;
    final j = <String, dynamic>{};
    for (final e in m.entries) {
      j[e.key.toString()] = e.value;
    }

    final partnm = _asString(_getByNorm(j, 'partnmcode'));
    final pcCode = _asString(_getByNorm(j, 'pccode'));
    final partNo = _asString(_getByNorm(j, 'partno'));
    final stockQty = _asInt(_getByNorm(j, 'stockqty'));
    final min = _asDouble(_getByNorm(j, 'minutestozero'));

    return StockDepletionItem(
      partnmCode: partnm,
      pcCode: pcCode,
      partNo: partNo,
      stockQty: stockQty,
      minutesToZero: min,
    );
  }
}


class StockDepletionResult {
  final String resultCode;
  final String resultMessage;
  final List<StockDepletionItem> items;
  StockDepletionResult({required this.resultCode, required this.resultMessage, required this.items});
}

class UpdateStockResult {
  final String resultCode;
  final String resultMessage;
  UpdateStockResult({required this.resultCode, required this.resultMessage});
}

class CurrentStockInfo {
  final String lineCode;
  final String partNo;
  final String partnmCode;
  final String partName;
  final String pcCode;
  final String? stationCode;
  final String workCode;
  final String workType;
  final String? seqIdx;
  final int stockQty;
  final DateTime? subtractionTime;
  final DateTime? additionTime;
  final String useFlag;

  CurrentStockInfo({
    required this.lineCode,
    required this.partNo,
    required this.partnmCode,
    required this.partName,
    required this.pcCode,
    required this.stationCode,
    required this.workCode,
    required this.workType,
    required this.seqIdx,
    required this.stockQty,
    required this.subtractionTime,
    required this.additionTime,
    required this.useFlag,
  });

  factory CurrentStockInfo.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      return DateTime.tryParse(s);
    }

    int i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;
    String s(dynamic v) => (v ?? '').toString();

    return CurrentStockInfo(
      lineCode: s(j['LINE_CODE'] ?? j['lineCode']),
      partNo: s(j['PART_NO'] ?? j['partNo']),
      partnmCode: s(j['PARTNM_CODE'] ?? j['partnmCode']),
      partName: s(j['PART_NAME'] ?? j['partName']),
      pcCode: s(j['PC_CODE'] ?? j['pcCode']),
      stationCode: (j['STATION_CODE'] ?? j['stationCode'])?.toString(),
      workCode: s(j['WORK_CODE'] ?? j['workCode']),
      workType: s(j['WORK_TYPE'] ?? j['workType']),
      seqIdx: (j['SEQ_IDX'] ?? j['seqIdx'])?.toString(),
      stockQty: i(j['STOCK_QTY'] ?? j['stockQty']),
      subtractionTime: dt(j['SUBTRACTION_TIME'] ?? j['subtractionTime']),
      additionTime: dt(j['ADDITION_TIME'] ?? j['additionTime']),
      useFlag: s(j['USE_FLAG'] ?? j['useFlag']),
    );
  }
}

class CurrentStockInfoResult {
  final String resultCode;
  final String resultMessage;
  final CurrentStockInfo? data;

  CurrentStockInfoResult({
    required this.resultCode,
    required this.resultMessage,
    required this.data,
  });
}

