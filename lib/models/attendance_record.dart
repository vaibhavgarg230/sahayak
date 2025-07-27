import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  present,
  absent,
  tardy,
  excused,
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String teacherId;
  final String grade;
  final String subject;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.grade,
    required this.subject,
    required this.date,
    required this.status,
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
      'date': Timestamp.fromDate(date),
      'status': status.name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory AttendanceRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceRecord(
      id: documentId,
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      grade: map['grade'] ?? '',
      subject: map['subject'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AttendanceStatus.present,
      ),
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create copy with updates
  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? grade,
    String? subject,
    DateTime? date,
    AttendanceStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Get status color for UI
  static int getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 0xFF4CAF50; // Green
      case AttendanceStatus.absent:
        return 0xFFF44336; // Red
      case AttendanceStatus.tardy:
        return 0xFFFF9800; // Orange
      case AttendanceStatus.excused:
        return 0xFF2196F3; // Blue
    }
  }

  // Get status icon for UI
  static String getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return '✓';
      case AttendanceStatus.absent:
        return '✗';
      case AttendanceStatus.tardy:
        return '⏰';
      case AttendanceStatus.excused:
        return '📝';
    }
  }

  @override
  String toString() {
    return 'AttendanceRecord(id: $id, studentId: $studentId, date: $date, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 