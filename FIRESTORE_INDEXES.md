# Firestore Composite Indexes & Hive Serialization Fixes

## Overview
This document outlines the required Firestore composite indexes and Hive serialization fixes for the Sahayak app to prevent FAILED_PRECONDITION errors and runtime crashes.

## Required Firestore Composite Indexes

### 1. Curriculum Collection Indexes

**Index 1: Teacher Curricula by Last Updated**
- Collection: `curriculum`
- Fields:
  - `teacherId` (Ascending)
  - `lastUpdated` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).orderBy('lastUpdated', descending: true)`

**Index 2: Curriculum by Teacher and Subject**
- Collection: `curriculum`
- Fields:
  - `teacherId` (Ascending)
  - `subject` (Ascending)
  - `lastUpdated` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).where('subject', isEqualTo: subject).orderBy('lastUpdated', descending: true)`

### 2. Daily Plans Collection Indexes

**Index 3: Weekly Plans by Teacher and Date Range**
- Collection: `daily_plans`
- Fields:
  - `teacherId` (Ascending)
  - `date` (Ascending)
  - `date` (Ascending) - for range queries
- Query: `where('teacherId', isEqualTo: teacherId).where('date', isGreaterThanOrEqualTo: weekStart).where('date', isLessThan: weekEnd).orderBy('date')`

**Index 4: Daily Plans by Teacher and Curriculum**
- Collection: `daily_plans`
- Fields:
  - `teacherId` (Ascending)
  - `curriculumId` (Ascending)
  - `date` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).where('curriculumId', isEqualTo: curriculumId).orderBy('date', descending: true)`

### 3. Attendance Collection Indexes

**Index 5: Student Attendance by Teacher and Date**
- Collection: `attendance`
- Fields:
  - `teacherId` (Ascending)
  - `date` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).orderBy('date', descending: true)`

**Index 6: Student Attendance by Teacher, Grade, and Date**
- Collection: `attendance`
- Fields:
  - `teacherId` (Ascending)
  - `grade` (Ascending)
  - `date` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).where('grade', isEqualTo: grade).orderBy('date', descending: true)`

### 4. Performance Scores Collection Indexes

**Index 7: Student Scores by Teacher and Date**
- Collection: `performance_scores`
- Fields:
  - `teacherId` (Ascending)
  - `date` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).orderBy('date', descending: true)`

**Index 8: Student Scores by Teacher, Student, and Date**
- Collection: `performance_scores`
- Fields:
  - `teacherId` (Ascending)
  - `studentId` (Ascending)
  - `date` (Descending)
- Query: `where('teacherId', isEqualTo: teacherId).where('studentId', isEqualTo: studentId).orderBy('date', descending: true)`

## How to Create Indexes

### Method 1: Firebase Console
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Select the collection name
4. Add fields in the correct order
5. Set field order (Ascending/Descending)
6. Click "Create"

### Method 2: Using Error URLs
When you get a FAILED_PRECONDITION error, the error message will contain a URL like:
```
https://console.firebase.google.com/project/sahayak-mvp-2025/firestore/indexes?create_composite=...
```

Click this URL to automatically create the required index.

### Method 3: Firebase CLI
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore

# Deploy indexes
firebase deploy --only firestore:indexes
```

## Hive Serialization Fixes

### Problem
Hive cannot directly serialize Firestore types like `Timestamp` and `FieldValue`, causing runtime crashes.

### Solution
We've implemented comprehensive type conversion methods:

#### 1. Firestore to Hive Conversion (`_convertFirestoreDataForHive`)
```dart
Map<String, dynamic> _convertFirestoreDataForHive(Map<String, dynamic> data) {
  final converted = <String, dynamic>{};
  
  for (final entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    
    if (value is Timestamp) {
      // Convert Timestamp to ISO 8601 string
      converted[key] = value.toDate().toIso8601String();
    } else if (value is FieldValue) {
      // Skip FieldValue objects - they're not serializable
      print('[Service] Skipping FieldValue for key: $key');
      continue;
    } else if (value is Map<String, dynamic>) {
      // Recursively convert nested maps
      converted[key] = _convertFirestoreDataForHive(value);
    } else if (value is List) {
      // Convert lists that might contain Firestore types
      converted[key] = value.map((item) {
        if (item is Map<String, dynamic>) {
          return _convertFirestoreDataForHive(item);
        } else if (item is Timestamp) {
          return item.toDate().toIso8601String();
        } else if (item is FieldValue) {
          return null;
        }
        return item;
      }).where((item) => item != null).toList();
    } else {
      // Keep other types as-is
      converted[key] = value;
    }
  }
  
  return converted;
}
```

#### 2. Hive to Usable Data Conversion (`_convertHiveDataToUsable`)
```dart
Map<String, dynamic> _convertHiveDataToUsable(Map<String, dynamic> data) {
  final converted = <String, dynamic>{};
  
  for (final entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    
    if (value is String && _isIso8601Date(value)) {
      // Convert ISO 8601 strings back to DateTime
      try {
        converted[key] = DateTime.parse(value);
      } catch (e) {
        print('[Service] Error parsing date string for key $key: $e');
        converted[key] = DateTime.now(); // Fallback
      }
    } else if (value is Map<String, dynamic>) {
      // Recursively convert nested maps
      converted[key] = _convertHiveDataToUsable(value);
    } else if (value is List) {
      // Convert lists that might contain date strings
      converted[key] = value.map((item) {
        if (item is Map<String, dynamic>) {
          return _convertHiveDataToUsable(item);
        } else if (item is String && _isIso8601Date(item)) {
          try {
            return DateTime.parse(item);
          } catch (e) {
            return DateTime.now();
          }
        }
        return item;
      }).toList();
    } else {
      // Keep other types as-is
      converted[key] = value;
    }
  }
  
  return converted;
}
```

#### 3. Date String Validation (`_isIso8601Date`)
```dart
bool _isIso8601Date(String value) {
  try {
    DateTime.parse(value);
    return true;
  } catch (e) {
    return false;
  }
}
```

## Error Handling for Index Issues

### Graceful Fallback Strategy
When Firestore index errors occur, the app implements fallback queries:

1. **Detect Index Error**: Check for `FAILED_PRECONDITION` or index URLs in error messages
2. **Simplified Query**: Remove complex ordering/filtering and fetch all data
3. **In-Memory Processing**: Sort and filter data in memory instead of Firestore
4. **Cache Fallback**: Use cached data if all queries fail

### Example Implementation
```dart
try {
  // Try optimized query with indexes
  final snapshot = await _firestore
      .collection('curriculum')
      .where('teacherId', isEqualTo: teacherId)
      .orderBy('lastUpdated', descending: true)
      .get();
  
  return snapshot.docs.map((doc) => Curriculum.fromMap(doc.data(), doc.id)).toList();
} catch (e) {
  if (e.toString().contains('FAILED_PRECONDITION') || 
      e.toString().contains('indexes?create_composite=')) {
    
    // Fallback: Simple query without ordering
    final snapshot = await _firestore
        .collection('curriculum')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    
    final curricula = snapshot.docs
        .map((doc) => Curriculum.fromMap(doc.data(), doc.id))
        .toList();
    
    // Sort in memory
    curricula.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    
    return curricula;
  }
  
  // Final fallback: Use cache
  return await _getCurriculaFromCache(teacherId);
}
```

## Testing Checklist

### Firestore Index Testing
- [ ] Create all required composite indexes
- [ ] Test curriculum queries with teacher filtering and ordering
- [ ] Test daily plan queries with date range filtering
- [ ] Test attendance queries with grade filtering
- [ ] Test performance score queries with student filtering
- [ ] Verify no FAILED_PRECONDITION errors in logs

### Hive Serialization Testing
- [ ] Test profile caching and retrieval
- [ ] Test curriculum caching with complex nested data
- [ ] Test daily plan caching with date fields
- [ ] Test attachment caching with file metadata
- [ ] Verify no serialization errors in logs
- [ ] Test offline functionality with cached data

### Integration Testing
- [ ] Test app startup with existing cached data
- [ ] Test data sync when coming back online
- [ ] Test error recovery when indexes are missing
- [ ] Test graceful degradation when Firestore is unavailable

## Monitoring and Maintenance

### Index Performance
- Monitor index usage in Firebase Console
- Remove unused indexes to reduce costs
- Optimize indexes based on query patterns

### Cache Management
- Monitor Hive cache size
- Implement cache cleanup for old data
- Validate cache integrity periodically

### Error Tracking
- Log all index-related errors
- Track fallback query usage
- Monitor serialization error rates

## Files Modified

1. `lib/services/auth_service.dart` - Added Hive serialization helpers
2. `lib/services/planner_service.dart` - Added Hive serialization and index error handling
3. `lib/services/student_data_service.dart` - Already has Hive serialization (needs cleanup)

## Next Steps

1. **Create Indexes**: Use Firebase Console to create all required composite indexes
2. **Test Queries**: Run the app and verify all Firestore queries work without errors
3. **Monitor Logs**: Check for any remaining serialization or index errors
4. **Performance Tuning**: Optimize indexes based on actual usage patterns
5. **Documentation**: Update this document with any additional indexes or fixes needed 