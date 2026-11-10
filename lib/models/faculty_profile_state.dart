import 'package:flutter/material.dart';

class FacultyProfileData {
  final String fullName;
  final String email;
  final String phone;
  final String office;
  final String employeeId;
  final String department;
  final String designation;
  final String appointmentDate;
  final String? photoUrl;

  FacultyProfileData({
    this.fullName = 'Md. Arman',
    this.email = 'arman@leavexa.edu',
    this.phone = '+880 1712-345678',
    this.office = 'Room 304, Academic Bldg 2',
    this.employeeId = 'FAC-1024',
    this.department = 'Computer Science & Engineering',
    this.designation = 'Lecturer',
    this.appointmentDate = 'August 2022',
    this.photoUrl,
  });

  FacultyProfileData copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? office,
    String? employeeId,
    String? department,
    String? designation,
    String? appointmentDate,
    String? photoUrl,
    bool removePhoto = false,
  }) {
    return FacultyProfileData(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      office: office ?? this.office,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      photoUrl: removePhoto ? null : (photoUrl ?? this.photoUrl),
    );
  }
}

class FacultyProfileState {
  FacultyProfileState._();
  static final FacultyProfileState instance = FacultyProfileState._();

  final ValueNotifier<FacultyProfileData> notifier =
      ValueNotifier<FacultyProfileData>(FacultyProfileData());

  void updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? office,
    String? photoUrl,
    bool removePhoto = false,
  }) {
    notifier.value = notifier.value.copyWith(
      fullName: fullName,
      email: email,
      phone: phone,
      office: office,
      photoUrl: photoUrl,
      removePhoto: removePhoto,
    );
  }

  void reset() {
    notifier.value = FacultyProfileData();
  }
}
