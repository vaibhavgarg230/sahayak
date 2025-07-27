import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import '../models/curriculum.dart';

class PlannerService {
  static final PlannerService _instance = PlannerService._internal();
  factory PlannerService() => _instance;
  PlannerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late Box<dynamic> _curriculumBox;
  late Box<dynamic> _weeklyPlanBox;

  Future<void> initialize() async {
    _curriculumBox = await Hive.openBox('curriculum_cache');
    _weeklyPlanBox = await Hive.openBox('weekly_plan_cache');
  }

  // ==================== CURRICULUM MANAGEMENT ====================

  Future<String> createCurriculum({
    required String teacherId,
    required String board,
    required String grade,
    required String subject,
    required DateTime startDate,
    required DateTime endDate,
    required List<CurriculumTopic> topics,
    String? pdfUrl,
    String? pdfName,
  }) async {
    try {
      final curriculum = Curriculum(
        id: '',
        teacherId: teacherId,
        board: board,
        grade: grade,
        subject: subject,
        startDate: startDate,
        endDate: endDate,
        topics: topics,
        pdfUrl: pdfUrl,
        pdfName: pdfName,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('curriculums')
          .add(curriculum.toMap());

      final createdCurriculum = curriculum.copyWith(id: docRef.id);
      await _cacheCurriculum(createdCurriculum);

      // Generate weekly plans for this curriculum
      await _generateWeeklyPlans(teacherId, createdCurriculum);

      return docRef.id;
    } catch (e) {
      print('[PlannerService] Error creating curriculum: $e');
      throw Exception('Failed to create curriculum: $e');
    }
  }

  Future<List<Curriculum>> getTeacherCurricula(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('curriculums')
          .orderBy('createdAt', descending: true)
          .get();

      final curricula = snapshot.docs
          .map((doc) => Curriculum.fromMap(doc.data(), doc.id))
          .toList();

      // Cache all curricula
      for (final curriculum in curricula) {
        await _cacheCurriculum(curriculum);
      }

      return curricula;
    } catch (e) {
      print('[PlannerService] Error fetching curricula: $e');
      // Try to get from cache
      return _getCurriculaFromCache(teacherId);
    }
  }

  Future<Curriculum?> getCurriculum(String curriculumId) async {
    try {
      final doc = await _firestore
          .collectionGroup('curriculums')
          .where(FieldPath.documentId, isEqualTo: curriculumId)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        final curriculum = Curriculum.fromMap(doc.docs.first.data(), doc.docs.first.id);
        await _cacheCurriculum(curriculum);
        return curriculum;
      }
      return null;
    } catch (e) {
      print('[PlannerService] Error fetching curriculum: $e');
      return _getCurriculumFromCache(curriculumId);
    }
  }

  Future<String> uploadCurriculumPDF(String teacherId, File file) async {
    try {
      final fileName = 'curriculum_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('teachers/$teacherId/curriculums/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('[PlannerService] Error uploading PDF: $e');
      throw Exception('Failed to upload PDF: $e');
    }
  }

  // ==================== WEEKLY PLAN GENERATION ====================

  Future<void> _generateWeeklyPlans(String teacherId, Curriculum curriculum) async {
    try {
      final weeks = _calculateWorkingWeeks(curriculum.startDate, curriculum.endDate);
      final topicsPerWeek = _distributeTopicsEvenly(curriculum.topics, weeks.length);

      for (int i = 0; i < weeks.length; i++) {
        final weekStart = weeks[i];
        final weekEnd = weekStart.add(const Duration(days: 4)); // Mon-Fri (5 days)
        final weekTopics = topicsPerWeek[i];

        final weeklyTopics = weekTopics.map((topic) {
          return WeeklyTopic(
            topicId: topic.id,
            title: topic.title,
            description: topic.description,
            originalOrder: topic.order,
            status: TopicStatus.pending,
            completedAt: null,
            notes: null,
          );
        }).toList();

        final weeklyPlan = WeeklyPlan(
          id: '',
          teacherId: teacherId,
          curriculumId: curriculum.id,
          weekStart: weekStart,
          weekEnd: weekEnd,
          topics: weeklyTopics,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );

        final docRef = await _firestore
            .collection('teachers')
            .doc(teacherId)
            .collection('weekly_plans')
            .add(weeklyPlan.toMap());

        final createdPlan = weeklyPlan.copyWith(id: docRef.id);
        await _cacheWeeklyPlan(createdPlan);
      }
    } catch (e) {
      print('[PlannerService] Error generating weekly plans: $e');
      throw Exception('Failed to generate weekly plans: $e');
    }
  }

  /// Calculate working weeks (Monday to Friday) between start and end dates
  List<DateTime> _calculateWorkingWeeks(DateTime startDate, DateTime endDate) {
    final weeks = <DateTime>[];
    DateTime currentWeek = _getNextMonday(startDate);
    
    while (currentWeek.isBefore(endDate) || currentWeek.isAtSameMomentAs(endDate)) {
      weeks.add(currentWeek);
      currentWeek = currentWeek.add(const Duration(days: 7));
    }
    
    return weeks;
  }

  /// Get the next Monday from the given date
  DateTime _getNextMonday(DateTime date) {
    final weekday = date.weekday;
    final daysUntilMonday = weekday == 1 ? 0 : 8 - weekday;
    return date.add(Duration(days: daysUntilMonday));
  }

  /// Distribute topics evenly across weeks, ensuring balanced distribution
  List<List<CurriculumTopic>> _distributeTopicsEvenly(List<CurriculumTopic> topics, int numWeeks) {
    if (numWeeks == 0) return [];
    
    final distribution = List.generate(numWeeks, (_) => <CurriculumTopic>[]);
    
    // Sort topics by order to maintain sequence
    final sortedTopics = List<CurriculumTopic>.from(topics)
      ..sort((a, b) => a.order.compareTo(b.order));
    
    for (int i = 0; i < sortedTopics.length; i++) {
      final weekIndex = i % numWeeks;
      distribution[weekIndex].add(sortedTopics[i]);
    }
    
    return distribution;
  }

  // ==================== WEEKLY PLAN MANAGEMENT ====================

  Future<List<WeeklyPlan>> getWeeklyPlans(String teacherId, String curriculumId) async {
    try {
      final snapshot = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('weekly_plans')
          .where('curriculumId', isEqualTo: curriculumId)
          .orderBy('weekStart', descending: false)
          .get();

      final plans = snapshot.docs
          .map((doc) => WeeklyPlan.fromMap(doc.data(), doc.id))
          .toList();

      // Cache all plans
      for (final plan in plans) {
        await _cacheWeeklyPlan(plan);
      }

      return plans;
    } catch (e) {
      print('[PlannerService] Error fetching weekly plans: $e');
      // Try to get from cache
      return _getWeeklyPlansFromCache(teacherId, curriculumId);
    }
  }

  Future<WeeklyPlan> updateTopicStatus({
    required String teacherId,
    required String planId,
    required String topicId,
    required TopicStatus status,
    String? notes,
  }) async {
    try {
      final plan = await _getWeeklyPlanById(teacherId, planId);
      if (plan == null) {
        throw Exception('Weekly plan not found');
      }

      final updatedTopics = plan.topics.map((topic) {
        if (topic.topicId == topicId) {
          return topic.copyWith(
            status: status,
            completedAt: status == TopicStatus.completed ? DateTime.now() : null,
            notes: notes,
          );
        }
        return topic;
      }).toList();

      final updatedPlan = plan.copyWith(
        topics: updatedTopics,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('weekly_plans')
          .doc(planId)
          .update(updatedPlan.toMap());

      await _cacheWeeklyPlan(updatedPlan);

      // If topic is marked incomplete, reschedule it to next available week
      if (status == TopicStatus.incomplete) {
        await _rescheduleIncompleteTopic(teacherId, updatedPlan, topicId);
      }

      return updatedPlan;
    } catch (e) {
      print('[PlannerService] Error updating topic status: $e');
      throw Exception('Failed to update topic status: $e');
    }
  }

  /// Reschedule incomplete topic to the next available week
  Future<void> _rescheduleIncompleteTopic(String teacherId, WeeklyPlan currentPlan, String topicId) async {
    try {
      // Find the incomplete topic
      final incompleteTopic = currentPlan.topics.firstWhere((t) => t.topicId == topicId);
      
      // Get all weekly plans for this curriculum
      final allPlans = await getWeeklyPlans(teacherId, currentPlan.curriculumId);
      
      // Find the next week plan (after current week)
      final currentWeekIndex = allPlans.indexWhere((p) => p.id == currentPlan.id);
      if (currentWeekIndex == -1 || currentWeekIndex >= allPlans.length - 1) {
        // No next week available, create a new week
        await _createNewWeekForIncompleteTopic(teacherId, currentPlan, incompleteTopic);
        return;
      }

      final nextWeekPlan = allPlans[currentWeekIndex + 1];
      
      // Add the incomplete topic to the next week
      final updatedTopics = List<WeeklyTopic>.from(nextWeekPlan.topics)
        ..add(incompleteTopic.copyWith(
          status: TopicStatus.pending,
          completedAt: null,
          notes: 'Rescheduled from previous week',
        ));

      final updatedPlan = nextWeekPlan.copyWith(
        topics: updatedTopics,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('weekly_plans')
          .doc(nextWeekPlan.id)
          .update(updatedPlan.toMap());

      await _cacheWeeklyPlan(updatedPlan);
    } catch (e) {
      print('[PlannerService] Error rescheduling incomplete topic: $e');
      throw Exception('Failed to reschedule incomplete topic: $e');
    }
  }

  /// Create a new week for incomplete topics when no future weeks exist
  Future<void> _createNewWeekForIncompleteTopic(String teacherId, WeeklyPlan currentPlan, WeeklyTopic incompleteTopic) async {
    try {
      final newWeekStart = currentPlan.weekEnd.add(const Duration(days: 3)); // Next Monday
      final newWeekEnd = newWeekStart.add(const Duration(days: 4)); // Friday

      final newWeeklyPlan = WeeklyPlan(
        id: '',
        teacherId: teacherId,
        curriculumId: currentPlan.curriculumId,
        weekStart: newWeekStart,
        weekEnd: newWeekEnd,
        topics: [incompleteTopic.copyWith(
          status: TopicStatus.pending,
          completedAt: null,
          notes: 'Rescheduled from previous week',
        )],
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('weekly_plans')
          .add(newWeeklyPlan.toMap());

      final createdPlan = newWeeklyPlan.copyWith(id: docRef.id);
      await _cacheWeeklyPlan(createdPlan);
    } catch (e) {
      print('[PlannerService] Error creating new week for incomplete topic: $e');
      throw Exception('Failed to create new week for incomplete topic: $e');
    }
  }

  Future<WeeklyPlan?> _getWeeklyPlanById(String teacherId, String planId) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('weekly_plans')
          .doc(planId)
          .get();

      if (doc.exists) {
        return WeeklyPlan.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('[PlannerService] Error fetching weekly plan by ID: $e');
      return null;
    }
  }

  // ==================== CACHING ====================

  Future<void> _cacheCurriculum(Curriculum curriculum) async {
    try {
      await _curriculumBox.put('${curriculum.teacherId}_${curriculum.id}', {
        'id': curriculum.id,
        'teacherId': curriculum.teacherId,
        'board': curriculum.board,
        'grade': curriculum.grade,
        'subject': curriculum.subject,
        'startDate': curriculum.startDate.millisecondsSinceEpoch,
        'endDate': curriculum.endDate.millisecondsSinceEpoch,
        'topics': curriculum.topics.map((t) => {
          'id': t.id,
          'title': t.title,
          'description': t.description,
          'order': t.order,
          'createdAt': t.createdAt.millisecondsSinceEpoch,
        }).toList(),
        'pdfUrl': curriculum.pdfUrl,
        'pdfName': curriculum.pdfName,
        'createdAt': curriculum.createdAt.millisecondsSinceEpoch,
        'lastUpdated': curriculum.lastUpdated.millisecondsSinceEpoch,
      });
    } catch (e) {
      print('[PlannerService] Error caching curriculum: $e');
    }
  }

  Future<void> _cacheWeeklyPlan(WeeklyPlan plan) async {
    try {
      await _weeklyPlanBox.put('${plan.teacherId}_${plan.id}', {
        'id': plan.id,
        'teacherId': plan.teacherId,
        'curriculumId': plan.curriculumId,
        'weekStart': plan.weekStart.millisecondsSinceEpoch,
        'weekEnd': plan.weekEnd.millisecondsSinceEpoch,
        'topics': plan.topics.map((t) => {
          'topicId': t.topicId,
          'title': t.title,
          'description': t.description,
          'originalOrder': t.originalOrder,
          'status': t.status.name,
          'completedAt': t.completedAt?.millisecondsSinceEpoch,
          'notes': t.notes,
        }).toList(),
        'createdAt': plan.createdAt.millisecondsSinceEpoch,
        'lastUpdated': plan.lastUpdated.millisecondsSinceEpoch,
      });
    } catch (e) {
      print('[PlannerService] Error caching weekly plan: $e');
    }
  }

  List<Curriculum> _getCurriculaFromCache(String teacherId) {
    try {
      final keys = _curriculumBox.keys.where((key) => key.toString().startsWith('${teacherId}_'));
      final curricula = <Curriculum>[];
      
      for (final key in keys) {
        final data = _curriculumBox.get(key) as Map<String, dynamic>;
        final topics = (data['topics'] as List<dynamic>).map((t) => CurriculumTopic(
          id: t['id'],
          title: t['title'],
          description: t['description'],
          order: t['order'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(t['createdAt']),
        )).toList();
        
        curricula.add(Curriculum(
          id: data['id'],
          teacherId: data['teacherId'],
          board: data['board'],
          grade: data['grade'],
          subject: data['subject'],
          startDate: DateTime.fromMillisecondsSinceEpoch(data['startDate']),
          endDate: DateTime.fromMillisecondsSinceEpoch(data['endDate']),
          topics: topics,
          pdfUrl: data['pdfUrl'],
          pdfName: data['pdfName'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated']),
        ));
      }
      
      return curricula;
    } catch (e) {
      print('[PlannerService] Error getting curricula from cache: $e');
      return [];
    }
  }

  Curriculum? _getCurriculumFromCache(String curriculumId) {
    try {
      final keys = _curriculumBox.keys.where((key) => key.toString().endsWith('_$curriculumId'));
      if (keys.isEmpty) return null;
      
      final data = _curriculumBox.get(keys.first) as Map<String, dynamic>;
      final topics = (data['topics'] as List<dynamic>).map((t) => CurriculumTopic(
        id: t['id'],
        title: t['title'],
        description: t['description'],
        order: t['order'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(t['createdAt']),
      )).toList();
      
      return Curriculum(
        id: data['id'],
        teacherId: data['teacherId'],
        board: data['board'],
        grade: data['grade'],
        subject: data['subject'],
        startDate: DateTime.fromMillisecondsSinceEpoch(data['startDate']),
        endDate: DateTime.fromMillisecondsSinceEpoch(data['endDate']),
        topics: topics,
        pdfUrl: data['pdfUrl'],
        pdfName: data['pdfName'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated']),
      );
    } catch (e) {
      print('[PlannerService] Error getting curriculum from cache: $e');
      return null;
    }
  }

  List<WeeklyPlan> _getWeeklyPlansFromCache(String teacherId, String curriculumId) {
    try {
      final keys = _weeklyPlanBox.keys.where((key) => key.toString().startsWith('${teacherId}_'));
      final plans = <WeeklyPlan>[];
      
      for (final key in keys) {
        final data = _weeklyPlanBox.get(key) as Map<String, dynamic>;
        if (data['curriculumId'] != curriculumId) continue;
        
        final topics = (data['topics'] as List<dynamic>).map((t) => WeeklyTopic(
          topicId: t['topicId'],
          title: t['title'],
          description: t['description'],
          originalOrder: t['originalOrder'],
          status: TopicStatus.values.firstWhere((e) => e.name == t['status']),
          completedAt: t['completedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(t['completedAt']) : null,
          notes: t['notes'],
        )).toList();
        
        plans.add(WeeklyPlan(
          id: data['id'],
          teacherId: data['teacherId'],
          curriculumId: data['curriculumId'],
          weekStart: DateTime.fromMillisecondsSinceEpoch(data['weekStart']),
          weekEnd: DateTime.fromMillisecondsSinceEpoch(data['weekEnd']),
          topics: topics,
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated']),
        ));
      }
      
      // Sort by week start date
      plans.sort((a, b) => a.weekStart.compareTo(b.weekStart));
      return plans;
    } catch (e) {
      print('[PlannerService] Error getting weekly plans from cache: $e');
      return [];
    }
  }

  // ==================== UTILITY METHODS ====================

  List<String> getAvailableBoards() {
    return [
      'CBSE',
      'ICSE',
      'State Board - Maharashtra',
      'State Board - Karnataka',
      'State Board - Tamil Nadu',
      'State Board - Kerala',
      'State Board - Andhra Pradesh',
      'State Board - Telangana',
      'State Board - Gujarat',
      'State Board - Rajasthan',
      'State Board - Madhya Pradesh',
      'State Board - Uttar Pradesh',
      'State Board - Bihar',
      'State Board - West Bengal',
      'State Board - Odisha',
      'State Board - Assam',
      'State Board - Punjab',
      'State Board - Haryana',
      'State Board - Himachal Pradesh',
      'State Board - Uttarakhand',
      'State Board - Jharkhand',
      'State Board - Chhattisgarh',
      'State Board - Goa',
      'State Board - Manipur',
      'State Board - Meghalaya',
      'State Board - Mizoram',
      'State Board - Nagaland',
      'State Board - Tripura',
      'State Board - Sikkim',
      'State Board - Arunachal Pradesh',
      'Other',
    ];
  }

  List<String> getAvailableGrades() {
    return [
      'Class 1',
      'Class 2',
      'Class 3',
      'Class 4',
      'Class 5',
      'Class 6',
      'Class 7',
      'Class 8',
      'Class 9',
      'Class 10',
      'Class 11',
      'Class 12',
    ];
  }

  List<String> getAvailableSubjects() {
    return [
      'Mathematics',
      'Science',
      'English',
      'Hindi',
      'Social Studies',
      'History',
      'Geography',
      'Civics',
      'Economics',
      'Physics',
      'Chemistry',
      'Biology',
      'Computer Science',
      'Physical Education',
      'Art',
      'Music',
      'Literature',
      'Grammar',
      'Environmental Studies',
      'General Knowledge',
      'Other',
    ];
  }
} 