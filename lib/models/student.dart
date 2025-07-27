import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String name;
  final String gender;
  final int age;
  final String rollNumber;
  final String? parentContact;
  final String teacherId;
  final String grade;
  final String subject;
  final DateTime createdAt;
  final DateTime lastUpdated;

  Student({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.rollNumber,
    this.parentContact,
    required this.teacherId,
    required this.grade,
    required this.subject,
    required this.createdAt,
    required this.lastUpdated,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'age': age,
      'rollNumber': rollNumber,
      'parentContact': parentContact,
      'teacherId': teacherId,
      'grade': grade,
      'subject': subject,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Create from Firestore document
  factory Student.fromMap(Map<String, dynamic> map, String documentId) {
    return Student(
      id: documentId,
      name: map['name'] ?? '',
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      rollNumber: map['rollNumber'] ?? '',
      parentContact: map['parentContact'],
      teacherId: map['teacherId'] ?? '',
      grade: map['grade'] ?? '',
      subject: map['subject'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create copy with updates
  Student copyWith({
    String? id,
    String? name,
    String? gender,
    int? age,
    String? rollNumber,
    String? parentContact,
    String? teacherId,
    String? grade,
    String? subject,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      rollNumber: rollNumber ?? this.rollNumber,
      parentContact: parentContact ?? this.parentContact,
      teacherId: teacherId ?? this.teacherId,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'Student(id: $id, name: $name, rollNumber: $rollNumber, grade: $grade, subject: $subject)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 