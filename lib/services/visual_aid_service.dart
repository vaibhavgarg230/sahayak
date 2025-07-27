import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class VisualAidService {
  final FirebaseFirestore _firestore;
  static const String _offlineBox = 'visual_aids_offline';
  
  VisualAidService({FirebaseFirestore? firestoreInstance})
      : _firestore = firestoreInstance ?? FirebaseFirestore.instance {
    _initHive();
  }

  Future<void> _initHive() async {
    if (!Hive.isBoxOpen(_offlineBox)) {
      Directory dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      await Hive.openBox(_offlineBox);
    }
  }

  // Save visual aid to Firestore
  Future<String> saveVisualAid({
    required String teacherId,
    required String subject,
    required String topic,
    required String visualContent,
    required String explanation,
    required String language,
    required String gradeLevel,
    bool aiGenerated = true,
  }) async {
    try {
      final visualAidData = {
        'teacherId': teacherId,
        'subject': subject,
        'topic': topic,
        'visualContent': visualContent,
        'explanation': explanation,
        'language': language,
        'gradeLevel': gradeLevel,
        'aiGenerated': aiGenerated,
        'generatedAt': FieldValue.serverTimestamp(),
        'usageCount': 0,
        'effectiveness': 0,
        'ratings': [],
        'shared': false,
        'tags': _generateTags(subject, topic),
      };

      final docRef = await _firestore.collection('visual_aids').add(visualAidData);
      
      // Also save to offline cache
      await _saveToOfflineCache(docRef.id, visualAidData);
      
      print('[VisualAidService] Visual aid saved successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('[VisualAidService] Error saving visual aid: $e');
      // Save to offline queue for later sync
      await _queueForOfflineSync({
        'teacherId': teacherId,
        'subject': subject,
        'topic': topic,
        'visualContent': visualContent,
        'explanation': explanation,
        'language': language,
        'gradeLevel': gradeLevel,
        'aiGenerated': aiGenerated,
      });
      rethrow;
    }
  }

  // Get visual aids for a teacher
  Future<List<Map<String, dynamic>>> getTeacherVisualAids(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection('visual_aids')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('generatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('[VisualAidService] Error fetching teacher visual aids: $e');
      // Return offline cached data
      return await _getOfflineVisualAids(teacherId);
    }
  }

  // Get shared visual aids
  Future<List<Map<String, dynamic>>> getSharedVisualAids({
    String? subject,
    String? gradeLevel,
    String? language,
  }) async {
    try {
      Query query = _firestore.collection('visual_aids').where('shared', isEqualTo: true);
      
      if (subject != null) {
        query = query.where('subject', isEqualTo: subject);
      }
      if (gradeLevel != null) {
        query = query.where('gradeLevel', isEqualTo: gradeLevel);
      }
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }

      final snapshot = await query.orderBy('usageCount', descending: true).limit(20).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('[VisualAidService] Error fetching shared visual aids: $e');
      return [];
    }
  }

  // Safe Firestore document update - creates if doesn't exist
  Future<void> _safeUpdateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      final docRef = _firestore.collection(collection).doc(docId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        // Document exists, update it
        print('[VisualAidService] Updating existing document: $collection/$docId');
        await docRef.update(data);
      } else {
        // Document doesn't exist, create it with merge
        print('[VisualAidService] Creating new document: $collection/$docId');
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('[VisualAidService] Safe document update failed for $collection/$docId: $e');
      throw Exception('Document operation failed: $e');
    }
  }

  // Update visual aid usage and effectiveness
  Future<void> updateVisualAidUsage(String visualAidId, int effectiveness) async {
    try {
      await _safeUpdateDocument('visual_aids', visualAidId, {
        'usageCount': FieldValue.increment(1),
        'effectiveness': FieldValue.increment(effectiveness),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[VisualAidService] Error updating visual aid usage: $e');
    }
  }

  // Rate visual aid effectiveness
  Future<void> rateVisualAid(String visualAidId, int rating, String teacherId) async {
    try {
      final ratingData = {
        'teacherId': teacherId,
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      };

      await _safeUpdateDocument('visual_aids', visualAidId, {
        'ratings': FieldValue.arrayUnion([ratingData]),
        'effectiveness': FieldValue.increment(rating),
      });
    } catch (e) {
      print('[VisualAidService] Error rating visual aid: $e');
    }
  }

  // Share visual aid with other teachers
  Future<void> shareVisualAid(String visualAidId, bool shared) async {
    try {
      await _safeUpdateDocument('visual_aids', visualAidId, {
        'shared': shared,
        'sharedAt': shared ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print('[VisualAidService] Error sharing visual aid: $e');
    }
  }

  // Search visual aids
  Future<List<Map<String, dynamic>>> searchVisualAids(String query, String teacherId) async {
    try {
      // Search in teacher's own visual aids
      final teacherSnapshot = await _firestore
          .collection('visual_aids')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      // Search in shared visual aids
      final sharedSnapshot = await _firestore
          .collection('visual_aids')
          .where('shared', isEqualTo: true)
          .get();

      final allDocs = [...teacherSnapshot.docs, ...sharedSnapshot.docs];
      
      return allDocs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((visualAid) {
            final searchText = query.toLowerCase();
            return visualAid['topic'].toString().toLowerCase().contains(searchText) ||
                   visualAid['subject'].toString().toLowerCase().contains(searchText) ||
                   visualAid['visualContent'].toString().toLowerCase().contains(searchText);
          })
          .toList();
    } catch (e) {
      print('[VisualAidService] Error searching visual aids: $e');
      return [];
    }
  }

  // Get visual aid analytics
  Future<Map<String, dynamic>> getVisualAidAnalytics(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection('visual_aids')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final visualAids = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      int totalVisualAids = visualAids.length;
      int totalUsage = visualAids.fold(0, (sum, aid) => sum + ((aid['usageCount'] as int?) ?? 0));
      double avgEffectiveness = visualAids.isEmpty ? 0 : 
          visualAids.fold(0.0, (sum, aid) => sum + ((aid['effectiveness'] as int?) ?? 0)) / totalVisualAids;
      
      // Subject distribution
      Map<String, int> subjectDistribution = {};
      for (var aid in visualAids) {
        final subject = aid['subject'] ?? 'unknown';
        subjectDistribution[subject] = (subjectDistribution[subject] ?? 0) + 1;
      }

      return {
        'totalVisualAids': totalVisualAids,
        'totalUsage': totalUsage,
        'averageEffectiveness': avgEffectiveness,
        'subjectDistribution': subjectDistribution,
        'recentActivity': visualAids
            .where((aid) => aid['generatedAt'] != null)
            .take(5)
            .map((aid) => {
              'topic': aid['topic'] as String? ?? 'Unknown',
              'generatedAt': aid['generatedAt'],
              'usageCount': (aid['usageCount'] as int?) ?? 0,
            })
            .toList(),
      };
    } catch (e) {
      print('[VisualAidService] Error getting analytics: $e');
      return {};
    }
  }

  // Offline caching methods
  Future<void> _saveToOfflineCache(String id, Map<String, dynamic> data) async {
    final box = await Hive.openBox(_offlineBox);
    await box.put(id, data);
  }

  Future<List<Map<String, dynamic>>> _getOfflineVisualAids(String teacherId) async {
    final box = await Hive.openBox(_offlineBox);
    final allData = box.values.toList();
    
    return allData
        .where((data) => data['teacherId'] == teacherId)
        .map((data) => data as Map<String, dynamic>)
        .toList();
  }

  Future<void> _queueForOfflineSync(Map<String, dynamic> data) async {
    final box = await Hive.openBox(_offlineBox);
    await box.add({
      ...data,
      'synced': false,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  // Sync offline data when online
  Future<void> syncOfflineData() async {
    try {
      final box = await Hive.openBox(_offlineBox);
      final unsyncedData = box.values
          .where((data) => data['synced'] == false)
          .toList();

      for (var data in unsyncedData) {
        final dataMap = data as Map<String, dynamic>;
        await saveVisualAid(
          teacherId: dataMap['teacherId'] as String,
          subject: dataMap['subject'] as String,
          topic: dataMap['topic'] as String,
          visualContent: dataMap['visualContent'] as String,
          explanation: dataMap['explanation'] as String,
          language: dataMap['language'] as String,
          gradeLevel: dataMap['gradeLevel'] as String,
          aiGenerated: dataMap['aiGenerated'] as bool? ?? true,
        );
        
        // Mark as synced
        final key = box.keys.firstWhere((k) => box.get(k) == data);
        await box.put(key, {...dataMap, 'synced': true});
      }
    } catch (e) {
      print('[VisualAidService] Error syncing offline data: $e');
    }
  }

  // Helper method to generate tags for search
  List<String> _generateTags(String subject, String topic) {
    final tags = [subject.toLowerCase(), topic.toLowerCase()];
    
    // Add subject-specific tags
    switch (subject.toLowerCase()) {
      case 'math':
        tags.addAll(['mathematics', 'calculation', 'numbers']);
        break;
      case 'science':
        tags.addAll(['experiment', 'observation', 'discovery']);
        break;
      case 'english':
        tags.addAll(['grammar', 'language', 'communication']);
        break;
      case 'hindi':
        tags.addAll(['हिंदी', 'भाषा', 'व्याकरण']);
        break;
    }
    
    return tags;
  }

  // Delete visual aid
  Future<void> deleteVisualAid(String visualAidId) async {
    try {
      await _firestore.collection('visual_aids').doc(visualAidId).delete();
      
      // Also remove from offline cache
      final box = await Hive.openBox(_offlineBox);
      await box.delete(visualAidId);
    } catch (e) {
      print('[VisualAidService] Error deleting visual aid: $e');
    }
  }
} 