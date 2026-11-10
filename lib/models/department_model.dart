// ─────────────────────────────────────────────────────────────────────────────
//  department_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class DepartmentModel {
  final String id;
  final String name;
  final String shortCode;
  final String headUid; // UID of the department head
  final bool isActive;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.headUid,
    this.isActive = true,
  });

  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    return DepartmentModel(
      id: map['id'] as String,
      name: map['name'] as String,
      shortCode: map['shortCode'] as String,
      headUid: map['headUid'] as String,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortCode': shortCode,
    'headUid': headUid,
    'isActive': isActive,
  };
}
