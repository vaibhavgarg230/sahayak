import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceScore {
  final String id;
  final String studentId;
  final String teacherId;
  final String grade;
  final String subject;
  final String testName;
  final double score;
  final double maxScore;
  final DateTime testDate;
  final String? notes;
  final DateTime createdAt;

  PerformanceScore({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.grade,
    required this.subject,
    required this.testName,
    required this.score,
    required this.maxScore,
    required this.testDate,
    this.notes,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'teacherId': teacherId,
      'grade': grade,
      'subject': subject,
      'testName': testName,
      'score': score,
      'maxScore': maxScore,
      'testDate': Timestamp.fromDate(testDate),
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory PerformanceScore.fromMap(Map<String, dynamic> map, String documentId) {
    return PerformanceScore(
      id: documentId,
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      grade: map['grade'] ?? '',
      subject: map['subject'] ?? '',
      testName: map['testName'] ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 100.0,
      testDate: (map['testDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create copy with updates
  PerformanceScore copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? grade,
    String? subject,
    String? testName,
    double? score,
    double? maxScore,
    DateTime? testDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return PerformanceScore(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      testName: testName ?? this.testName,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      testDate: testDate ?? this.testDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Calculate percentage
  double get percentage => (score / maxScore) * 100;

  // Get grade label based on percentage
  String get gradeLabel {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C+';
    if (percentage >= 40) return 'C';
    if (percentage >= 30) return 'D';
    return 'F';
  }

  // Get color based on percentage
  static int getScoreColor(double percentage) {
    if (percentage >= 80) return 0xFF4CAF50; // Green
    if (percentage >= 60) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }

  @override
  String toString() {
    return 'PerformanceScore(id: $id, studentId: $studentId, testName: $testName, score: $score/$maxScore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformanceScore && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 