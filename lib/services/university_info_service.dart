// ─────────────────────────────────────────────────────────────────────────────
//  university_info_service.dart  –  Leading University (lus.ac.bd) Info Service
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle, AssetBundle;
import '../core/constants/app_constants.dart';
import 'cloud_functions_service.dart';

class OfficialFacultyMember {
  final String id;
  final String name;
  final String designation;
  final String department;
  final String deptCode;
  final String deptId;
  final String? imageUrl;
  final String? profileUrl;
  final String source;

  const OfficialFacultyMember({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.deptCode,
    required this.deptId,
    this.imageUrl,
    this.profileUrl,
    this.source = 'Official University Directory • lus.ac.bd',
  });

  factory OfficialFacultyMember.fromMap(Map<String, dynamic> map) {
    return OfficialFacultyMember(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      designation: map['designation']?.toString() ?? 'Faculty Member',
      department: map['department']?.toString() ?? '',
      deptCode: map['deptCode']?.toString() ?? '',
      deptId: map['deptId']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      profileUrl: map['profileUrl']?.toString(),
      source: map['source']?.toString() ??
          'Official University Directory • lus.ac.bd',
    );
  }
}

class OfficialDepartment {
  final String id;
  final String name;
  final String code;
  final String faculty;
  final String? officialWebUrl;
  final String status;

  const OfficialDepartment({
    required this.id,
    required this.name,
    required this.code,
    required this.faculty,
    this.officialWebUrl,
    this.status = 'active',
  });

  factory OfficialDepartment.fromMap(Map<String, dynamic> map, [String? docId]) {
    return OfficialDepartment(
      id: docId ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      faculty: map['faculty']?.toString() ?? 'General Faculty',
      officialWebUrl: map['officialWebUrl']?.toString(),
      status: map['status']?.toString() ?? 'active',
    );
  }
}

class UniversityOverview {
  final String universityName;
  final String shortName;
  final String campusAddress;
  final String pabx;
  final String generalEmail;
  final String websiteUrl;
  final String sourceUrl;
  final DateTime? lastSuccessfulUpdate;

  const UniversityOverview({
    required this.universityName,
    required this.shortName,
    required this.campusAddress,
    required this.pabx,
    required this.generalEmail,
    required this.websiteUrl,
    required this.sourceUrl,
    this.lastSuccessfulUpdate,
  });

  factory UniversityOverview.fromMap(Map<String, dynamic> map) {
    DateTime? updateTime;
    if (map['lastSuccessfulUpdate'] is Timestamp) {
      updateTime = (map['lastSuccessfulUpdate'] as Timestamp).toDate();
    }
    return UniversityOverview(
      universityName: map['universityName']?.toString() ?? 'Leading University',
      shortName: map['shortName']?.toString() ?? 'LU',
      campusAddress: map['campusAddress']?.toString() ??
          'Ragibnagar, South Surma, Sylhet-3112, Bangladesh',
      pabx: map['pabx']?.toString() ?? '01313084499',
      generalEmail: map['generalEmail']?.toString() ?? 'info@lus.ac.bd',
      websiteUrl: map['websiteUrl']?.toString() ?? 'https://lus.ac.bd/',
      sourceUrl: map['sourceUrl']?.toString() ?? 'https://lus.ac.bd/contact/',
      lastSuccessfulUpdate: updateTime,
    );
  }
}

class UniversityInfoService {
  FirebaseFirestore? _firestoreInstance;
  CloudFunctionsService? _functionsServiceInstance;

  UniversityInfoService({
    FirebaseFirestore? firestore,
    CloudFunctionsService? functionsService,
  })  : _firestoreInstance = firestore,
        _functionsServiceInstance = functionsService;

  FirebaseFirestore? get _firestore {
    try {
      return _firestoreInstance ??= FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CloudFunctionsService get _functionsService =>
      _functionsServiceInstance ??= CloudFunctionsService();

  /// Fetches university overview & contact details from Firestore cache with local fallback.
  Future<UniversityOverview> getOverview() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc =
            await firestore.collection('university_info').doc('overview').get();
        if (doc.exists && doc.data() != null) {
          return UniversityOverview.fromMap(doc.data()!);
        }
      } catch (_) {}
    }

    // Authoritative fallback
    return const UniversityOverview(
      universityName: 'Leading University',
      shortName: 'LU',
      campusAddress: 'Ragibnagar, South Surma, Sylhet-3112, Bangladesh',
      pabx: '01313084499',
      generalEmail: 'info@lus.ac.bd',
      websiteUrl: 'https://lus.ac.bd/',
      sourceUrl: 'https://lus.ac.bd/contact/',
    );
  }

  /// Streams or fetches official departments.
  /// Falls back to canonical `AppConstants.departmentNameToId` if offline or empty.
  Future<List<OfficialDepartment>> getOfficialDepartments() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('departments').get();
        if (snap.docs.isNotEmpty) {
          return snap.docs
              .map((d) => OfficialDepartment.fromMap(d.data(), d.id))
              .where((d) => d.status == 'active')
              .toList();
        }
      } catch (_) {}
    }

    // Fallback based on AppConstants canonical list
    return AppConstants.departmentNameToId.entries.map((e) {
      return OfficialDepartment(
        id: e.value,
        name: e.key,
        code: e.value.replaceAll('dept_', '').toUpperCase(),
        faculty: 'Leading University Academic Faculty',
        officialWebUrl: 'https://lus.ac.bd/faculty/',
      );
    }).toList();
  }

  /// Fetches policies document and distinguishes verified study leave from unverified leaves.
  Future<Map<String, dynamic>> getLeavePolicies() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc =
            await firestore.collection('university_info').doc('policies').get();
        if (doc.exists && doc.data() != null) {
          return doc.data()!;
        }
      } catch (_) {}
    }

    return {
      'leavePolicies': {
        'study_leave': {
          'name': 'Study Leave',
          'status': 'VERIFIED',
          'sourceUrl':
              'https://www.lus.ac.bd/wp-content/uploads/2021/09/Study-Leave-Policy.pdf',
          'isPubliclyVerified': true,
        },
        'casual_leave': {
          'name': 'Casual Leave',
          'status': 'Not verified – Admin configuration required',
          'isPubliclyVerified': false,
        },
        'medical_leave': {
          'name': 'Medical Leave',
          'status': 'Not verified – Admin configuration required',
          'isPubliclyVerified': false,
        },
      }
    };
  }

  /// Fetches sync metadata (status, source URLs, timestamps, conflicts).
  Future<Map<String, dynamic>?> getSyncMetadata() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('university_info')
            .doc('sync_metadata')
            .get();
        if (doc.exists && doc.data() != null) {
          return doc.data();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Admin-only manual sync trigger.
  Future<Map<String, dynamic>> triggerSync({bool force = false}) async {
    return await _functionsService.syncUniversityInfo(force: force);
  }

  /// Loads verified official faculty members directly from Leading University directory data.
  Future<List<OfficialFacultyMember>> getOfficialFaculty({AssetBundle? bundle}) async {
    try {
      final actualBundle = bundle ?? rootBundle;
      final jsonString = await actualBundle
          .loadString('assets/data/official_faculty.json')
          .timeout(const Duration(milliseconds: 100));
      final List<dynamic> list = json.decode(jsonString) as List<dynamic>;
      return list
          .map((item) =>
              OfficialFacultyMember.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
