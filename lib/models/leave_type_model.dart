// ─────────────────────────────────────────────────────────────────────────────
//  leave_type_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class LeaveTypeModel {
  final String id;
  final String name;          // e.g. 'Casual Leave'
  final String code;          // e.g. 'CL'
  final int defaultDays;
  final bool requiresDocument;
  final bool isActive;

  const LeaveTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.defaultDays,
    this.requiresDocument = false,
    this.isActive = true,
  });

  factory LeaveTypeModel.fromMap(Map<String, dynamic> map) {
    return LeaveTypeModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      defaultDays: map['defaultDays'] as int,
      requiresDocument: map['requiresDocument'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'defaultDays': defaultDays,
    'requiresDocument': requiresDocument,
    'isActive': isActive,
  };

  static List<LeaveTypeModel> get defaultLeaveTypes => const [
    LeaveTypeModel(
      id: 'casual_leave',
      name: 'Casual Leave',
      code: 'CL',
      defaultDays: 10,
    ),
    LeaveTypeModel(
      id: 'duty_leave',
      name: 'Duty Leave',
      code: 'DL',
      defaultDays: 14,
    ),
    LeaveTypeModel(
      id: 'station_leave',
      name: 'Station Leave',
      code: 'STL',
      defaultDays: 5,
    ),
    LeaveTypeModel(
      id: 'study_leave',
      name: 'Study Leave',
      code: 'SL',
      defaultDays: 30,
    ),
    LeaveTypeModel(
      id: 'others',
      name: 'Others',
      code: 'OTH',
      defaultDays: 7,
    ),
  ];
}
