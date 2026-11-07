// ─────────────────────────────────────────────────────────────────────────────
//  admin_dashboard.dart  –  Admin Dashboard Screen
//  Pixel-perfect implementation of Stitch Screen 07e86fc7dbf84e198b6a1b13fae76a59
//  Manage pending teacher registrations, credential verification & approvals
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentNavIndex = 0; // 0: Home, 1: Approvals, 2: Faculty, 3: Profile

  int _pendingCount = 12;
  int _approvedCount = 231;
  int _rejectedCount = 5;

  bool _sortNewestFirst = true;
  bool _didReadInitialTab = false;

  // Approvals Tab state
  String _approvalStatusFilter = 'ALL'; // 'ALL', 'PENDING', 'APPROVED', 'REJECTED'
  String _approvalSearchQuery = '';
  final TextEditingController _approvalSearchCtrl = TextEditingController();

  // Faculty Directory Tab state
  String _facultyDeptFilter = 'ALL';
  String _facultySearchQuery = '';
  final TextEditingController _facultySearchCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didReadInitialTab) {
      _didReadInitialTab = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['tab'] is int) {
        final tab = args['tab'] as int;
        if (tab >= 0 && tab <= 2) {
          setState(() {
            _currentNavIndex = tab;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _approvalSearchCtrl.dispose();
    _facultySearchCtrl.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _teachers = [
    {
      'id': 'T-1045',
      'name': 'Dr. Nazmul Hasan',
      'empId': 'EMP-1045',
      'department': 'Computer Science & Eng.',
      'designation': 'Assistant Professor',
      'submittedTime': 'Submitted 2h ago',
      'submittedHours': 2,
      'credentials': 'MSc & PhD Credentials Attached (PDF • 4.2 MB)',
      'avatarType': 'placeholder', // 'img' placeholder box matching stitch mockup
      'avatarColor': const Color(0xFF64748B),
      'status': 'PENDING',
      'institution': 'PhD from BUET, M.Sc from University of Melbourne',
      'nidVerified': true,
      'degrees': ['B.Sc in CSE (BUET)', 'M.Sc in CS (UniMelb)', 'Ph.D in AI/ML (BUET)'],
    },
    {
      'id': 'T-1046',
      'name': 'Farhana Akter',
      'empId': 'EMP-1046',
      'department': 'Electrical & Electronic Eng.',
      'designation': 'Lecturer',
      'submittedTime': 'Submitted 5h ago',
      'submittedHours': 5,
      'credentials': "National ID & Master's Transcript (PDF • 2.8 MB)",
      'avatarType': 'female',
      'avatarColor': const Color(0xFF0D9488),
      'status': 'PENDING',
      'institution': 'M.Sc from Dhaka University, B.Sc in EEE from RUET',
      'nidVerified': true,
      'degrees': ['B.Sc in EEE (RUET)', "M.Sc in Applied Physics (DU)"],
    },
    {
      'id': 'T-1047',
      'name': 'Mahruf Alam',
      'empId': 'EMP-1047',
      'department': 'Civil Engineering',
      'designation': 'Lecturer',
      'submittedTime': 'Submitted 1d ago',
      'submittedHours': 24,
      'credentials': 'B.Sc Certificate & IEB Accreditation (PDF • 6.1 MB)',
      'avatarType': 'male',
      'avatarColor': const Color(0xFF4F46E5),
      'status': 'PENDING',
      'institution': 'B.Sc in Civil Engineering from CUET, IEB Member #34892',
      'nidVerified': true,
      'degrees': ['B.Sc in Civil Engineering (CUET)'],
    },
    {
      'id': 'T-1048',
      'name': 'Dr. Sadia Tahsin',
      'empId': 'EMP-1048',
      'department': 'Architecture',
      'designation': 'Associate Professor',
      'submittedTime': 'Submitted 1d ago',
      'submittedHours': 26,
      'credentials': 'Doctorate Degree & Design Portfolio (PDF • 9.4 MB)',
      'avatarType': 'female',
      'avatarColor': const Color(0xFF7C3AED),
      'status': 'PENDING',
      'institution': 'Ph.D in Sustainable Architecture, NUS Singapore',
      'nidVerified': true,
      'degrees': ['B.Arch (BUET)', 'Ph.D in Architecture (NUS)'],
    },
    {
      'id': 'T-1049',
      'name': 'Engr. Tanvir Ahmed',
      'empId': 'EMP-1049',
      'department': 'Mechanical Engineering',
      'designation': 'Lecturer',
      'submittedTime': 'Submitted 2d ago',
      'submittedHours': 48,
      'credentials': 'M.Sc Degree & IEB Certification (PDF • 3.5 MB)',
      'avatarType': 'male',
      'avatarColor': const Color(0xFFEA580C),
      'status': 'PENDING',
      'institution': 'M.Sc in Mechanical Eng from IUT',
      'nidVerified': true,
      'degrees': ['B.Sc in ME (KUET)', 'M.Sc in ME (IUT)'],
    },
  ];

  final List<Map<String, dynamic>> _facultyDirectory = [
    {
      'id': 'FAC-1024',
      'name': 'Md. Arman',
      'empId': 'FAC-1024',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Lecturer',
      'email': 'arman@leavexa.edu',
      'phone': '+880 1712-345678',
      'joined': 'August 2022',
      'degrees': ['B.Sc in CSE (BUET)'],
      'institution': 'B.Sc in Computer Science & Eng. from BUET',
      'credentials': 'B.Sc Certificate & Academic Transcripts (PDF • 2.4 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'EMP-H1005',
      'name': 'Prof. Dr. Tariqul Islam',
      'empId': 'EMP-H1005',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Professor & Head of Dept.',
      'email': 'head.cse@leavexa.edu',
      'phone': '+880 1711-987654',
      'joined': 'January 2018',
      'degrees': ['B.Sc in CSE (BUET)', 'Ph.D from University of Tokyo'],
      'institution': 'Ph.D from Univ of Tokyo, Postdoc from NUS',
      'credentials': 'Doctorate Degree & Official HoD Gazetted Order (PDF • 5.1 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1011',
      'name': 'Dr. Sarah Ahmed',
      'empId': 'FAC-1011',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Assistant Professor',
      'email': 'sarah.cse@leavexa.edu',
      'phone': '+880 1713-112233',
      'joined': 'July 2020',
      'degrees': ['B.Sc in CSE (DU)', 'Ph.D in Software Eng. (Monash)'],
      'institution': 'Ph.D in Software Eng. from Monash University',
      'credentials': 'Ph.D Certificate & IEEE Senior Membership (PDF • 3.8 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1018',
      'name': 'Engr. Naila Parveen',
      'empId': 'FAC-1018',
      'department': 'Electrical & Electronic Eng.',
      'deptCode': 'EEE',
      'designation': 'Assistant Professor',
      'email': 'naila.eee@leavexa.edu',
      'phone': '+880 1714-445566',
      'joined': 'January 2021',
      'degrees': ['B.Sc in EEE (BUET)', 'M.Sc in Microelectronics (IUT)'],
      'institution': 'M.Sc from IUT, IEB Chartered Engineer',
      'credentials': 'M.Sc Degree & IEB Accreditation (PDF • 3.1 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1015',
      'name': 'Dr. Farhana Yasmin',
      'empId': 'FAC-1015',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Associate Professor',
      'email': 'farhana.ai@leavexa.edu',
      'phone': '+880 1715-778899',
      'joined': 'March 2019',
      'degrees': ['B.Sc in CSE (KUET)', 'Ph.D in AI/Robotics (KAIST)'],
      'institution': 'Ph.D in Artificial Intelligence, KAIST Korea',
      'credentials': 'Doctorate Degree & AI Lab Accreditation (PDF • 4.5 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1008',
      'name': 'Prof. M. Kamal',
      'empId': 'FAC-1008',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Professor',
      'email': 'kamal.se@leavexa.edu',
      'phone': '+880 1716-123456',
      'joined': 'January 2015',
      'degrees': ['B.Sc in CSE (BUET)', 'Ph.D from University of Cambridge'],
      'institution': 'Ph.D in Distributed Systems, Cambridge UK',
      'credentials': 'Doctorate Degree & Professorship Gazetted Records (PDF • 6.2 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1022',
      'name': 'Ms. Sadia Karim',
      'empId': 'FAC-1022',
      'department': 'Computer Science & Eng.',
      'deptCode': 'CSE',
      'designation': 'Lecturer',
      'email': 'sadia.karim@leavexa.edu',
      'phone': '+880 1717-654321',
      'joined': 'September 2023',
      'degrees': ['B.Sc in CSE (RUET)'],
      'institution': 'B.Sc in CSE (RUET), Gold Medalist',
      'credentials': 'B.Sc Degree & Gold Medal Certificate (PDF • 2.9 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1030',
      'name': 'Engr. Rafiqul Bari',
      'empId': 'FAC-1030',
      'department': 'Civil Engineering',
      'deptCode': 'Civil',
      'designation': 'Senior Lecturer',
      'email': 'rafiqul.ce@leavexa.edu',
      'phone': '+880 1718-987123',
      'joined': 'February 2021',
      'degrees': ['B.Sc in Civil Eng. (CUET)', 'M.Sc in Structural Eng. (BUET)'],
      'institution': 'M.Sc in Structural Eng from BUET',
      'credentials': 'M.Sc Degree & IEB Structural License (PDF • 4.1 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1048',
      'name': 'Dr. Sadia Tahsin',
      'empId': 'EMP-1048',
      'department': 'Architecture',
      'deptCode': 'Architecture',
      'designation': 'Associate Professor',
      'email': 'sadia.arch@leavexa.edu',
      'phone': '+880 1720-776655',
      'joined': 'October 2019',
      'degrees': ['B.Arch (BUET)', 'Ph.D in Architecture (NUS)'],
      'institution': 'Ph.D in Sustainable Architecture, NUS Singapore',
      'credentials': 'Doctorate Degree & Design Portfolio (PDF • 9.4 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
    {
      'id': 'FAC-1049',
      'name': 'Engr. Tanvir Ahmed',
      'empId': 'EMP-1049',
      'department': 'Mechanical Engineering',
      'deptCode': 'Mechanical',
      'designation': 'Lecturer',
      'email': 'tanvir.me@leavexa.edu',
      'phone': '+880 1719-334455',
      'joined': 'March 2023',
      'degrees': ['B.Sc in ME (KUET)', 'M.Sc in ME (IUT)'],
      'institution': 'M.Sc in Mechanical Eng from IUT',
      'credentials': 'M.Sc Degree & IEB Certification (PDF • 3.5 MB)',
      'nidVerified': true,
      'status': 'VERIFIED',
    },
  ];

  void _onBottomNavTap(int index) {
    if (index == 3) {
      Navigator.pushReplacementNamed(context, AppRoutes.adminProfile);
      return;
    }
    setState(() => _currentNavIndex = index);
  }

  void _onApproveTeacher(Map<String, dynamic> teacher) {
    setState(() {
      teacher['status'] = 'APPROVED';
      _pendingCount = (_pendingCount > 0) ? _pendingCount - 1 : 0;
      _approvedCount++;
    });

    AppHelpers.showSuccess(
      context,
      '${teacher['name']} has been approved and registered!',
    );
  }

  void _onRejectTeacher(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        String selectedReason = 'Incomplete documentation';
        final reasons = [
          'Incomplete documentation',
          'Unverified academic credentials',
          'NID / Identity mismatch',
          'Department criteria not satisfied',
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reject Verification',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              teacher['name'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Select Rejection Reason:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...reasons.map(
                    (r) => RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFFDC2626),
                      title: Text(
                        r,
                        style: TextStyle(fontSize: 13.5, color: textPrimary),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedReason = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              teacher['status'] = 'REJECTED';
                              _pendingCount = (_pendingCount > 0)
                                  ? _pendingCount - 1
                                  : 0;
                              _rejectedCount++;
                            });
                            AppHelpers.showError(
                              context,
                              'Registration rejected: $selectedReason',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Confirm Reject',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openInspectModal(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final boxBg =
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final borderCol =
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 22,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Credential Inspection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${teacher['empId']} • ${teacher['department']} • ${teacher['designation']}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'National ID Verified',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            teacher['institution'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Attached Documentation:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'PDF',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        teacher['credentials'] as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      onPressed: () {
                        AppHelpers.showSuccess(
                          context,
                          'Opening certificate file...',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (teacher['status'] == 'PENDING')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onRejectTeacher(teacher);
                        },
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: const Color(0xFFFEE2E2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onApproveTeacher(teacher);
                        },
                        icon: const Icon(Icons.check_rounded,
                            size: 17, color: Colors.white),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3827),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check_circle_rounded,
                        size: 18, color: Colors.white),
                    label: const Text(
                      'Verified Faculty Member • Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3827),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor =
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary =
            isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: _buildCurrentTabBody(
                isDark: isDark,
                bgColor: bgColor,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'admin',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentTabBody({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    switch (_currentNavIndex) {
      case 1:
        return _buildApprovalsView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 2:
        return _buildFacultyDirectoryView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 0:
      default:
        return _buildHomeView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
    }
  }

  // ── Reusable Top Bar for Admin Dashboard Views ─────────────────────────────
  Widget _buildTopBar({
    required String breadcrumb,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            breadcrumb,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 23,
                  color: textPrimary,
                ),
                onPressed: () {
                  AppHelpers.showSuccess(
                    context,
                    'All notifications up to date',
                  );
                },
              ),
              const SizedBox(width: 4),
              // Admin Profile Picture (profile.jpg)
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.adminProfile,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/profile.jpg',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFF1B4332),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'AD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final activeList = _teachers
        .where((t) => t['status'] == 'PENDING')
        .toList();

    if (!_sortNewestFirst) {
      activeList.sort((a, b) =>
          (b['submittedHours'] as int).compareTo(a['submittedHours'] as int));
    } else {
      activeList.sort((a, b) =>
          (a['submittedHours'] as int).compareTo(b['submittedHours'] as int));
    }

    return CustomScrollView(
      slivers: [
        // ── 1. TOP BAR (Home breadcrumb + Bell + Avatar) ───────────
        SliverToBoxAdapter(
          child: _buildTopBar(
            breadcrumb: 'Home',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

                  // ── 2. ADMIN DASHBOARD HEADING & FALL TERM PILL ───────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Admin Dashboard',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'serif',
                                  color: textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              // Fall Term 2026 Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A)
                                          .withValues(alpha: 0.35)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.3)
                                        : const Color(0xFFE0E7FF),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3B82F6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Fall Term 2026',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Manage pending teacher registrations and verify credentials.',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  // ── 3. TOP 3 STATS CARDS (Pending, Approved, Rejected) ─────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Card 1: Pending
                          Expanded(
                            child: _buildMetricCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textSecondary: textSecondary,
                              title: 'Pending',
                              dotColor: const Color(0xFFD97706),
                              value: '$_pendingCount',
                              valueColor: const Color(0xFFB45309),
                              caption: 'Needs Action',
                              captionColor: const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Card 2: Approved
                          Expanded(
                            child: _buildMetricCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textSecondary: textSecondary,
                              title: 'Approved',
                              dotColor: const Color(0xFF16A34A),
                              value: '$_approvedCount',
                              valueColor: const Color(0xFF047857),
                              caption: 'This Session',
                              captionColor: const Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Card 3: Rejected
                          Expanded(
                            child: _buildMetricCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textSecondary: textSecondary,
                              title: 'Rejected',
                              dotColor: const Color(0xFFDC2626),
                              value: '$_rejectedCount',
                              valueColor: const Color(0xFFDC2626),
                              caption: 'Archived',
                              captionColor: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 4. SECTION HEADER: "Pending Verifications" + SORT ─────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 22,
                        bottom: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pending Verifications',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_pendingCount',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _sortNewestFirst = !_sortNewestFirst;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Sort by Date',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.swap_vert_rounded,
                                  size: 18,
                                  color: textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 5. PENDING VERIFICATIONS LIST ─────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final teacher = activeList[index];
                          return _buildTeacherCard(
                            teacher: teacher,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          );
                        },
                        childCount: activeList.length,
                      ),
                    ),
                  ),

                  // ── 6. "VIEW ALL 12 PENDING REQUESTS →" BUTTON ─────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 4,
                        bottom: 24,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _currentNavIndex = 1);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE0E7FF),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View All $_pendingCount Pending Requests',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF334155),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TAB 1: APPROVALS QUEUE VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildApprovalsView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final filtered = _teachers.where((t) {
      final status = (t['status'] as String).toUpperCase();
      if (_approvalStatusFilter != 'ALL' && status != _approvalStatusFilter) {
        return false;
      }
      if (_approvalSearchQuery.isNotEmpty) {
        final name = (t['name'] as String).toLowerCase();
        final emp = (t['empId'] as String).toLowerCase();
        final dept = (t['department'] as String).toLowerCase();
        if (!name.contains(_approvalSearchQuery) &&
            !emp.contains(_approvalSearchQuery) &&
            !dept.contains(_approvalSearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // 1. Top Bar
        SliverToBoxAdapter(
          child: _buildTopBar(
            breadcrumb: 'Approvals Queue',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

        // 2. Heading & Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Approvals Queue',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'serif',
                        color: textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF451A03).withValues(alpha: 0.5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_pendingCount Pending',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Review incoming teacher registrations and approve faculty accounts.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
                const SizedBox(height: 14),

                // Search Box
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _approvalSearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _approvalSearchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by teacher name, ID, or department...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                      suffixIcon: _approvalSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                _approvalSearchCtrl.clear();
                                setState(() => _approvalSearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Status Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatusChip('ALL', 'All (${_teachers.length})', isDark),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'PENDING',
                    'Pending ($_pendingCount)',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'APPROVED',
                    'Approved (${_teachers.where((t) => t['status'] == 'APPROVED').length})',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'REJECTED',
                    'Rejected (${_teachers.where((t) => t['status'] == 'REJECTED').length})',
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. List of Teachers
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No registration requests found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try clearing the search query or status filter.',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final teacher = filtered[index];
                  return _buildTeacherCard(
                    teacher: teacher,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String statusKey, String label, bool isDark) {
    final isSelected = _approvalStatusFilter == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _approvalStatusFilter = statusKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TAB 2: VERIFIED FACULTY DIRECTORY VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFacultyDirectoryView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final filtered = _facultyDirectory.where((f) {
      final deptCode = (f['deptCode'] as String? ?? '').toUpperCase();
      if (_facultyDeptFilter != 'ALL' &&
          deptCode != _facultyDeptFilter.toUpperCase()) {
        return false;
      }
      if (_facultySearchQuery.isNotEmpty) {
        final name = (f['name'] as String).toLowerCase();
        final emp = (f['empId'] as String).toLowerCase();
        final dept = (f['department'] as String).toLowerCase();
        if (!name.contains(_facultySearchQuery) &&
            !emp.contains(_facultySearchQuery) &&
            !dept.contains(_facultySearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // 1. Top Bar
        SliverToBoxAdapter(
          child: _buildTopBar(
            breadcrumb: 'Faculty Directory',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

        // 2. Heading & Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Faculty Directory',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'serif',
                        color: textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_facultyDirectory.length} Verified',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse registered faculty members across university departments.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
                const SizedBox(height: 14),

                // Search Box
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _facultySearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _facultySearchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search faculty by name, ID or department...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                      suffixIcon: _facultySearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                _facultySearchCtrl.clear();
                                setState(() => _facultySearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Department Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildDeptChip('ALL', 'All Departments', isDark),
                  const SizedBox(width: 8),
                  _buildDeptChip('CSE', 'CSE', isDark),
                  const SizedBox(width: 8),
                  _buildDeptChip('EEE', 'EEE', isDark),
                  const SizedBox(width: 8),
                  _buildDeptChip('Civil', 'Civil', isDark),
                  const SizedBox(width: 8),
                  _buildDeptChip('Architecture', 'Architecture', isDark),
                  const SizedBox(width: 8),
                  _buildDeptChip('Mechanical', 'Mechanical', isDark),
                ],
              ),
            ),
          ),
        ),

        // 4. Faculty List
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No faculty members found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try choosing another department or clearing search query.',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final faculty = filtered[index];
                  return _buildFacultyCard(
                    faculty: faculty,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeptChip(String deptKey, String label, bool isDark) {
    final isSelected = _facultyDeptFilter == deptKey;
    return GestureDetector(
      onTap: () => setState(() => _facultyDeptFilter = deptKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FACULTY DIRECTORY CARD WIDGET
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFacultyCard({
    required Map<String, dynamic> faculty,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(faculty, isDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            faculty['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 11,
                                color: Color(0xFF16A34A),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${faculty['empId']} • ${faculty['department']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 12,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                faculty['designation'] as String,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Joined ${faculty['joined']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 15,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    faculty['institution'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _openInspectModal(faculty),
                  child: Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.email_outlined, size: 13, color: textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  faculty['email'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.phone_outlined, size: 13, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                faculty['phone'] as String,
                style: TextStyle(fontSize: 11.5, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  METRIC CARD (Top 3 summary blocks)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMetricCard({
    required Color cardBg,
    required Color borderColor,
    required Color textSecondary,
    required String title,
    required Color dotColor,
    required String value,
    required Color valueColor,
    required String caption,
    required Color captionColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: captionColor,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TEACHER CARD (Pending Verification Item)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTeacherCard({
    required Map<String, dynamic> teacher,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Avatar (2-Letter Initials) + Info + PENDING Badge ───────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with 2-letter initials
              _buildAvatar(teacher, isDark),
              const SizedBox(width: 10),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & PENDING badge on same line
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            teacher['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // PENDING Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF451A03).withValues(alpha: 0.5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${teacher['empId']} • ${teacher['department']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Wrap designation & submitted time to NEVER overflow
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Green pill: 🎓 Assistant Professor / Lecturer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 12.5,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                teacher['designation'] as String,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          teacher['submittedTime'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Middle Row: Credential Box with Shield & Inspect Button ────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: Color(0xFF475569),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacher['credentials'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openInspectModal(teacher),
                  child: Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Action Buttons: [ ✕ Reject ]   [ ✓ Approve ] ───────────────────
          Row(
            children: [
              // Reject Button (Soft Pink/Red)
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => _onRejectTeacher(teacher),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF450A0A)
                          : const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFDC2626),
                      elevation: 0,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFFFECACA),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Approve Button (Dark Forest Green)
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => _onApproveTeacher(teacher),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 17),
                        SizedBox(width: 6),
                        Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Avatar Widget matching Stitch mockup
  String _getInitials(String name) {
    // Strip prefixes: Dr., Engr., Prof., Mr., Ms., Mrs., Md.
    final clean = name
        .replaceAll(
            RegExp(r'^(Dr\.|Engr\.|Prof\.|Mr\.|Ms\.|Mrs\.|Md\.)\s*',
                caseSensitive: false),
            '')
        .trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0][0].toUpperCase();
    }
    return 'TC';
  }

  // 2-Letter Initials Avatar Widget (as requested)
  Widget _buildAvatar(Map<String, dynamic> teacher, bool isDark) {
    final name = teacher['name'] as String;
    final initials = _getInitials(name);

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (name.contains('Nazmul')) {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
      textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    } else if (name.contains('Farhana')) {
      bgColor = isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1);
      textColor = isDark ? const Color(0xFF99F6E4) : const Color(0xFF0F766E);
      borderColor = isDark ? const Color(0xFF115E59) : const Color(0xFF99F6E4);
    } else if (name.contains('Mahruf')) {
      bgColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
      textColor = isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA);
      borderColor = isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE);
    } else if (name.contains('Sadia')) {
      bgColor = isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF);
      textColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE);
      borderColor = isDark ? const Color(0xFF6B21A8) : const Color(0xFFDDD6FE);
    } else {
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      textColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      borderColor = isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
