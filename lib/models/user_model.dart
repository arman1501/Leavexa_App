// ─────────────────────────────────────────────────────────────────────────────
//  user_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String employeeId;
  final String departmentId;
  final String departmentName;
  final String role; // 'faculty' | 'department_head' | 'registrar'
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.departmentId,
    required this.departmentName,
    required this.role,
    this.phone,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      employeeId: map['employeeId'] as String,
      departmentId: map['departmentId'] as String,
      departmentName: map['departmentName'] as String,
      role: map['role'] as String,
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'employeeId': employeeId,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'role': role,
      'phone': phone,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? photoUrl,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      employeeId: employeeId,
      departmentId: departmentId,
      departmentName: departmentName,
      role: role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
