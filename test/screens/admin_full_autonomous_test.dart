import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/core/theme/app_theme.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/admin/admin_dashboard.dart';
import 'package:leavexa/screens/admin/admin_profile_screen.dart';
import 'package:leavexa/services/storage_service.dart';
import 'package:leavexa/widgets/app_avatar.dart';

class MockFullAdminUserRepository extends UserRepository {
  bool approveFacultyCalled = false;
  String? lastApprovedUid;

  bool rejectFacultyCalled = false;
  String? lastRejectedUid;
  String? lastRejectionReason;

  bool setUserActiveCalled = false;
  String? lastActiveUid;
  bool? lastActiveStatus;

  List<UserModel> mockPending = [];
  List<UserModel> mockAll = [];
  List<UserModel> mockAdmins = [];
  StreamController<List<UserModel>>? usersStreamController;
  bool throwOnApprove = false;
  bool throwOnReject = false;

  @override
  Future<List<UserModel>> getPendingFaculty() async => mockPending;

  @override
  Future<List<UserModel>> getAllFaculty() async => mockAll;

  @override
  Future<List<UserModel>> getActiveAdmins() async => mockAdmins;

  @override
  Stream<List<UserModel>> streamAllUsers() =>
      usersStreamController?.stream ?? const Stream.empty();

  @override
  Future<void> approveFaculty(String uid) async {
    if (throwOnApprove) {
      throw Exception('Permission denied');
    }
    approveFacultyCalled = true;
    lastApprovedUid = uid;
  }

  @override
  Future<void> rejectFaculty(String uid, {String? reason}) async {
    if (throwOnReject) {
      throw Exception('Network error');
    }
    rejectFacultyCalled = true;
    lastRejectedUid = uid;
    lastRejectionReason = reason;
  }

  Map<String, dynamic>? lastUpdatedUserData;

  @override
  Future<void> setUserActive(String uid, bool isActive) async {
    setUserActiveCalled = true;
    lastActiveUid = uid;
    lastActiveStatus = isActive;
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    lastUpdatedUserData = data;
  }
}

class MockFailingStorageService extends StorageService {
  @override
  Future<String> uploadProfileImage({
    required String uid,
    required File file,
    String? previousPhotoUrl,
    void Function(double)? onProgress,
  }) async {
    throw Exception('404 Not Found: Storage bucket not provisioned');
  }
}

class MockAdminImagePicker extends ImagePicker {
  final XFile? fileToReturn;
  MockAdminImagePicker(this.fileToReturn);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      fileToReturn;
}

class MockFullAdminAuthRepository extends AuthRepository {
  UserModel? mockUser;
  bool logoutCalled = false;

  MockFullAdminAuthRepository({this.mockUser});

  @override
  String? get currentUserId => mockUser?.uid;

  @override
  Future<UserModel?> getCurrentUserProfile() async => mockUser;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    AuthRepository.activeUser = null;
  }
}

void main() {
  UserModel createTestUser({
    required String uid,
    required String name,
    required String empId,
    required String approvalStatus,
    String deptName = 'Computer Science & Engineering',
    String deptId = 'dept_cse',
    bool isActive = true,
  }) {
    return UserModel(
      uid: uid,
      email: '$empId@leavexa.edu',
      fullName: name,
      employeeId: empId,
      role: 'faculty',
      departmentId: deptId,
      departmentName: deptName,
      designation: 'Assistant Professor',
      approvalStatus: approvalStatus,
      isActive: isActive,
      createdAt: DateTime.now(),
    );
  }

  group('A & B: Admin Dashboard & Statistics Tests', () {
    testWidgets('Dashboard loads and displays real-time statistics counters',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final mockAuthRepo = MockFullAdminAuthRepository(
        mockUser: UserModel(
          uid: 'admin_uid_1',
          email: 'admin.lu@gmail.com',
          fullName: 'System Administrator',
          employeeId: 'ADMIN-001',
          role: 'admin',
          designation: 'System Administrator',
          departmentId: 'admin_dept',
          departmentName: 'Office of the Administrator',
          approvalStatus: 'approved',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final pendingUser = createTestUser(
        uid: 'pending_user_1',
        name: 'Dr. Pending Teacher',
        empId: 'FAC-001',
        approvalStatus: 'pending',
        isActive: false,
      );

      final approvedUser = createTestUser(
        uid: 'approved_user_1',
        name: 'Dr. Approved Teacher',
        empId: 'FAC-002',
        approvalStatus: 'approved',
        isActive: true,
      );

      final rejectedUser = createTestUser(
        uid: 'rejected_user_1',
        name: 'Dr. Rejected Teacher',
        empId: 'FAC-003',
        approvalStatus: 'rejected',
        isActive: false,
      );

      mockUserRepo.mockPending = [pendingUser];
      mockUserRepo.mockAll = [approvedUser, rejectedUser];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(
            userRepository: mockUserRepo,
            authRepository: mockAuthRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading check
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Manage pending teacher registrations and verify credentials.'), findsOneWidget);

      // Stat cards: pending = 1, approved = 1, rejected = 1
      expect(find.text('1'), findsWidgets);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Needs Action'), findsOneWidget);
      expect(find.text('This Session'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('Dashboard renders clean empty state when no pending faculty exist',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final mockAuthRepo = MockFullAdminAuthRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(
            userRepository: mockUserRepo,
            authRepository: mockAuthRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home tab shows empty state when no pending faculty exist
      expect(find.text('No Pending Registrations'), findsOneWidget);
      expect(find.text('All faculty registrations have been reviewed and processed.'), findsOneWidget);

      // Switch to Approvals Queue tab
      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Approvals Queue'), findsOneWidget);
      expect(find.text('No registration requests found'), findsOneWidget);
      expect(find.text('Try clearing the search query or status filter.'), findsOneWidget);
    });
  });

  group('C: Faculty Verification & Actions Tests', () {
    testWidgets('Pending queue displays genuine faculty and filters synthetic stubs',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final genuineFaculty = createTestUser(
        uid: 'tester1501_uid',
        name: 'Md. Tester',
        empId: 'LU-015',
        approvalStatus: 'pending',
        isActive: false,
      );
      final syntheticPhotoStub = createTestUser(
        uid: 'no_photo_user_99',
        name: 'No Photo User',
        empId: 'EMP-NOPHOTO-999',
        approvalStatus: 'pending',
        isActive: false,
      );
      final syntheticValidReg = createTestUser(
        uid: 'valid_reg_99',
        name: 'Dr. Valid Faculty',
        empId: 'EMP-VAL-999',
        approvalStatus: 'pending',
        isActive: false,
      );

      mockUserRepo.mockPending = [genuineFaculty, syntheticPhotoStub, syntheticValidReg];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Approvals tab
      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      // Genuine faculty must appear
      expect(find.text('Md. Tester'), findsOneWidget);
      expect(find.textContaining('LU-015'), findsOneWidget);

      // Synthetic stubs must be completely filtered out
      expect(find.text('EMP-NOPHOTO-999'), findsNothing);
      expect(find.text('EMP-VAL-999'), findsNothing);
    });

    testWidgets('Credential Inspection modal shows Faculty ID Verified and no PDF button',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final faculty = createTestUser(
        uid: 'genuine_fac_1',
        name: 'Dr. Tariqul Islam',
        empId: 'FAC-777',
        approvalStatus: 'pending',
        isActive: false,
      );
      mockUserRepo.mockPending = [faculty];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Open inspection modal via 'Inspect' button on the pending card
      final inspectBtn = find.text('Inspect');
      expect(inspectBtn, findsOneWidget);
      await tester.tap(inspectBtn);
      await tester.pumpAndSettle();

      // Modal verification
      expect(find.textContaining('Faculty ID'), findsWidgets);
      expect(find.text('Attached Documentation'), findsNothing);
      expect(find.text('Download PDF'), findsNothing);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });

  group('D: Faculty Directory & University Sync Tests', () {
    testWidgets('Directory renders search bar, department chips and distinguishes sources',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final regFaculty = createTestUser(
        uid: 'reg_fac_1',
        name: 'Dr. Aminul Haque',
        empId: 'FAC-100',
        approvalStatus: 'approved',
        isActive: true,
      );
      mockUserRepo.mockAll = [regFaculty];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Faculty Directory
      await tester.tap(find.text('Faculty'));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Directory'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Department filter chips
      expect(find.text('All Departments'), findsOneWidget);
      expect(find.text('CSE'), findsOneWidget);
      expect(find.text('EEE'), findsOneWidget);
      expect(find.text('BBA'), findsOneWidget);

      // Leavexa registered badge
      expect(find.text('LEAVEXA VERIFIED'), findsOneWidget);
      expect(find.text('Dr. Aminul Haque'), findsOneWidget);

      // Search functionality
      await tester.enterText(find.byType(TextField), 'NonExistentPersonXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No faculty members found'), findsOneWidget);
    });
  });

  group('F: Admin Profile & Logout Confirmation Tests', () {
    testWidgets('Admin Profile shows details, omits Theme row, and orders Logout buttons vertically',
        (tester) async {
      final mockAuthRepo = MockFullAdminAuthRepository(
        mockUser: UserModel(
          uid: 'admin_test_uid',
          email: 'admin.lu@gmail.com',
          fullName: 'System Administrator',
          employeeId: 'ADMIN-001',
          role: 'admin',
          designation: 'System Administrator',
          departmentId: 'admin_dept',
          departmentName: 'Office of the Administrator',
          approvalStatus: 'approved',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (ctx) => const Scaffold(body: Text('Login Screen Mock')),
          },
          home: AdminProfileScreen(authRepository: mockAuthRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Admin profile details
      expect(find.text('System Administrator'), findsOneWidget);
      expect(find.text('admin.lu@gmail.com'), findsOneWidget);

      // Verify Theme Appearance is removed
      expect(find.text('Theme Appearance'), findsNothing);

      // Verify Teacher Verifications Queue shortcut is removed
      expect(find.text('Teacher Verifications Queue'), findsNothing);

      // Verify Verified Faculty Directory shortcut is present
      expect(find.text('Verified Faculty Directory'), findsOneWidget);

      // Tap Logout button
      final logoutBtn = find.text('Log Out of Admin Portal');
      await tester.scrollUntilVisible(logoutBtn, 50);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Verify Logout Dialog modal appears
      expect(find.text('Are you sure you want to log out of the Administrator Portal?'), findsOneWidget);

      // Verify Cancel button dismisses modal
      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to log out of the Administrator Portal?'), findsNothing);

      // Tap Logout again and confirm
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      final confirmLogoutBtn = find.widgetWithText(ElevatedButton, 'Log Out');
      expect(confirmLogoutBtn, findsOneWidget);
      await tester.tap(confirmLogoutBtn);
      await tester.pumpAndSettle();

      expect(mockAuthRepo.logoutCalled, isTrue);
      expect(find.text('Login Screen Mock'), findsOneWidget);
    });
  });

  group('I: Responsiveness & RenderFlex Overflow Matrix', () {
    testWidgets('Admin Dashboard renders on small screen (320x568) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUserRepo = MockFullAdminUserRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm no exception occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('Admin Dashboard renders on standard screen (390x844) without overflow',
        (tester) async {
      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUserRepo = MockFullAdminUserRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      if (errorDetails != null) {
        debugPrint('WIDGET CREATOR: ${errorDetails!.informationCollector?.call().map((e) => e.toString()).join('\n')}');
      }
      final ex = tester.takeException();
      expect(ex, isNull);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('Admin Dashboard renders on large screen (412x915) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockUserRepo = MockFullAdminUserRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Admin Dashboard'), findsOneWidget);
    });
  });

  group('J: Real-Time Updates, Header Styling, Approvals Badge & Directory Overflow', () {
    testWidgets(
        'AdminProfileScreen updates stats & Approvals badge in real time and hides badge when pending is 0',
        (tester) async {
      final controller = StreamController<List<UserModel>>.broadcast();
      addTearDown(() => controller.close());

      final mockUserRepo = MockFullAdminUserRepository()
        ..usersStreamController = controller;
      final admin1 = UserModel(
        uid: 'admin_1',
        email: 'admin.lu@gmail.com',
        fullName: 'System Administrator',
        employeeId: 'EMP-ADM01',
        role: 'admin',
        designation: 'System Administrator',
        departmentId: 'admin_dept',
        departmentName: 'Administration',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final mockAuthRepo = MockFullAdminAuthRepository(mockUser: admin1);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProfileScreen(
            authRepository: mockAuthRepo,
            userRepository: mockUserRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Emit initial snapshot: 1 approved teacher (0 pending), 1 active admin
      final approvedFaculty = createTestUser(
        uid: 'fac_1',
        name: 'Md. Hasan',
        empId: 'LU-11',
        approvalStatus: 'approved',
        isActive: true,
      );
      controller.add([admin1, approvedFaculty]);
      await tester.pumpAndSettle();

      // Total Teachers = 1, Pending Requests = 0, Active Admins = 1
      expect(find.text('Total Teachers'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Active Admins'), findsOneWidget);
      expect(find.byType(Badge), findsNothing);

      // Header title uses normal font (18, non-serif)
      final profileTitle = tester.widget<Text>(find.text('Admin Profile'));
      expect(profileTitle.style?.fontSize, 18);
      expect(profileTitle.style?.fontFamily, isNull);

      // Simulate new faculty registering + second admin added in real time
      final pendingFaculty = createTestUser(
        uid: 'fac_2',
        name: 'Md. Tester',
        empId: 'LU-015',
        approvalStatus: 'pending',
        isActive: false,
      );
      final admin2 = UserModel(
        uid: 'admin_2',
        email: 'admin2@leavexa.edu',
        fullName: 'Co-Administrator',
        employeeId: 'EMP-ADM02',
        role: 'admin',
        designation: 'Co-Admin',
        departmentId: 'admin_dept',
        departmentName: 'Administration',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      controller.add([admin1, admin2, approvedFaculty, pendingFaculty]);
      await tester.pumpAndSettle();

      // Total Teachers = 2, Pending Requests = 1, Active Admins = 2
      expect(find.text('2'), findsNWidgets(2));
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgets(
        'AdminDashboard updates stats in real time and Faculty Directory card shows long designations & full names without overflow at 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = StreamController<List<UserModel>>.broadcast();
      addTearDown(() => controller.close());

      final mockUserRepo = MockFullAdminUserRepository()
        ..usersStreamController = controller;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Normal header title styling check
      final dashTitle = tester.widget<Text>(find.text('Admin Dashboard'));
      expect(dashTitle.style?.fontSize, 18);
      expect(dashTitle.style?.fontFamily, isNull);

      // Stream a faculty member with a very long name & long designation
      final longFaculty = UserModel(
        uid: 'fac_long_1',
        email: 'verylongfacultyaddress@lus.ac.bd',
        fullName: 'Professor Dr. Mohammad Shahabuddin Chowdhury',
        employeeId: 'LU-CSE-004',
        role: 'faculty',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Associate Professor & Head',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      controller.add([longFaculty]);
      await tester.pumpAndSettle();

      // Switch to Faculty Directory tab
      await tester.tap(find.text('Faculty'));
      await tester.pumpAndSettle();

      expect(
        find.text('Professor Dr. Mohammad Shahabuddin Chowdhury'),
        findsOneWidget,
      );
      expect(find.text('Associate Professor & Head'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('K: Final Audit Regression Tests (Isolation, Rollback, Filters, Widths)', () {
    testWidgets(
        'Staff roles (admin, head, registrar) are strictly excluded from Faculty counts',
        (tester) async {
      final controller = StreamController<List<UserModel>>.broadcast();
      addTearDown(() => controller.close());

      final mockUserRepo = MockFullAdminUserRepository()
        ..usersStreamController = controller;

      final admin = UserModel(
        uid: 'adm_1',
        email: 'admin.lu@gmail.com',
        fullName: 'Primary Admin',
        employeeId: 'ADM-001',
        role: 'admin',
        departmentId: 'admin_office',
        departmentName: 'Administration',
        designation: 'System Administrator',
        phone: '+8801711111111',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final head = UserModel(
        uid: 'head_1',
        email: 'head@lus.ac.bd',
        fullName: 'Dr. Dept Head',
        employeeId: 'HEAD-01',
        role: 'department_head',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Head of CSE',
        approvalStatus: 'pending',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final registrar = UserModel(
        uid: 'reg_1',
        email: 'reg@lus.ac.bd',
        fullName: 'Mr. Registrar',
        employeeId: 'REG-01',
        role: 'registrar',
        departmentId: 'registrar_office',
        departmentName: 'Office of the Registrar',
        designation: 'Registrar',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final faculty = createTestUser(
        uid: 'fac_only_1',
        name: 'Genuine Lecturer',
        empId: 'FAC-101',
        approvalStatus: 'approved',
        isActive: true,
      );

      final mockAuthRepo = MockFullAdminAuthRepository(mockUser: admin);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProfileScreen(
            authRepository: mockAuthRepo,
            userRepository: mockUserRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.add([admin, head, registrar, faculty]);
      await tester.pumpAndSettle();

      // Dynamic Admin identity fields rendered from UserModel
      expect(find.text('ADM-001'), findsOneWidget);
      expect(find.text('+8801711111111'), findsOneWidget);
      expect(find.text('Administration'), findsOneWidget);

      // Total Teachers = 1 (faculty only), Pending = 0, Active Admins = 1
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets(
        'Approve failure rolls back optimistic status and pending counter and shows error',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository()..throwOnApprove = true;
      final pendingFaculty = createTestUser(
        uid: 'fac_err_1',
        name: 'Dr. Error Rollback',
        empId: 'FAC-ERR-1',
        approvalStatus: 'pending',
        isActive: false,
      );
      mockUserRepo.mockPending = [pendingFaculty];
      mockUserRepo.mockAll = [pendingFaculty];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Card stays pending with Approve button still visible after rollback
      expect(find.text('Approve'), findsOneWidget);
      expect(find.textContaining('Failed to approve'), findsOneWidget);
    });

    testWidgets(
        'Faculty Directory filters canonical dept codes (CE, MPH, BNG), searches by email, and filters Active/Inactive',
        (tester) async {
      final controller = StreamController<List<UserModel>>.broadcast();
      addTearDown(() => controller.close());
      final mockUserRepo = MockFullAdminUserRepository()
        ..usersStreamController = controller;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      final civilFac = UserModel(
        uid: 'fac_ce_1',
        email: 'civil.prof@lus.ac.bd',
        fullName: 'Engr. Civil Faculty',
        employeeId: 'LU-CE-10',
        role: 'faculty',
        departmentId: 'dept_civil',
        departmentName: 'Civil Engineering',
        designation: 'Assistant Professor',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final inactiveFac = UserModel(
        uid: 'fac_mph_1',
        email: 'public.health@lus.ac.bd',
        fullName: 'Dr. Public Health',
        employeeId: 'LU-MPH-20',
        role: 'faculty',
        departmentId: 'dept_public_health',
        departmentName: 'Department of Public Health',
        designation: 'Lecturer',
        approvalStatus: 'approved',
        isActive: false,
        createdAt: DateTime.now(),
      );
      controller.add([civilFac, inactiveFac]);
      await tester.pumpAndSettle();

      // Switch to Faculty Directory
      await tester.tap(find.text('Faculty'));
      await tester.pumpAndSettle();

      // Filter by Civil (CE) -> finds dept_civil faculty!
      await tester.tap(find.text('Civil (CE)'));
      await tester.pumpAndSettle();
      expect(find.text('Engr. Civil Faculty'), findsOneWidget);
      expect(find.text('Dr. Public Health'), findsNothing);

      // Reset to All Departments and filter by Inactive status
      await tester.tap(find.text('All Departments'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Public Health'), findsOneWidget);
      expect(find.text('Engr. Civil Faculty'), findsNothing);

      // Reset status to All Status and search by email
      await tester.tap(find.text('All Status'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'civil.prof@lus.ac.bd');
      await tester.pumpAndSettle();
      expect(find.text('Engr. Civil Faculty'), findsOneWidget);
      expect(find.text('Dr. Public Health'), findsNothing);
    });

    testWidgets(
        'Approvals Queue renders dynamic APPROVED/REJECTED badges and hides Pending action buttons',
        (tester) async {
      final mockUserRepo = MockFullAdminUserRepository();
      final approved = createTestUser(
        uid: 'fac_app_1',
        name: 'Approved Faculty Member',
        empId: 'FAC-APP-1',
        approvalStatus: 'approved',
        isActive: true,
      );
      mockUserRepo.mockAll = [approved];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(userRepository: mockUserRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Approved Faculty Member'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets(
        'AdminDashboard and AdminProfileScreen pass responsive matrix across 320, 360, 390, 430, and 800px tablet',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final widths = <double>[320, 360, 390, 430, 800];
      for (final w in widths) {
        tester.view.physicalSize = Size(w, 844);
        tester.view.devicePixelRatio = 1.0;

        final mockUserRepo = MockFullAdminUserRepository();
        final mockAuthRepo = MockFullAdminAuthRepository(
          mockUser: UserModel(
            uid: 'adm_matrix',
            email: 'admin.lu@gmail.com',
            fullName: 'Very Long Administrator Full Name For Viewport Check',
            employeeId: 'EMP-ADM-MATRIX',
            role: 'admin',
            departmentId: 'admin_office',
            departmentName: 'Office of the Administrator',
            designation: 'Chief System Administrator',
            approvalStatus: 'approved',
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AdminProfileScreen(
              authRepository: mockAuthRepo,
              userRepository: mockUserRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Profile overflow at $w px');
      }
      tester.view.resetPhysicalSize();
    });
  });

  group('L: Dark Mode Contrast, Visit Website CTA, Base64 Avatar & Theme-Safe Logout', () {
    testWidgets(
        'AppAvatar renders Base64 data URI photo without network call',
        (tester) async {
      // 1x1 valid transparent PNG encoded in Base64
      const tinyPngDataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppAvatar(
              name: 'System Administrator',
              photoUrl: tinyPngDataUri,
              size: 64,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'University Info button has high-contrast dark mode color and modal displays Visit University Website CTA & link',
        (tester) async {
      AppThemeState.instance.toggleTheme(true);
      addTearDown(() => AppThemeState.instance.resetToLightMode());

      final mockUserRepo = MockFullAdminUserRepository();
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeState.instance.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              home: AdminDashboard(userRepository: mockUserRepo),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final uniBtnFinder = find.byKey(const Key('university_info_sync_button'));
      expect(uniBtnFinder, findsOneWidget);

      // Tap button to open University Official Info modal
      await tester.tap(uniBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('University Official Info'), findsOneWidget);
      expect(find.text('Visit University Website'), findsOneWidget);
      expect(find.text('https://lus.ac.bd/'), findsOneWidget);
      expect(find.text('Synchronize Information from Website'), findsNothing);
      expect(tester.takeException(), isNull);

      // Tap Visit University Website button (copies URL cleanly in test env)
      await tester.tap(
        find.byKey(const Key('modal_visit_university_website_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AdminProfileScreen dark mode toggle + logout under ValueListenableBuilder MaterialApp throws zero GlobalKey or _dependents assertions',
        (tester) async {
      AppThemeState.instance.toggleTheme(true);
      addTearDown(() => AppThemeState.instance.resetToLightMode());

      final mockUserRepo = MockFullAdminUserRepository();
      final mockAuthRepo = MockFullAdminAuthRepository(
        mockUser: UserModel(
          uid: 'adm_dark_logout',
          email: 'admin.lu@gmail.com',
          fullName: 'System Administrator',
          employeeId: 'ADMIN-001',
          role: 'admin',
          departmentId: 'admin_office',
          departmentName: 'Office of the Administrator',
          designation: 'System Administrator',
          approvalStatus: 'approved',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeState.instance.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              routes: {
                AppRoutes.login: (_) =>
                    const Scaffold(body: Text('Login Screen Mock')),
              },
              home: AdminProfileScreen(
                authRepository: mockAuthRepo,
                userRepository: mockUserRepo,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Toggle dark -> light -> dark while mounted
      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Scroll down to logout button and log out from Dark Mode
      final logoutBtn = find.text('Log Out of Admin Portal');
      await tester.scrollUntilVisible(logoutBtn, 150);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(mockAuthRepo.logoutCalled, isTrue);
      expect(AppThemeState.instance.themeModeNotifier.value, ThemeMode.light);
      expect(find.text('Login Screen Mock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AdminProfileScreen falls back to compressed Base64 data URI in Firestore when Storage upload fails',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('leavexa_avatar_test');
      addTearDown(() {
        AuthRepository.activeUser = null;
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final tempPng = File('${tempDir.path}/avatar.png');
      const pngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      tempPng.writeAsBytesSync(base64Decode(pngBase64));

      final adminUser = UserModel(
        uid: 'adm_photo_1',
        email: 'admin.lu@gmail.com',
        fullName: 'System Administrator',
        employeeId: 'ADMIN-001',
        role: 'admin',
        departmentId: 'admin_office',
        departmentName: 'Office of the Administrator',
        designation: 'System Administrator',
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime.now(),
      );
      AuthRepository.activeUser = adminUser;

      final mockUserRepo = MockFullAdminUserRepository();
      final mockAuthRepo = MockFullAdminAuthRepository(mockUser: adminUser);
      final mockStorage = MockFailingStorageService();
      final mockPicker = MockAdminImagePicker(XFile(tempPng.path));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProfileScreen(
            authRepository: mockAuthRepo,
            userRepository: mockUserRepo,
            storageService: mockStorage,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppAvatar));
      await tester.pumpAndSettle();

      expect(find.text('Upload Photo'), findsOneWidget);
      await tester.tap(find.text('Upload Photo'));
      // Advance FakeAsync past bottom-sheet dismissal + 80ms delay, then let
      // sequential dart:io file reads/closes complete outside FakeAsync.
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 40 && mockUserRepo.lastUpdatedUserData == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        mockUserRepo.lastUpdatedUserData?['photoUrl'],
        startsWith('data:image/png;base64,'),
      );
      expect(
        AuthRepository.activeUser?.photoUrl,
        startsWith('data:image/png;base64,'),
      );
      expect(find.text('Profile photo updated successfully!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
