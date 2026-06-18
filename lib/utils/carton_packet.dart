double roundToDecimals(double value, int decimals) {
  final factor = _pow10(decimals);
  return (value * factor).roundToDouble() / factor;
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}

String formatQty(double? qty) {
  if (qty == null) return '0';
  final s = qty.toStringAsFixed(3);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}

int splitCartonPacketToCartons(double qty) => qty.floor();

int splitCartonPacketToPackets(double qty) {
  final pkts = ((qty - qty.floor()) * 6).round();
  return pkts == 6 ? 0 : pkts;
}

String formatCP(double qty, {bool packetsEnabled = false}) {
  if (!packetsEnabled) return formatQty(qty);
  final cartons = splitCartonPacketToCartons(qty);
  final packets = splitCartonPacketToPackets(qty);
  if (packets == 0) return '$cartons';
  return '$cartons كرتون + $packets باكيت';
}

String formatCPCompact(double qty, {bool packetsEnabled = false}) {
  if (!packetsEnabled) return formatQty(qty);
  final cartons = splitCartonPacketToCartons(qty);
  final packets = splitCartonPacketToPackets(qty);
  return packets == 0 ? '$cartons' : '${cartons}ك ${packets}ب';
}

double cpToBaseQty(int cartons, int packets) {
  return (cartons).toDouble() + (packets) / 6.0;
}
