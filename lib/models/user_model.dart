
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String employeeId;
  final String departmentId;
  final String departmentName;
  final String designation;
  final String role;
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final String approvalStatus;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.departmentId,
    required this.departmentName,
    required this.designation,
    required this.role,
    this.phone,
    this.photoUrl,
    this.isActive = false,
    this.approvalStatus = 'pending',
    required this.createdAt,
  });

  // Firestore → UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final timestamp = map['createdAt'];

    DateTime parsedDate;

    if (timestamp is Timestamp) {
      parsedDate = timestamp.toDate();
    } else if (timestamp is String) {
      parsedDate = DateTime.tryParse(timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return UserModel(
      uid: map['uid'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      departmentId: map['departmentId'] as String? ?? '',
      departmentName: map['departmentName'] as String? ?? '',
      designation: map['designation'] as String? ?? '',
      role: map['role'] as String? ?? 'faculty',
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? false,
      approvalStatus:
      map['approvalStatus'] as String? ?? 'pending',
      createdAt: parsedDate,
    );
  }

  // UserModel → Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'employeeId': employeeId,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'designation': designation,
      'role': role,
      'phone': phone,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'approvalStatus': approvalStatus,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Update existing user information
  UserModel copyWith({
    String? fullName,
    String? phone,
    String? photoUrl,
    String? designation,
    bool? isActive,
    String? approvalStatus,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      employeeId: employeeId,
      departmentId: departmentId,
      departmentName: departmentName,
      designation: designation ?? this.designation,
      role: role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt,
    );
  }
}
