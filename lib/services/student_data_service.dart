import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/performance_score.dart';

class StudentDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Hive box names for offline caching
  static const String _studentsBox = 'students_cache';
  static const String _attendanceBox = 'attendance_cache';
  static const String _scoresBox = 'scores_cache';
  static const String _offlineQueueBox = 'offline_queue';
  
  // Stream controllers for real-time updates
  final StreamController<List<Student>> _studentsController = 
      StreamController<List<Student>>.broadcast();
  final StreamController<List<AttendanceRecord>> _attendanceController = 
      StreamController<List<AttendanceRecord>>.broadcast();
  final StreamController<List<PerformanceScore>> _scoresController = 
      StreamController<List<PerformanceScore>>.broadcast();

  StudentDataService() {
    _initHive();
  }

  // Initialize Hive for offline caching
  Future<void> _initHive() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    
    await Hive.openBox(_studentsBox);
    await Hive.openBox(_attendanceBox);
    await Hive.openBox(_scoresBox);
    await Hive.openBox(_offlineQueueBox);
  }

  // Safe Firestore document update - creates if doesn't exist
  Future<void> _safeUpdateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      final docRef = _firestore.collection(collection).doc(docId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        print('[StudentDataService] Updating existing document: $collection/$docId');
        await docRef.update(data);
      } else {
        print('[StudentDataService] Creating new document: $collection/$docId');
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('[StudentDataService] Safe document update failed for $collection/$docId: $e');
      throw Exception('Document operation failed: $e');
    }
  }

  // Queue offline operation for later sync
  Future<void> _queueOfflineOperation(String operation, Map<String, dynamic> data) async {
    final box = await Hive.openBox(_offlineQueueBox);
    final operationData = {
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await box.add(operationData);
  }

  // Sync offline operations when back online
  Future<void> syncOfflineOperations() async {
    try {
      final box = await Hive.openBox(_offlineQueueBox);
      final operations = box.values.toList();
      
      for (var operation in operations) {
        try {
          final operationData = operation as Map<String, dynamic>;
          final operationType = operationData['operation'] as String;
          final data = operationData['data'] as Map<String, dynamic>;
          
          switch (operationType) {
            case 'addStudent':
              await _addStudentToFirestore(data);
              break;
            case 'updateStudent':
              await _updateStudentInFirestore(data);
              break;
            case 'deleteStudent':
              await _deleteStudentFromFirestore(data);
              break;
            case 'addAttendance':
              await _addAttendanceToFirestore(data);
              break;
            case 'addScore':
              await _addScoreToFirestore(data);
              break;
          }
          
          // Remove successful operation from queue
          await box.delete(operation);
        } catch (e) {
          print('[StudentDataService] Failed to sync operation: $e');
        }
      }
    } catch (e) {
      print('[StudentDataService] Error syncing offline operations: $e');
    }
  }

  // ==================== STUDENT CRUD OPERATIONS ====================

  // Add new student
  Future<void> addStudent(Student student) async {
    try {
      // Add to Firestore
      await _firestore.collection('students').doc(student.id).set(student.toMap());
      
      // Cache locally
      await _cacheStudent(student);
      
      // Notify listeners
      _notifyStudentsChanged();
    } catch (e) {
      print('[StudentDataService] Error adding student: $e');
      // Queue for offline sync
      await _queueOfflineOperation('addStudent', student.toMap());
      // Cache locally anyway
      await _cacheStudent(student);
      _notifyStudentsChanged();
    }
  }

  // Update student
  Future<void> updateStudent(Student student) async {
    try {
      // Update in Firestore
      await _safeUpdateDocument('students', student.id, student.toMap());
      
      // Update cache
      await _cacheStudent(student);
      
      // Notify listeners
      _notifyStudentsChanged();
    } catch (e) {
      print('[StudentDataService] Error updating student: $e');
      // Queue for offline sync
      await _queueOfflineOperation('updateStudent', student.toMap());
      // Update cache anyway
      await _cacheStudent(student);
      _notifyStudentsChanged();
    }
  }

  // Delete student
  Future<void> deleteStudent(String studentId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('students').doc(studentId).delete();
      
      // Remove from cache
      await _removeStudentFromCache(studentId);
      
      // Notify listeners
      _notifyStudentsChanged();
    } catch (e) {
      print('[StudentDataService] Error deleting student: $e');
      // Queue for offline sync
      await _queueOfflineOperation('deleteStudent', {'id': studentId});
      // Remove from cache anyway
      await _removeStudentFromCache(studentId);
      _notifyStudentsChanged();
    }
  }

  // Get students for teacher/grade/subject
  Future<List<Student>> getStudents(String teacherId, String grade, String subject) async {
    try {
      // Try Firestore first
      final snapshot = await _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .where('grade', isEqualTo: grade)
          .where('subject', isEqualTo: subject)
          .get();

      final students = snapshot.docs
          .map((doc) => Student.fromMap(doc.data(), doc.id))
          .toList();

      // Cache results
      for (var student in students) {
        await _cacheStudent(student);
      }

      return students;
    } catch (e) {
      print('[StudentDataService] Error fetching students: $e');
      // Return from cache
      return await _getStudentsFromCache(teacherId, grade, subject);
    }
  }

  // Stream of students for real-time updates
  Stream<List<Student>> getStudentsStream(String teacherId, String grade, String subject) {
    return _studentsController.stream.where((students) =>
        students.any((student) =>
            student.teacherId == teacherId &&
            student.grade == grade &&
            student.subject == subject));
  }

  // ==================== ATTENDANCE OPERATIONS ====================

  // Mark attendance for a student
  Future<void> markAttendance(AttendanceRecord attendance) async {
    try {
      // Add to Firestore
      await _firestore.collection('attendance').doc(attendance.id).set(attendance.toMap());
      
      // Cache locally
      await _cacheAttendance(attendance);
      
      // Notify listeners
      _notifyAttendanceChanged();
    } catch (e) {
      print('[StudentDataService] Error marking attendance: $e');
      // Queue for offline sync
      await _queueOfflineOperation('addAttendance', attendance.toMap());
      // Cache locally anyway
      await _cacheAttendance(attendance);
      _notifyAttendanceChanged();
    }
  }

  // Get attendance for a student on a specific date
  Future<AttendanceRecord?> getAttendance(String studentId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final record = AttendanceRecord.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        await _cacheAttendance(record);
        return record;
      }
      return null;
    } catch (e) {
      print('[StudentDataService] Error fetching attendance: $e');
      return await _getAttendanceFromCache(studentId, date);
    }
  }

  // Get attendance history for a student
  Future<List<AttendanceRecord>> getAttendanceHistory(String studentId, {int days = 30}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data(), doc.id))
          .toList();

      // Cache results
      for (var record in records) {
        await _cacheAttendance(record);
      }

      return records;
    } catch (e) {
      print('[StudentDataService] Error fetching attendance history: $e');
      return await _getAttendanceHistoryFromCache(studentId, days);
    }
  }

  // ==================== PERFORMANCE SCORE OPERATIONS ====================

  // Add performance score
  Future<void> addScore(PerformanceScore score) async {
    try {
      // Add to Firestore
      await _firestore.collection('performance_scores').doc(score.id).set(score.toMap());
      
      // Cache locally
      await _cacheScore(score);
      
      // Notify listeners
      _notifyScoresChanged();
    } catch (e) {
      print('[StudentDataService] Error adding score: $e');
      // Queue for offline sync
      await _queueOfflineOperation('addScore', score.toMap());
      // Cache locally anyway
      await _cacheScore(score);
      _notifyScoresChanged();
    }
  }

  // Get scores for a student
  Future<List<PerformanceScore>> getStudentScores(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('performance_scores')
          .where('studentId', isEqualTo: studentId)
          .orderBy('testDate', descending: true)
          .get();

      final scores = snapshot.docs
          .map((doc) => PerformanceScore.fromMap(doc.data(), doc.id))
          .toList();

      // Cache results
      for (var score in scores) {
        await _cacheScore(score);
      }

      return scores;
    } catch (e) {
      print('[StudentDataService] Error fetching scores: $e');
      return await _getScoresFromCache(studentId);
    }
  }

  // Get average score for a student
  Future<double> getStudentAverageScore(String studentId) async {
    final scores = await getStudentScores(studentId);
    if (scores.isEmpty) return 0.0;
    
    final totalPercentage = scores.fold(0.0, (sum, score) => sum + score.percentage);
    return totalPercentage / scores.length;
  }

  // ==================== CACHE OPERATIONS ====================

  // Cache student
  Future<void> _cacheStudent(Student student) async {
    try {
      final box = await Hive.openBox(_studentsBox);
      final key = '${student.teacherId}_${student.grade}_${student.subject}_${student.id}';
      
      // Convert Firestore Timestamps to DateTime for Hive storage
      final cacheData = Map<String, dynamic>.from(student.toMap());
      if (cacheData['createdAt'] is Timestamp) {
        cacheData['createdAt'] = (cacheData['createdAt'] as Timestamp).toDate().toIso8601String();
      } else if (cacheData['createdAt'] is DateTime) {
        cacheData['createdAt'] = (cacheData['createdAt'] as DateTime).toIso8601String();
      }
      if (cacheData['lastUpdated'] is Timestamp) {
        cacheData['lastUpdated'] = (cacheData['lastUpdated'] as Timestamp).toDate().toIso8601String();
      } else if (cacheData['lastUpdated'] is DateTime) {
        cacheData['lastUpdated'] = (cacheData['lastUpdated'] as DateTime).toIso8601String();
      }
      
      await box.put(key, cacheData);
    } catch (e) {
      print('[StudentDataService] Error caching student: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  // Get students from cache
  Future<List<Student>> _getStudentsFromCache(String teacherId, String grade, String subject) async {
    try {
      final box = await Hive.openBox(_studentsBox);
      final prefix = '${teacherId}_${grade}_${subject}_';
      final students = <Student>[];

      for (var key in box.keys) {
        if (key.toString().startsWith(prefix)) {
          final cachedData = box.get(key);
          
          if (cachedData is Map) {
            try {
              final data = Map<String, dynamic>.from(cachedData);
              
              // Convert DateTime strings back to DateTime objects if needed
              if (data['createdAt'] is String) {
                try {
                  data['createdAt'] = DateTime.parse(data['createdAt'] as String);
                } catch (e) {
                  print('[StudentDataService] Error parsing student createdAt: $e');
                  data['createdAt'] = DateTime.now();
                }
              }
              if (data['lastUpdated'] is String) {
                try {
                  data['lastUpdated'] = DateTime.parse(data['lastUpdated'] as String);
                } catch (e) {
                  print('[StudentDataService] Error parsing student lastUpdated: $e');
                  data['lastUpdated'] = DateTime.now();
                }
              }
              
              students.add(Student.fromMap(data, data['id'] as String));
            } catch (e) {
              print('[StudentDataService] Error converting cached student data: $e');
            }
          }
        }
      }

      return students;
    } catch (e) {
      print('[StudentDataService] Error retrieving students from cache: $e');
      return [];
    }
  }

  // Remove student from cache
  Future<void> _removeStudentFromCache(String studentId) async {
    try {
      final box = await Hive.openBox(_studentsBox);
      final keysToRemove = <String>[];

      for (var key in box.keys) {
        final cachedData = box.get(key);
        
        if (cachedData is Map) {
          try {
            final data = Map<String, dynamic>.from(cachedData);
            if (data['id'] == studentId) {
              keysToRemove.add(key.toString());
            }
          } catch (e) {
            print('[StudentDataService] Error checking cached student data for removal: $e');
          }
        }
      }

      for (var key in keysToRemove) {
        await box.delete(key);
      }
    } catch (e) {
      print('[StudentDataService] Error removing student from cache: $e');
      // Don't throw - cache removal failure shouldn't break the app
    }
  }

  // Cache attendance
  Future<void> _cacheAttendance(AttendanceRecord attendance) async {
    try {
      final box = await Hive.openBox(_attendanceBox);
      final key = '${attendance.studentId}_${attendance.date.toIso8601String().split('T')[0]}';
      
      // Convert Firestore Timestamps to DateTime for Hive storage
      final cacheData = Map<String, dynamic>.from(attendance.toMap());
      if (cacheData['createdAt'] is Timestamp) {
        cacheData['createdAt'] = (cacheData['createdAt'] as Timestamp).toDate().toIso8601String();
      } else if (cacheData['createdAt'] is DateTime) {
        cacheData['createdAt'] = (cacheData['createdAt'] as DateTime).toIso8601String();
      }
      
      await box.put(key, cacheData);
    } catch (e) {
      print('[StudentDataService] Error caching attendance: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  // Get attendance from cache
  Future<AttendanceRecord?> _getAttendanceFromCache(String studentId, DateTime date) async {
    try {
      final box = await Hive.openBox(_attendanceBox);
      final key = '${studentId}_${date.toIso8601String().split('T')[0]}';
      final cachedData = box.get(key);
      
      if (cachedData is Map) {
        try {
          final data = Map<String, dynamic>.from(cachedData);
          
          // Convert DateTime strings back to DateTime objects if needed
          if (data['createdAt'] is String) {
            try {
              data['createdAt'] = DateTime.parse(data['createdAt'] as String);
            } catch (e) {
              print('[StudentDataService] Error parsing attendance createdAt: $e');
              data['createdAt'] = DateTime.now();
            }
          }
          
          return AttendanceRecord.fromMap(data, data['id'] as String);
        } catch (e) {
          print('[StudentDataService] Error converting cached attendance data: $e');
        }
      }
      return null;
    } catch (e) {
      print('[StudentDataService] Error retrieving attendance from cache: $e');
      return null;
    }
  }

  // Get attendance history from cache
  Future<List<AttendanceRecord>> _getAttendanceHistoryFromCache(String studentId, int days) async {
    try {
      final box = await Hive.openBox(_attendanceBox);
      final records = <AttendanceRecord>[];
      final startDate = DateTime.now().subtract(Duration(days: days));

      for (var key in box.keys) {
        if (key.toString().startsWith('${studentId}_')) {
          final cachedData = box.get(key);
          
          if (cachedData is Map) {
            try {
              final data = Map<String, dynamic>.from(cachedData);
              
              // Convert DateTime strings back to DateTime objects if needed
              if (data['createdAt'] is String) {
                try {
                  data['createdAt'] = DateTime.parse(data['createdAt'] as String);
                } catch (e) {
                  print('[StudentDataService] Error parsing attendance history createdAt: $e');
                  data['createdAt'] = DateTime.now();
                }
              }
              
              final record = AttendanceRecord.fromMap(data, data['id'] as String);
              
              if (record.date.isAfter(startDate)) {
                records.add(record);
              }
            } catch (e) {
              print('[StudentDataService] Error converting cached attendance history data: $e');
            }
          }
        }
      }

      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (e) {
      print('[StudentDataService] Error retrieving attendance history from cache: $e');
      return [];
    }
  }

  // Cache score
  Future<void> _cacheScore(PerformanceScore score) async {
    try {
      final box = await Hive.openBox(_scoresBox);
      final key = '${score.studentId}_${score.id}';
      
      // Convert Firestore Timestamps to DateTime for Hive storage
      final cacheData = Map<String, dynamic>.from(score.toMap());
      if (cacheData['testDate'] is Timestamp) {
        cacheData['testDate'] = (cacheData['testDate'] as Timestamp).toDate().toIso8601String();
      } else if (cacheData['testDate'] is DateTime) {
        cacheData['testDate'] = (cacheData['testDate'] as DateTime).toIso8601String();
      }
      if (cacheData['createdAt'] is Timestamp) {
        cacheData['createdAt'] = (cacheData['createdAt'] as Timestamp).toDate().toIso8601String();
      } else if (cacheData['createdAt'] is DateTime) {
        cacheData['createdAt'] = (cacheData['createdAt'] as DateTime).toIso8601String();
      }
      
      await box.put(key, cacheData);
    } catch (e) {
      print('[StudentDataService] Error caching score: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  // Get scores from cache
  Future<List<PerformanceScore>> _getScoresFromCache(String studentId) async {
    try {
      final box = await Hive.openBox(_scoresBox);
      final scores = <PerformanceScore>[];

      for (var key in box.keys) {
        if (key.toString().startsWith('${studentId}_')) {
          final cachedData = box.get(key);
          
          if (cachedData is Map) {
            try {
              final data = Map<String, dynamic>.from(cachedData);
              
              // Convert DateTime strings back to DateTime objects if needed
              if (data['testDate'] is String) {
                try {
                  data['testDate'] = DateTime.parse(data['testDate'] as String);
                } catch (e) {
                  print('[StudentDataService] Error parsing score testDate: $e');
                  data['testDate'] = DateTime.now();
                }
              }
              if (data['createdAt'] is String) {
                try {
                  data['createdAt'] = DateTime.parse(data['createdAt'] as String);
                } catch (e) {
                  print('[StudentDataService] Error parsing score createdAt: $e');
                  data['createdAt'] = DateTime.now();
                }
              }
              
              scores.add(PerformanceScore.fromMap(data, data['id'] as String));
            } catch (e) {
              print('[StudentDataService] Error converting cached score data: $e');
            }
          }
        }
      }

      scores.sort((a, b) => b.testDate.compareTo(a.testDate));
      return scores;
    } catch (e) {
      print('[StudentDataService] Error retrieving scores from cache: $e');
      return [];
    }
  }

  // ==================== FIRESTORE OPERATIONS ====================

  // Add student to Firestore (for offline sync)
  Future<void> _addStudentToFirestore(Map<String, dynamic> data) async {
    await _firestore.collection('students').doc(data['id'] as String).set(data);
  }

  // Update student in Firestore (for offline sync)
  Future<void> _updateStudentInFirestore(Map<String, dynamic> data) async {
    await _safeUpdateDocument('students', data['id'] as String, data);
  }

  // Delete student from Firestore (for offline sync)
  Future<void> _deleteStudentFromFirestore(Map<String, dynamic> data) async {
    await _firestore.collection('students').doc(data['id'] as String).delete();
  }

  // Add attendance to Firestore (for offline sync)
  Future<void> _addAttendanceToFirestore(Map<String, dynamic> data) async {
    await _firestore.collection('attendance').doc(data['id'] as String).set(data);
  }

  // Add score to Firestore (for offline sync)
  Future<void> _addScoreToFirestore(Map<String, dynamic> data) async {
    await _firestore.collection('performance_scores').doc(data['id'] as String).set(data);
  }

  // ==================== NOTIFICATION METHODS ====================

  void _notifyStudentsChanged() {
    // This would typically trigger a refresh of the students list
    // Implementation depends on the specific UI requirements
  }

  void _notifyAttendanceChanged() {
    // This would typically trigger a refresh of the attendance list
    // Implementation depends on the specific UI requirements
  }

  void _notifyScoresChanged() {
    // This would typically trigger a refresh of the scores list
    // Implementation depends on the specific UI requirements
  }

  // ==================== UTILITY METHODS ====================

  // Convert timestamp to Hive-safe format
  dynamic _convertTimestampForHive(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    } else if (timestamp is DateTime) {
      return timestamp.toIso8601String();
    }
    return timestamp;
  }

  // Convert Hive timestamp string back to DateTime
  DateTime _convertHiveTimestampToDateTime(dynamic timestamp) {
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        print('[StudentDataService] Error parsing timestamp: $e');
        return DateTime.now();
      }
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  // Generate unique ID
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Get attendance statistics
  Map<String, int> getAttendanceStats(List<AttendanceRecord> records) {
    final stats = <String, int>{
      'present': 0,
      'absent': 0,
      'tardy': 0,
      'excused': 0,
    };

    for (var record in records) {
      stats[record.status.name] = (stats[record.status.name] ?? 0) + 1;
    }

    return stats;
  }

  // Dispose resources
  void dispose() {
    _studentsController.close();
    _attendanceController.close();
    _scoresController.close();
  }
} 