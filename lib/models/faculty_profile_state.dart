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

  FacultyProfileData({
    this.fullName = 'Md. Arman Hussan',
    this.email = 'rahman@cse.univ.edu',
    this.phone = '+880 1712-345678',
    this.office = 'Room 408, Academic Bldg 2',
    this.employeeId = 'FAC-1024',
    this.department = 'Computer Science & Engineering',
    this.designation = 'Associate Professor (Tenured)',
    this.appointmentDate = 'August 2018 (6 Years Tenure)',
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
  }) {
    notifier.value = notifier.value.copyWith(
      fullName: fullName,
      email: email,
      phone: phone,
      office: office,
    );
  }
}
