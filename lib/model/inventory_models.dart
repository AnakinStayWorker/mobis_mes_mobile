class InventoryItem {
  final String id;
  final int quantity;
  final String? remark;
  final String useFlag;
  final DateTime? lastUptDate;
  final String? otherInfo;

  InventoryItem({
    required this.id,
    required this.quantity,
    this.remark,
    this.useFlag = 'Y',
    this.lastUptDate,
    this.otherInfo,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        return DateTime.parse(s).toLocal();
      } catch (_) {
        return null;
      }
    }

    return InventoryItem(
      id: json['Id'] ?? json['id'] ?? '',
      quantity: (json['Quantity'] ?? json['quantity'] ?? 0) is int
          ? (json['Quantity'] ?? json['quantity'])
          : int.tryParse((json['Quantity'] ?? json['quantity'] ?? '0').toString()) ?? 0,
      remark: json['Remark'] ?? json['remark'],
      useFlag: json['UseFlag'] ?? json['useFlag'] ?? 'Y',
      lastUptDate: parseDt(json['LastUptDate'] ?? json['lastUptDate']),
      otherInfo: json['OtherInfo'] ?? json['otherInfo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Quantity': quantity,
    'Remark': remark,
    'UseFlag': useFlag,
    'LastUptDate': lastUptDate?.toIso8601String(),
    'OtherInfo': otherInfo,
  };
}

class InventoryAllResult {
  final String resultCode;
  final String resultMessage;
  final List<InventoryItem> items;

  InventoryAllResult({
    required this.resultCode,
    required this.resultMessage,
    required this.items,
  });
}

class InventoryQtyResult {
  final String resultCode;
  final String resultMessage;
  final InventoryItem? item;

  InventoryQtyResult({
    required this.resultCode,
    required this.resultMessage,
    required this.item,
  });
}
