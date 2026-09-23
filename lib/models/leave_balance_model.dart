// ─────────────────────────────────────────────────────────────────────────────
//  leave_balance_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class LeaveBalanceModel {
  final String id;
  final String userUid;
  final String leaveTypeId;
  final String leaveTypeName;
  final int totalAllotted;
  final int used;
  final int year;

  const LeaveBalanceModel({
    required this.id,
    required this.userUid,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.totalAllotted,
    required this.used,
    required this.year,
  });

  int get remaining => totalAllotted - used;

  factory LeaveBalanceModel.fromMap(Map<String, dynamic> map) {
    return LeaveBalanceModel(
      id: map['id'] as String,
      userUid: map['userUid'] as String,
      leaveTypeId: map['leaveTypeId'] as String,
      leaveTypeName: map['leaveTypeName'] as String,
      totalAllotted: map['totalAllotted'] as int,
      used: map['used'] as int,
      year: map['year'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userUid': userUid,
    'leaveTypeId': leaveTypeId,
    'leaveTypeName': leaveTypeName,
    'totalAllotted': totalAllotted,
    'used': used,
    'year': year,
  };
}
