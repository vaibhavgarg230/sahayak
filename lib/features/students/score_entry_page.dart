import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/performance_score.dart';
import '../../services/student_data_service.dart';
import '../../services/auth_service.dart';

class ScoreEntryPage extends StatefulWidget {
  final List<Student> students;
  final String grade;
  final String subject;

  const ScoreEntryPage({
    super.key,
    required this.students,
    required this.grade,
    required this.subject,
  });

  @override
  State<ScoreEntryPage> createState() => _ScoreEntryPageState();
}

class _ScoreEntryPageState extends State<ScoreEntryPage> {
  final StudentDataService _studentService = StudentDataService();
  final AuthService _authService = AuthService();
  
  final _testNameController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _notesController = TextEditingController();
  
  Map<String, TextEditingController> _scoreControllers = {};
  DateTime _testDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeScoreControllers();
    _maxScoreController.text = '100'; // Default max score
  }

  void _initializeScoreControllers() {
    _scoreControllers.clear();
    for (var student in widget.students) {
      _scoreControllers[student.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _maxScoreController.dispose();
    _notesController.dispose();
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        _testDate = picked;
      });
    }
  }

  Future<void> _saveScores() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        throw Exception('No authenticated user');
      }

      final maxScore = double.parse(_maxScoreController.text.trim());
      final testName = _testNameController.text.trim();
      final notes = _notesController.text.trim();

      for (var student in widget.students) {
        final scoreText = _scoreControllers[student.id]?.text.trim();
        if (scoreText != null && scoreText.isNotEmpty) {
          final score = double.parse(scoreText);
          
          final performanceScore = PerformanceScore(
            id: _studentService.generateId(),
            studentId: student.id,
            teacherId: teacherId,
            grade: widget.grade,
            subject: widget.subject,
            testName: testName,
            score: score,
            maxScore: maxScore,
            testDate: _testDate,
            notes: notes.isEmpty ? null : notes,
            createdAt: DateTime.now(),
          );

          await _studentService.addScore(performanceScore);
        }
      }

      if (mounted) {
        _showSuccessSnackBar('Scores saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('Failed to save scores: $e');
    }
  }

  bool _validateForm() {
    if (_testNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter test name');
      return false;
    }

    if (_maxScoreController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter maximum score');
      return false;
    }

    final maxScore = double.tryParse(_maxScoreController.text.trim());
    if (maxScore == null || maxScore <= 0) {
      _showErrorSnackBar('Please enter a valid maximum score');
      return false;
    }

    bool hasAtLeastOneScore = false;
    for (var controller in _scoreControllers.values) {
      if (controller.text.trim().isNotEmpty) {
        hasAtLeastOneScore = true;
        final score = double.tryParse(controller.text.trim());
        if (score == null || score < 0 || score > maxScore) {
          _showErrorSnackBar('Please enter valid scores between 0 and $maxScore');
          return false;
        }
      }
    }

    if (!hasAtLeastOneScore) {
      _showErrorSnackBar('Please enter at least one score');
      return false;
    }

    return true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Enter Test Scores'),
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
          // Header with Test Info
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
                // Test Name
                TextFormField(
                  controller: _testNameController,
                  decoration: InputDecoration(
                    labelText: 'Test Name *',
                    hintText: 'e.g., Unit Test 1, Midterm Exam',
                    prefixIcon: const Icon(Icons.assignment),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Date and Max Score Row
                Row(
                  children: [
                    // Date Selector
                    Expanded(
                      child: InkWell(
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
                                'Date: ${_testDate.toLocal().toString().split(' ')[0]}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Max Score
                    Expanded(
                      child: TextFormField(
                        controller: _maxScoreController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Max Score *',
                          hintText: '100',
                          prefixIcon: const Icon(Icons.score),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any additional notes about the test...',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ],
            ),
          ),
          
          // Students List with Score Inputs
          Expanded(
            child: widget.students.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.students.length,
                    itemBuilder: (context, index) {
                      final student = widget.students[index];
                      return _buildStudentScoreCard(student);
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
            onPressed: _isSaving ? null : _saveScores,
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
                    'Save Scores',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
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
            'Add students to this class to enter scores',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentScoreCard(Student student) {
    final scoreController = _scoreControllers[student.id]!;
    final maxScore = double.tryParse(_maxScoreController.text.trim()) ?? 100.0;
    
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
            
            // Score Input
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: scoreController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Score',
                  hintText: '0-$maxScore',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                onChanged: (value) {
                  // Show percentage if score is entered
                  if (value.isNotEmpty) {
                    final score = double.tryParse(value);
                    if (score != null && maxScore > 0) {
                      final percentage = (score / maxScore) * 100;
                      // You could show this as a tooltip or in a separate field
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 