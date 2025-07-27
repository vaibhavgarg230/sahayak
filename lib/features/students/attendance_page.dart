import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/attendance_record.dart';
import '../../services/student_data_service.dart';
import '../../services/auth_service.dart';

class AttendancePage extends StatefulWidget {
  final List<Student> students;
  final String grade;
  final String subject;

  const AttendancePage({
    super.key,
    required this.students,
    required this.grade,
    required this.subject,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final StudentDataService _studentService = StudentDataService();
  final AuthService _authService = AuthService();
  
  DateTime _selectedDate = DateTime.now();
  Map<String, AttendanceStatus> _attendanceMap = {};
  Map<String, AttendanceRecord?> _existingAttendance = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeAttendance();
  }

  Future<void> _initializeAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize all students as present by default
      for (var student in widget.students) {
        _attendanceMap[student.id] = AttendanceStatus.present;
      }

      // Load existing attendance for the selected date
      await _loadExistingAttendance();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load attendance: $e');
    }
  }

  Future<void> _loadExistingAttendance() async {
    for (var student in widget.students) {
      final existingRecord = await _studentService.getAttendance(student.id, _selectedDate);
      if (existingRecord != null) {
        _attendanceMap[student.id] = existingRecord.status;
        _existingAttendance[student.id] = existingRecord;
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      
      // Clear current attendance and load for new date
      _attendanceMap.clear();
      _existingAttendance.clear();
      
      for (var student in widget.students) {
        _attendanceMap[student.id] = AttendanceStatus.present;
      }
      
      await _loadExistingAttendance();
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateAttendance(String studentId, AttendanceStatus status) {
    setState(() {
      _attendanceMap[studentId] = status;
    });
  }

  Future<void> _saveAttendance() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        throw Exception('No authenticated user');
      }

      for (var student in widget.students) {
        final status = _attendanceMap[student.id] ?? AttendanceStatus.present;
        final existingRecord = _existingAttendance[student.id];
        
        final attendanceRecord = AttendanceRecord(
          id: existingRecord?.id ?? _studentService.generateId(),
          studentId: student.id,
          teacherId: teacherId,
          grade: widget.grade,
          subject: widget.subject,
          date: _selectedDate,
          status: status,
          createdAt: existingRecord?.createdAt ?? DateTime.now(),
        );

        await _studentService.markAttendance(attendanceRecord);
      }

      if (mounted) {
        _showSuccessSnackBar('Attendance saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('Failed to save attendance: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, int> get _attendanceStats {
    final stats = <String, int>{
      'present': 0,
      'absent': 0,
      'tardy': 0,
      'excused': 0,
    };

    for (var status in _attendanceMap.values) {
      stats[status.name] = (stats[status.name] ?? 0) + 1;
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header with Date and Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Date Selector
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down, color: Colors.blue[600]),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Attendance Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Present', _attendanceStats['present']?.toString() ?? '0', 
                        AttendanceStatus.present, Colors.green),
                    _buildStatCard('Absent', _attendanceStats['absent']?.toString() ?? '0', 
                        AttendanceStatus.absent, Colors.red),
                    _buildStatCard('Tardy', _attendanceStats['tardy']?.toString() ?? '0', 
                        AttendanceStatus.tardy, Colors.orange),
                    _buildStatCard('Excused', _attendanceStats['excused']?.toString() ?? '0', 
                        AttendanceStatus.excused, Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          
          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.students.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.students.length,
                        itemBuilder: (context, index) {
                          final student = widget.students[index];
                          return _buildStudentAttendanceCard(student);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Attendance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, AttendanceStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            AttendanceRecord.getStatusIcon(status),
            style: TextStyle(
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add students to this class to mark attendance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceCard(Student student) {
    final currentStatus = _attendanceMap[student.id] ?? AttendanceStatus.present;
    final statusColor = AttendanceRecord.getStatusColor(currentStatus);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Student Avatar
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Roll No: ${student.rollNumber} • Age: ${student.age}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Attendance Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(statusColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(statusColor)),
              ),
              child: Text(
                AttendanceRecord.getStatusIcon(currentStatus),
                style: TextStyle(
                  fontSize: 18,
                  color: Color(statusColor),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Attendance Options
            PopupMenuButton<AttendanceStatus>(
              onSelected: (status) => _updateAttendance(student.id, status),
              itemBuilder: (context) => AttendanceStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Text(
                        AttendanceRecord.getStatusIcon(status),
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(AttendanceRecord.getStatusColor(status)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.name.toUpperCase()),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 