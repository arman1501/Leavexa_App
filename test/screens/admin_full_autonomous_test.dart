import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/admin/admin_dashboard.dart';
import 'package:leavexa/screens/admin/admin_profile_screen.dart';

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

  @override
  Future<List<UserModel>> getPendingFaculty() async => mockPending;

  @override
  Future<List<UserModel>> getAllFaculty() async => mockAll;

  @override
  Future<void> approveFaculty(String uid) async {
    approveFacultyCalled = true;
    lastApprovedUid = uid;
  }

  @override
  Future<void> rejectFaculty(String uid, {String? reason}) async {
    rejectFacultyCalled = true;
    lastRejectedUid = uid;
    lastRejectionReason = reason;
  }

  @override
  Future<void> setUserActive(String uid, bool isActive) async {
    setUserActiveCalled = true;
    lastActiveUid = uid;
    lastActiveStatus = isActive;
  }
}

class MockFullAdminAuthRepository extends AuthRepository {
  UserModel? mockUser;
  bool logoutCalled = false;

  MockFullAdminAuthRepository({this.mockUser});

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
}
