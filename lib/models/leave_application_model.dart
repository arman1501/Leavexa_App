// ─────────────────────────────────────────────────────────────────────────────
//  leave_application_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class LeaveApplicationModel {
  final String id;
  final String applicantUid;
  final String applicantName;
  final String applicantEmployeeId;
  final String departmentId;
  final String departmentName;
  final String leaveTypeId;
  final String leaveTypeName;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final String? documentUrl;

  // Approval flow
  final String status; // pending | forwarded | approved | rejected
  final String? headComment;
  final DateTime? headActionAt;
  final String? headUid;

  final String? registrarComment;
  final DateTime? registrarActionAt;
  final String? registrarUid;

  // Cancellation flow
  final DateTime? cancelledAt;
  final String? cancelReason;

  final DateTime appliedAt;

  const LeaveApplicationModel({
    required this.id,
    required this.applicantUid,
    required this.applicantName,
    required this.applicantEmployeeId,
    required this.departmentId,
    required this.departmentName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.documentUrl,
    this.status = 'pending',
    this.headComment,
    this.headActionAt,
    this.headUid,
    this.registrarComment,
    this.registrarActionAt,
    this.registrarUid,
    this.cancelledAt,
    this.cancelReason,
    required this.appliedAt,
  });

  factory LeaveApplicationModel.fromMap(Map<String, dynamic> map) {
    return LeaveApplicationModel(
      id: map['id'] as String,
      applicantUid: map['applicantUid'] as String,
      applicantName: map['applicantName'] as String,
      applicantEmployeeId: map['applicantEmployeeId'] as String,
      departmentId: map['departmentId'] as String,
      departmentName: map['departmentName'] as String,
      leaveTypeId: map['leaveTypeId'] as String,
      leaveTypeName: map['leaveTypeName'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      totalDays: map['totalDays'] as int,
      reason: map['reason'] as String,
      documentUrl: map['documentUrl'] as String?,
      status: map['status'] as String? ?? 'pending',
      headComment: map['headComment'] as String?,
      headActionAt: map['headActionAt'] != null
          ? DateTime.parse(map['headActionAt'] as String)
          : null,
      headUid: map['headUid'] as String?,
      registrarComment: map['registrarComment'] as String?,
      registrarActionAt: map['registrarActionAt'] != null
          ? DateTime.parse(map['registrarActionAt'] as String)
          : null,
      registrarUid: map['registrarUid'] as String?,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'] as String)
          : null,
      cancelReason: map['cancelReason'] as String?,
      appliedAt: DateTime.parse(map['appliedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'applicantUid': applicantUid,
    'applicantName': applicantName,
    'applicantEmployeeId': applicantEmployeeId,
    'departmentId': departmentId,
    'departmentName': departmentName,
    'leaveTypeId': leaveTypeId,
    'leaveTypeName': leaveTypeName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'totalDays': totalDays,
    'reason': reason,
    'documentUrl': documentUrl,
    'status': status,
    'headComment': headComment,
    'headActionAt': headActionAt?.toIso8601String(),
    'headUid': headUid,
    'registrarComment': registrarComment,
    'registrarActionAt': registrarActionAt?.toIso8601String(),
    'registrarUid': registrarUid,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancelReason': cancelReason,
    'appliedAt': appliedAt.toIso8601String(),
  };

  LeaveApplicationModel copyWith({
    String? status,
    String? headComment,
    DateTime? headActionAt,
    String? headUid,
    String? registrarComment,
    DateTime? registrarActionAt,
    String? registrarUid,
    DateTime? cancelledAt,
    String? cancelReason,
  }) {
    return LeaveApplicationModel(
      id: id,
      applicantUid: applicantUid,
      applicantName: applicantName,
      applicantEmployeeId: applicantEmployeeId,
      departmentId: departmentId,
      departmentName: departmentName,
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      reason: reason,
      documentUrl: documentUrl,
      status: status ?? this.status,
      headComment: headComment ?? this.headComment,
      headActionAt: headActionAt ?? this.headActionAt,
      headUid: headUid ?? this.headUid,
      registrarComment: registrarComment ?? this.registrarComment,
      registrarActionAt: registrarActionAt ?? this.registrarActionAt,
      registrarUid: registrarUid ?? this.registrarUid,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      appliedAt: appliedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isForwarded => status == 'forwarded';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}
