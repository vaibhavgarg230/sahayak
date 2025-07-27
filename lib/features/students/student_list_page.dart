import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/student_data_service.dart';
import '../../services/auth_service.dart';
import 'student_form_page.dart';
import 'attendance_page.dart';
import 'score_entry_page.dart';

class StudentListPage extends StatefulWidget {
  final String grade;
  final String subject;

  const StudentListPage({
    super.key,
    required this.grade,
    required this.subject,
  });

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final StudentDataService _studentService = StudentDataService();
  final AuthService _authService = AuthService();
  
  List<Student> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'rollNumber', 'age'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId != null) {
        final students = await _studentService.getStudents(
          teacherId,
          widget.grade,
          widget.subject,
        );
        
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load students: $e');
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

  List<Student> get _filteredAndSortedStudents {
    var filtered = _students.where((student) {
      final query = _searchQuery.toLowerCase();
      return student.name.toLowerCase().contains(query) ||
             student.rollNumber.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'rollNumber':
          comparison = a.rollNumber.compareTo(b.rollNumber);
          break;
        case 'age':
          comparison = a.age.compareTo(b.age);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<void> _addStudent() async {
    final result = await Navigator.push<Student>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormPage(
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );

    if (result != null) {
      await _loadStudents();
      _showSuccessSnackBar('Student added successfully!');
    }
  }

  Future<void> _editStudent(Student student) async {
    final result = await Navigator.push<Student>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentFormPage(
          student: student,
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );

    if (result != null) {
      await _loadStudents();
      _showSuccessSnackBar('Student updated successfully!');
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _studentService.deleteStudent(student.id);
        await _loadStudents();
        _showSuccessSnackBar('Student deleted successfully!');
      } catch (e) {
        _showErrorSnackBar('Failed to delete student: $e');
      }
    }
  }

  void _openAttendancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendancePage(
          students: _students,
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );
  }

  void _openScoreEntryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreEntryPage(
          students: _students,
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.grade} - ${widget.subject}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.event_available),
            onPressed: _openAttendancePage,
            tooltip: 'Mark Attendance',
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: _openScoreEntryPage,
            tooltip: 'Enter Scores',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Stats Bar
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
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Total Students', _students.length.toString(), Icons.people),
                    _buildStatCard('Present Today', _getPresentTodayCount().toString(), Icons.check_circle),
                    _buildStatCard('Average Score', '${_getAverageScore().toStringAsFixed(1)}%', Icons.trending_up),
                  ],
                ),
              ],
            ),
          ),
          
          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAndSortedStudents.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadStudents,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredAndSortedStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredAndSortedStudents[index];
                            return _buildStudentCard(student);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[600], size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
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
            'Add your first student to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addStudent,
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Roll No: ${student.rollNumber} • Age: ${student.age} • ${student.gender}'),
            if (student.parentContact != null)
              Text('Contact: ${student.parentContact}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editStudent(student);
                break;
              case 'delete':
                _deleteStudent(student);
                break;
              case 'attendance':
                _openStudentAttendance(student);
                break;
              case 'scores':
                _openStudentScores(student);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
                         const PopupMenuItem(
               value: 'attendance',
               child: Row(
                 children: [
                   Icon(Icons.event_available, size: 20),
                   SizedBox(width: 8),
                   Text('Attendance'),
                 ],
               ),
             ),
            const PopupMenuItem(
              value: 'scores',
              child: Row(
                children: [
                  Icon(Icons.assessment, size: 20),
                  SizedBox(width: 8),
                  Text('Scores'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Roll Number'),
              value: 'rollNumber',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Age'),
              value: 'age',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Ascending Order'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() {
                  _sortAscending = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openStudentAttendance(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendancePage(
          students: [student],
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );
  }

  void _openStudentScores(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreEntryPage(
          students: [student],
          grade: widget.grade,
          subject: widget.subject,
        ),
      ),
    );
  }

  int _getPresentTodayCount() {
    // This would be implemented with actual attendance data
    // For now, return a placeholder
    return _students.length > 0 ? (_students.length * 0.85).round() : 0;
  }

  double _getAverageScore() {
    // This would be implemented with actual score data
    // For now, return a placeholder
    return 75.0;
  }
} 