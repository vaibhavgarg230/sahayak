import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _userBox = 'user_profile_cache';
  
  // Stream controller for auth state changes
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  
  // Current user profile data
  Map<String, dynamic>? _currentUserProfile;
  
  AuthService() {
    _initHive();
    _setupAuthStateListener();
  }

  // Initialize Hive for offline caching
  Future<void> _initHive() async {
    if (!Hive.isBoxOpen(_userBox)) {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      await Hive.openBox(_userBox);
    }
  }

  // Setup auth state listener
  void _setupAuthStateListener() {
    _auth.authStateChanges().listen((User? user) {
      _authStateController.add(user);
      if (user != null) {
        _loadUserProfile(user.uid);
      } else {
        _currentUserProfile = null;
      }
    });
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state stream
  Stream<User?> get authStateChanges => _authStateController.stream;

  // Get current user profile
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;

  // Phone number authentication
  Future<void> sendPhoneOTP(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _storeVerificationId(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  // Verify OTP and sign in
  Future<UserCredential> verifyOTPAndSignIn(String otp) async {
    try {
      final verificationId = await _getStoredVerificationId();
      if (verificationId == null) {
        throw Exception('No verification ID found. Please request OTP again.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // Check if user profile exists
      final profileExists = await _checkUserProfileExists(userCredential.user!.uid);
      if (!profileExists) {
        // Create initial profile
        await _createInitialProfile(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  // Email + PIN authentication
  Future<UserCredential> signInWithEmailAndPIN(String email, String pin) async {
    try {
      // For demo purposes, we'll use a simple PIN system
      // In production, you'd want to hash the PIN and store it securely
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pin, // In production, use proper password hashing
      );

      // Check if user profile exists
      final profileExists = await _checkUserProfileExists(userCredential.user!.uid);
      if (!profileExists) {
        await _createInitialProfile(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw Exception('Email/PIN authentication failed: $e');
    }
  }

  // Create new account with email
  Future<UserCredential> createAccountWithEmail(String email, String pin, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pin,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      // Create initial profile
      await _createInitialProfile(userCredential.user!);

      return userCredential;
    } catch (e) {
      throw Exception('Account creation failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUserProfile = null;
      await _clearCachedProfile();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Check if user profile exists
  Future<bool> _checkUserProfileExists(String userId) async {
    try {
      final doc = await _firestore.collection('teachers').doc(userId).get();
      return doc.exists;
    } catch (e) {
      // If offline, check cached profile
      return await _getCachedProfile() != null;
    }
  }

  // Safe Firestore document update - creates if doesn't exist
  Future<void> _safeUpdateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      final docRef = _firestore.collection(collection).doc(docId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        // Document exists, update it
        print('[AuthService] Updating existing document: $collection/$docId');
        await docRef.update(data);
      } else {
        // Document doesn't exist, create it with merge
        print('[AuthService] Creating new document: $collection/$docId');
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('[AuthService] Safe document update failed for $collection/$docId: $e');
      throw Exception('Document operation failed: $e');
    }
  }

  // Create initial profile
  Future<void> _createInitialProfile(User user) async {
    final initialProfile = {
      'userId': user.uid,
      'name': user.displayName ?? 'Teacher',
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'grades': [],
      'subjects': [],
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'isProfileComplete': false,
    };

    try {
      await _firestore.collection('teachers').doc(user.uid).set(initialProfile);
      await _cacheProfile(initialProfile);
      _currentUserProfile = initialProfile;
    } catch (e) {
      // Cache offline if Firestore fails
      await _cacheProfile(initialProfile);
      _currentUserProfile = initialProfile;
    }
  }

  // Load user profile
  Future<void> _loadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('teachers').doc(userId).get();
      if (doc.exists) {
        final profile = doc.data()!;
        _currentUserProfile = profile;
        await _cacheProfile(profile);
      }
    } catch (e) {
      // Load from cache if offline
      final cachedProfile = await _getCachedProfile();
      if (cachedProfile != null) {
        _currentUserProfile = cachedProfile;
      }
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    try {
      final updatedProfile = {
        ..._currentUserProfile ?? {},
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Use safe update method that handles document creation if needed
      final updateData = {
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // If document doesn't exist, include initial data
      if (_currentUserProfile == null) {
        updateData.addAll({
          'userId': currentUser!.uid,
          'name': currentUser!.displayName ?? 'Teacher',
          'email': currentUser!.email,
          'phoneNumber': currentUser!.phoneNumber,
          'grades': [],
          'subjects': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _safeUpdateDocument('teachers', currentUser!.uid, updateData);
      
      _currentUserProfile = updatedProfile;
      await _cacheProfile(updatedProfile);
    } catch (e) {
      print('Firestore update error: $e');
      // Cache offline if Firestore fails
      final updatedProfile = {
        ..._currentUserProfile ?? {},
        ...updates,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      _currentUserProfile = updatedProfile;
      await _cacheProfile(updatedProfile);
      throw Exception('Profile update failed (offline mode): $e');
    }
  }

  // Update grades and subjects
  Future<void> updateGradesAndSubjects(List<String> grades, List<String> subjects) async {
    await updateUserProfile({
      'grades': grades,
      'subjects': subjects,
      'isProfileComplete': true,
    });
  }

  // Get available grades
  List<String> getAvailableGrades() {
    return [
      'Grade 1',
      'Grade 2', 
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
      'Grade 7',
      'Grade 8',
    ];
  }

  // Get available subjects
  List<String> getAvailableSubjects() {
    return [
      'Mathematics',
      'Science',
      'Hindi',
      'English',
      'Social Studies',
      'Environmental Studies',
      'Computer Science',
      'Physical Education',
    ];
  }

  // Cache profile offline
  Future<void> _cacheProfile(Map<String, dynamic> profile) async {
    try {
      final box = await Hive.openBox(_userBox);
      
      // Convert Firestore types to Hive-safe types
      final cacheData = _convertFirestoreDataForHive(profile);
      
      await box.put('user_profile', cacheData);
    } catch (e) {
      print('[AuthService] Error caching profile: $e');
      // Don't throw - caching failure shouldn't break the app
    }
  }

  /// Convert Firestore data types to Hive-safe serializable types
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
        print('[AuthService] Skipping FieldValue for key: $key');
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
            print('[AuthService] Skipping FieldValue in list for key: $key');
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

  // Get cached profile
  Future<Map<String, dynamic>?> _getCachedProfile() async {
    try {
      final box = await Hive.openBox(_userBox);
      final cachedData = box.get('user_profile');
      
      if (cachedData == null) return null;
      
      // Safely convert dynamic data to Map<String, dynamic>
      if (cachedData is Map) {
        final profileData = Map<String, dynamic>.from(cachedData);
        
        // Convert cached data back to usable format
        return _convertHiveDataToUsable(profileData);
      } else {
        print('[AuthService] Invalid cached profile data type: ${cachedData.runtimeType}');
        return null;
      }
    } catch (e) {
      print('[AuthService] Error retrieving cached profile: $e');
      return null;
    }
  }

  /// Convert Hive cached data back to usable format
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
          print('[AuthService] Error parsing date string for key $key: $e');
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
              print('[AuthService] Error parsing date string in list: $e');
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

  /// Check if a string is an ISO 8601 date format
  bool _isIso8601Date(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear cached profile
  Future<void> _clearCachedProfile() async {
    final box = await Hive.openBox(_userBox);
    await box.delete('user_profile');
  }

  // Store verification ID
  Future<void> _storeVerificationId(String verificationId) async {
    final box = await Hive.openBox(_userBox);
    await box.put('verification_id', verificationId);
  }

  // Get stored verification ID
  Future<String?> _getStoredVerificationId() async {
    final box = await Hive.openBox(_userBox);
    return box.get('verification_id') as String?;
  }

  // Sync offline changes
  Future<void> syncOfflineChanges() async {
    if (currentUser == null) return;

    try {
      final cachedProfile = await _getCachedProfile();
      if (cachedProfile != null) {
        // Check if cached profile is newer than Firestore
        final docRef = _firestore.collection('teachers').doc(currentUser!.uid);
        final doc = await docRef.get();
        
        if (doc.exists) {
          final firestoreProfile = doc.data()!;
          final cachedTime = DateTime.parse(cachedProfile['lastUpdated'] ?? DateTime.now().toIso8601String());
          final firestoreTime = (firestoreProfile['lastUpdated'] as Timestamp).toDate();
          
          if (cachedTime.isAfter(firestoreTime)) {
            // Use safe update method
            await _safeUpdateDocument('teachers', currentUser!.uid, cachedProfile);
          }
        } else {
          // Document doesn't exist, create it with cached data
          await _safeUpdateDocument('teachers', currentUser!.uid, cachedProfile);
        }
      }
    } catch (e) {
      print('Failed to sync offline changes: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  

  // Dispose resources
  void dispose() {
    _authStateController.close();
  }
} 