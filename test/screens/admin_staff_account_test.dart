import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/admin/admin_dashboard.dart';

class MockAdminUserRepository extends UserRepository {
  bool createStaffCalled = false;
  Map<String, dynamic>? lastCreatedStaff;
  bool setUserActiveCalled = false;
  String? lastActiveUid;
  bool? lastActiveStatus;
  bool shouldThrowOnCreate = false;

  List<UserModel> mockPending = [];
  List<UserModel> mockAll = [];

  @override
  Future<List<UserModel>> getPendingFaculty() async => mockPending;

  @override
  Future<List<UserModel>> getAllFaculty() async => mockAll;

  @override
  Future<Map<String, dynamic>> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String role,
    String? departmentId,
    String? departmentName,
    String? designation,
    String? phone,
  }) async {
    if (shouldThrowOnCreate) {
      throw Exception('already-exists: Employee ID already registered.');
    }
    createStaffCalled = true;
    lastCreatedStaff = {
      'email': email,
      'password': password,
      'fullName': fullName,
      'employeeId': employeeId,
      'role': role,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'designation': designation,
      'phone': phone,
    };
    return {'success': true, 'uid': 'staff_new_uid_99'};
  }

  @override
  Future<void> setUserActive(String uid, bool isActive) async {
    setUserActiveCalled = true;
    lastActiveUid = uid;
    lastActiveStatus = isActive;
  }
}

void main() {
  UserModel createFacultyUser({
    required String uid,
    required String name,
    required String empId,
    bool isActive = true,
  }) {
    return UserModel(
      uid: uid,
      email: '$empId@leavexa.edu',
      fullName: name,
      employeeId: empId,
      role: 'faculty',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Assistant Professor',
      approvalStatus: 'approved',
      isActive: isActive,
      createdAt: DateTime.now(),
    );
  }

  testWidgets('Create Staff Account button is displayed on Admin Dashboard',
      (tester) async {
    final mockRepo = MockAdminUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create_staff_account_button')), findsOneWidget);
  });

  testWidgets(
      'Opening modal and submitting empty fields triggers validation errors',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = MockAdminUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    // Open modal
    await tester.tap(find.byKey(const Key('create_staff_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Staff Account'), findsOneWidget);
    expect(find.byKey(const Key('submit_create_staff_button')), findsOneWidget);

    // Tap create without filling fields
    await tester.tap(find.byKey(const Key('submit_create_staff_button')));
    await tester.pumpAndSettle();

    expect(find.text('Full Name is required'), findsOneWidget);
    expect(find.text('Employee ID is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(mockRepo.createStaffCalled, isFalse);
  });

  testWidgets('Validation enforces valid email and password min length 8',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = MockAdminUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_staff_account_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('staff_name_field')), 'Dr. Tariqul Islam');
    await tester.enterText(
        find.byKey(const Key('staff_empid_field')), 'EMP-H101');
    await tester.enterText(
        find.byKey(const Key('staff_email_field')), 'invalid-email-format');
    await tester.enterText(
        find.byKey(const Key('staff_password_field')), '12345'); // < 8 chars
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_create_staff_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(mockRepo.createStaffCalled, isFalse);
  });

  testWidgets(
      'Creating Department Head provisions correct role, dept, and credentials',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = MockAdminUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_staff_account_button')));
    await tester.pumpAndSettle();

    // Default role is department_head, so dept dropdown is present
    expect(find.byKey(const Key('staff_dept_dropdown')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('staff_name_field')), 'Prof. Dr. Tariqul Islam');
    await tester.enterText(
        find.byKey(const Key('staff_empid_field')), 'EMP-H101');
    await tester.enterText(
        find.byKey(const Key('staff_email_field')), 'head.cse@leavexa.edu');
    await tester.enterText(
        find.byKey(const Key('staff_password_field')), 'Password123#');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_create_staff_button')));
    await tester.pumpAndSettle();

    expect(mockRepo.createStaffCalled, isTrue);
    expect(mockRepo.lastCreatedStaff?['role'], 'department_head');
    expect(mockRepo.lastCreatedStaff?['fullName'], 'Prof. Dr. Tariqul Islam');
    expect(mockRepo.lastCreatedStaff?['employeeId'], 'EMP-H101');
    expect(mockRepo.lastCreatedStaff?['email'], 'head.cse@leavexa.edu');
    expect(mockRepo.lastCreatedStaff?['departmentId'], 'dept_cse');
    expect(find.textContaining('created successfully'), findsOneWidget);
  });

  testWidgets(
      'Selecting Registrar role hides Department dropdown and creates registrar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = MockAdminUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_staff_account_button')));
    await tester.pumpAndSettle();

    // Switch to Registrar
    await tester.tap(find.byKey(const Key('role_registrar_chip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staff_dept_dropdown')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('staff_name_field')), 'Dr. Mostafa Kamal');
    await tester.enterText(
        find.byKey(const Key('staff_empid_field')), 'EMP-R201');
    await tester.enterText(
        find.byKey(const Key('staff_email_field')), 'registrar@leavexa.edu');
    await tester.enterText(
        find.byKey(const Key('staff_password_field')), 'RegistrarSecret123');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_create_staff_button')));
    await tester.pumpAndSettle();

    expect(mockRepo.createStaffCalled, isTrue);
    expect(mockRepo.lastCreatedStaff?['role'], 'registrar');
    expect(mockRepo.lastCreatedStaff?['departmentId'], isNull);
    expect(mockRepo.lastCreatedStaff?['email'], 'registrar@leavexa.edu');
  });

  testWidgets('Handles duplicate employee ID error gracefully',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = MockAdminUserRepository();
    mockRepo.shouldThrowOnCreate = true;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_staff_account_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('staff_name_field')), 'Existing Staff');
    await tester.enterText(
        find.byKey(const Key('staff_empid_field')), 'EMP-DUPLICATE');
    await tester.enterText(
        find.byKey(const Key('staff_email_field')), 'dup@leavexa.edu');
    await tester.enterText(
        find.byKey(const Key('staff_password_field')), 'SecretPass123');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_create_staff_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('already registered'), findsOneWidget);
  });

  testWidgets('Faculty Directory card active toggle calls setUserActive',
      (tester) async {
    final mockRepo = MockAdminUserRepository();
    final facultyUser = createFacultyUser(
      uid: 'user_target_456',
      name: 'Dr. Sarah Ahmed',
      empId: 'FAC-1011',
      isActive: true,
    );
    mockRepo.mockAll = [facultyUser];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboard(userRepository: mockRepo),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Faculty Directory tab (bottom nav index 2)
    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    // Verify ACTIVE toggle chip exists
    final toggleKey = find.byKey(const Key('toggle_active_user_target_456'));
    expect(toggleKey, findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Tap toggle to deactivate
    await tester.tap(toggleKey);
    await tester.pumpAndSettle();

    expect(mockRepo.setUserActiveCalled, isTrue);
    expect(mockRepo.lastActiveUid, 'user_target_456');
    expect(mockRepo.lastActiveStatus, false);
    expect(find.text('INACTIVE'), findsOneWidget);
  });
}
