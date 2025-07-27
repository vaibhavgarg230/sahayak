import 'package:cloud_firestore/cloud_firestore.dart';

enum TopicStatus {
  pending,
  completed,
  incomplete,
}

class Curriculum {
  final String id;
  final String teacherId;
  final String board;
  final String grade;
  final String subject;
  final DateTime startDate;
  final DateTime endDate;
  final List<CurriculumTopic> topics;
  final String? pdfUrl;
  final String? pdfName;
  final DateTime createdAt;
  final DateTime lastUpdated;

  Curriculum({
    required this.id,
    required this.teacherId,
    required this.board,
    required this.grade,
    required this.subject,
    required this.startDate,
    required this.endDate,
    required this.topics,
    this.pdfUrl,
    this.pdfName,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'board': board,
      'grade': grade,
      'subject': subject,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'topics': topics.map((topic) => topic.toMap()).toList(),
      'pdfUrl': pdfUrl,
      'pdfName': pdfName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory Curriculum.fromMap(Map<String, dynamic> map, String id) {
    return Curriculum(
      id: id,
      teacherId: map['teacherId'] ?? '',
      board: map['board'] ?? '',
      grade: map['grade'] ?? '',
      subject: map['subject'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      topics: (map['topics'] as List<dynamic>?)
              ?.map((topic) => CurriculumTopic.fromMap(topic as Map<String, dynamic>))
              .toList() ??
          [],
      pdfUrl: map['pdfUrl'],
      pdfName: map['pdfName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Curriculum copyWith({
    String? id,
    String? teacherId,
    String? board,
    String? grade,
    String? subject,
    DateTime? startDate,
    DateTime? endDate,
    List<CurriculumTopic>? topics,
    String? pdfUrl,
    String? pdfName,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return Curriculum(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      board: board ?? this.board,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      topics: topics ?? this.topics,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfName: pdfName ?? this.pdfName,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class CurriculumTopic {
  final String id;
  final String title;
  final String description;
  final int order;
  final DateTime createdAt;

  CurriculumTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CurriculumTopic.fromMap(Map<String, dynamic> map) {
    return CurriculumTopic(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      order: map['order'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  CurriculumTopic copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    DateTime? createdAt,
  }) {
    return CurriculumTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WeeklyPlan {
  final String id;
  final String teacherId;
  final String curriculumId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<WeeklyTopic> topics;
  final DateTime createdAt;
  final DateTime lastUpdated;

  WeeklyPlan({
    required this.id,
    required this.teacherId,
    required this.curriculumId,
    required this.weekStart,
    required this.weekEnd,
    required this.topics,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'curriculumId': curriculumId,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'topics': topics.map((topic) => topic.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory WeeklyPlan.fromMap(Map<String, dynamic> map, String id) {
    return WeeklyPlan(
      id: id,
      teacherId: map['teacherId'] ?? '',
      curriculumId: map['curriculumId'] ?? '',
      weekStart: (map['weekStart'] as Timestamp).toDate(),
      weekEnd: (map['weekEnd'] as Timestamp).toDate(),
      topics: (map['topics'] as List<dynamic>?)
              ?.map((topic) => WeeklyTopic.fromMap(topic as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  WeeklyPlan copyWith({
    String? id,
    String? teacherId,
    String? curriculumId,
    DateTime? weekStart,
    DateTime? weekEnd,
    List<WeeklyTopic>? topics,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return WeeklyPlan(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      curriculumId: curriculumId ?? this.curriculumId,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      topics: topics ?? this.topics,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class WeeklyTopic {
  final String topicId;
  final String title;
  final String description;
  final int originalOrder;
  final TopicStatus status;
  final DateTime? completedAt;
  final String? notes;

  WeeklyTopic({
    required this.topicId,
    required this.title,
    required this.description,
    required this.originalOrder,
    required this.status,
    this.completedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'title': title,
      'description': description,
      'originalOrder': originalOrder,
      'status': status.name,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }

  factory WeeklyTopic.fromMap(Map<String, dynamic> map) {
    return WeeklyTopic(
      topicId: map['topicId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      originalOrder: map['originalOrder'] ?? 0,
      status: TopicStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TopicStatus.pending,
      ),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
    );
  }

  WeeklyTopic copyWith({
    String? topicId,
    String? title,
    String? description,
    int? originalOrder,
    TopicStatus? status,
    DateTime? completedAt,
    String? notes,
  }) {
    return WeeklyTopic(
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      description: description ?? this.description,
      originalOrder: originalOrder ?? this.originalOrder,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
} 