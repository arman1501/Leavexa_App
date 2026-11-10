// ─────────────────────────────────────────────────────────────────────────────
//  leave_type_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class LeaveTypeModel {
  final String id;
  final String name; // e.g. 'Casual Leave'
  final String code; // e.g. 'CL'
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
      id: 'casual',
      name: 'Casual Leave',
      code: 'CL',
      defaultDays: 10,
    ),
    LeaveTypeModel(
      id: 'medical',
      name: 'Medical Leave',
      code: 'ML',
      defaultDays: 14,
      requiresDocument: true,
    ),
    LeaveTypeModel(
      id: 'earned',
      name: 'Earned Leave',
      code: 'EL',
      defaultDays: 30,
    ),
    LeaveTypeModel(
      id: 'duty',
      name: 'Duty Leave',
      code: 'DL',
      defaultDays: 14,
    ),
    LeaveTypeModel(
      id: 'station',
      name: 'Station Leave',
      code: 'STL',
      defaultDays: 5,
    ),
    LeaveTypeModel(
      id: 'study',
      name: 'Study Leave',
      code: 'SL',
      defaultDays: 30,
      requiresDocument: true,
    ),
  ];

  /// Normalizes legacy aliases ('casual_leave', 'sick', 'sick_leave') to canonical IDs.
  static String normalizeId(String rawId) {
    switch (rawId.trim().toLowerCase()) {
      case 'sick':
      case 'sick_leave':
      case 'medical_leave':
        return 'medical';
      case 'casual_leave':
        return 'casual';
      case 'duty_leave':
        return 'duty';
      case 'station_leave':
        return 'station';
      case 'study_leave':
        return 'study';
      case 'earned_leave':
        return 'earned';
      default:
        return rawId.trim().toLowerCase();
    }
  }
}
