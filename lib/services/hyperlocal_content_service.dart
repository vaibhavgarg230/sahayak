import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'vertex_ai_service.dart';

class HyperlocalStory {
  final String id;
  final String teacherId;
  final String topic;
  final String grade;
  final String language;
  final String storyText;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime lastUpdated;

  HyperlocalStory({
    required this.id,
    required this.teacherId,
    required this.topic,
    required this.grade,
    required this.language,
    required this.storyText,
    this.audioUrl,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'topic': topic,
      'grade': grade,
      'language': language,
      'storyText': storyText,
      'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory HyperlocalStory.fromMap(Map<String, dynamic> map, String id) {
    return HyperlocalStory(
      id: id,
      teacherId: map['teacherId'] ?? '',
      topic: map['topic'] ?? '',
      grade: map['grade'] ?? '',
      language: map['language'] ?? '',
      storyText: map['storyText'] ?? '',
      audioUrl: map['audioUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  HyperlocalStory copyWith({
    String? id,
    String? teacherId,
    String? topic,
    String? grade,
    String? language,
    String? storyText,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return HyperlocalStory(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      topic: topic ?? this.topic,
      grade: grade ?? this.grade,
      language: language ?? this.language,
      storyText: storyText ?? this.storyText,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class HyperlocalContentService {
  static final HyperlocalContentService _instance = HyperlocalContentService._internal();
  factory HyperlocalContentService() => _instance;
  HyperlocalContentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterTts _flutterTts = FlutterTts();
  final VertexAIService _vertexAIService = VertexAIService();
  
  late Box<dynamic> _storyBox;
  late Box<dynamic> _templateBox;

  Future<void> initialize() async {
    _storyBox = await Hive.openBox('hyperlocal_stories_cache');
    _templateBox = await Hive.openBox('story_templates_cache');
    
    // Initialize TTS
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Initialize Vertex AI
    await _vertexAIService.initialize();
    
    // Load offline templates if not already loaded
    await _loadOfflineTemplates();
  }

  // ==================== STORY GENERATION ====================

  Future<HyperlocalStory> generateStory({
    required String teacherId,
    required String topic,
    required String grade,
    required String language,
  }) async {
    try {
      // Generate story using Vertex AI
      final storyText = await _generateStoryWithAI(topic, grade, language);
      
      // Create story object
      final story = HyperlocalStory(
        id: '',
        teacherId: teacherId,
        topic: topic,
        grade: grade,
        language: language,
        storyText: storyText,
        audioUrl: null,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('hyperlocal_stories')
          .add(story.toMap());

      final savedStory = story.copyWith(id: docRef.id);
      
      // Cache locally
      await _cacheStory(savedStory);
      
      return savedStory;
    } catch (e) {
      print('[HyperlocalContentService] Error generating story: $e');
      // Fallback to offline template
      return _getOfflineTemplate(topic, grade, language, teacherId);
    }
  }

  Future<String> _generateStoryWithAI(String topic, String grade, String language) async {
    final prompt = _buildPrompt(topic, grade, language);
    
    try {
      final response = await _vertexAIService.generateText(prompt);
      return response.trim();
    } catch (e) {
      print('[HyperlocalContentService] Vertex AI generation failed: $e');
      throw Exception('Failed to generate story with Vertex AI');
    }
  }

  String _buildPrompt(String topic, String grade, String language) {
    final languageContext = _getLanguageContext(language);
    final gradeContext = _getGradeContext(grade);
    
    return '''
You are a creative teacher in a rural Indian village. Create a simple, engaging story that explains the concept of "$topic" to a $grade student.

REQUIREMENTS:
- Write in $languageContext
- Make it culturally relevant to rural Indian village life
- Use simple language appropriate for $gradeContext
- Include familiar village elements (farming, animals, local markets, etc.)
- Keep the story under 300 words
- Make it educational but entertaining
- Include dialogue between village characters
- End with a clear understanding of the concept

STORY STRUCTURE:
1. Introduce village characters
2. Present a problem related to the concept
3. Show how the concept helps solve the problem
4. End with learning and celebration

Generate a warm, engaging story that connects "$topic" to everyday village life.
''';
  }

  String _getLanguageContext(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':
        return 'simple Hindi with some English words mixed in (Hinglish)';
      case 'english':
        return 'simple English with some Hindi words for cultural context';
      case 'marathi':
        return 'simple Marathi with some English words mixed in';
      case 'gujarati':
        return 'simple Gujarati with some English words mixed in';
      case 'tamil':
        return 'simple Tamil with some English words mixed in';
      case 'telugu':
        return 'simple Telugu with some English words mixed in';
      case 'kannada':
        return 'simple Kannada with some English words mixed in';
      case 'malayalam':
        return 'simple Malayalam with some English words mixed in';
      case 'bengali':
        return 'simple Bengali with some English words mixed in';
      case 'punjabi':
        return 'simple Punjabi with some English words mixed in';
      default:
        return 'simple English with some Hindi words for cultural context';
    }
  }

  String _getGradeContext(String grade) {
    switch (grade.toLowerCase()) {
      case 'class 1':
      case 'class 2':
        return 'very young children (6-7 years old)';
      case 'class 3':
      case 'class 4':
        return 'young children (8-9 years old)';
      case 'class 5':
      case 'class 6':
        return 'pre-teens (10-11 years old)';
      case 'class 7':
      case 'class 8':
        return 'early teens (12-13 years old)';
      case 'class 9':
      case 'class 10':
        return 'teens (14-15 years old)';
      case 'class 11':
      case 'class 12':
        return 'older teens (16-17 years old)';
      default:
        return 'children (8-12 years old)';
    }
  }

  // ==================== OFFLINE TEMPLATES ====================

  Future<void> _loadOfflineTemplates() async {
    if (_templateBox.isEmpty) {
      final templates = _getDefaultTemplates();
      for (final template in templates) {
        await _templateBox.put(template['key'], template);
      }
    }
  }

  HyperlocalStory _getOfflineTemplate(String topic, String grade, String language, String teacherId) {
    final key = '${topic.toLowerCase()}_${grade.toLowerCase()}_${language.toLowerCase()}';
    final template = _templateBox.get(key) ?? _templateBox.get('default');
    
    return HyperlocalStory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      teacherId: teacherId,
      topic: topic,
      grade: grade,
      language: language,
      storyText: template['story'] ?? _getDefaultStory(topic),
      audioUrl: null,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  List<Map<String, dynamic>> _getDefaultTemplates() {
    return [
      {
        'key': 'addition_class 5_hindi',
        'story': '''गाँव में रामू किसान के पास 3 बकरियाँ थीं। एक दिन उसने बाजार से 2 और बकरियाँ खरीदीं। अब उसके पास कितनी बकरियाँ हैं?

रामू ने गिना: पहले 3 बकरियाँ + नई 2 बकरियाँ = 5 बकरियाँ

"वाह! अब मेरे पास 5 बकरियाँ हैं," रामू खुशी से बोला। उसकी पत्नी सीता ने कहा, "हाँ, यही है जोड़ (Addition)। जब हम दो चीज़ें मिलाते हैं, तो हमें ज्यादा मिलता है।"

रामू के बच्चे भी समझ गए कि जोड़ कैसे काम करता है। अब वे अपनी बकरियों को गिनते समय जोड़ का उपयोग करते हैं।'''
      },
      {
        'key': 'multiplication_class 5_hindi',
        'story': '''गाँव में लक्ष्मी दीदी के पास 4 बक्से हैं। हर बक्से में 3 सेब हैं। कुल कितने सेब हैं?

लक्ष्मी ने गिना: 4 बक्से × 3 सेब = 12 सेब

"यह है गुणा (Multiplication)," लक्ष्मी ने अपने छोटे भाई को समझाया। "जब हम एक ही चीज़ को कई बार जोड़ते हैं, तो गुणा का उपयोग करते हैं।"

उसका भाई समझ गया कि 4 × 3 का मतलब है 3 + 3 + 3 + 3 = 12। अब वह भी गुणा करना सीख गया है।'''
      },
      {
        'key': 'photosynthesis_class 7_english',
        'story': '''In a small village, there was a wise old tree named Banyan Baba. One day, little Sunita asked, "Baba, how do you make your own food?"

Banyan Baba smiled and explained, "I use sunlight, water, and air to make my food. This process is called photosynthesis."

"Really? How?" Sunita was curious.

"Watch," said Baba. "The sun gives me energy, I take water from the soil through my roots, and I breathe in carbon dioxide from the air. My green leaves mix all these together and make sugar - my food!"

Sunita was amazed. "So you're like a kitchen that cooks with sunlight!"

"Exactly!" Baba laughed. "And I give back oxygen for all of you to breathe. That's why trees are so important in our village."'''
      },
      {
        'key': 'democracy_class 8_english',
        'story': '''In a small village called Gram Panchayat, the villagers had to choose their new leader. Old farmer Ram Singh explained democracy to the children.

"Democracy means 'rule by the people,'" he said. "Every adult villager gets one vote, and the person with the most votes becomes our leader."

Little Priya asked, "What if someone doesn't like the winner?"

"Good question!" Ram Singh replied. "In democracy, we respect everyone's choice. The winner works for all villagers, not just those who voted for them. And after five years, we vote again."

"So everyone's voice matters?" asked Priya.

"Exactly! That's why democracy is so special. Even the poorest farmer has the same voting power as the richest person in the village."'''
      },
      {
        'key': 'default',
        'story': '''गाँव में एक बुद्धिमान किसान था जो हमेशा नई चीज़ें सीखता था। एक दिन उसने अपने बच्चों को समझाया कि जीवन में सीखना कितना महत्वपूर्ण है।

"हर दिन कुछ नया सीखो," उसने कहा। "ज्ञान ही सबसे बड़ा धन है।"

उसके बच्चे समझ गए और पढ़ाई में मन लगाने लगे। आज भी गाँव में शिक्षा को सबसे ऊपर रखा जाता है।'''
      },
    ];
  }

  String _getDefaultStory(String topic) {
    return '''गाँव में एक बुद्धिमान किसान था जो हमेशा नई चीज़ें सीखता था। एक दिन उसने अपने बच्चों को "$topic" के बारे में समझाया।

"यह एक महत्वपूर्ण अवधारणा है," उसने कहा। "इसे ध्यान से समझो और अपने जीवन में उपयोग करो।"

उसके बच्चे समझ गए और आज भी गाँव में इस ज्ञान का उपयोग किया जाता है।''';
  }

  // ==================== STORY MANAGEMENT ====================

  Future<List<HyperlocalStory>> getTeacherStories(String teacherId) async {
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('hyperlocal_stories')
          .orderBy('createdAt', descending: true)
          .get();

      final stories = querySnapshot.docs
          .map((doc) => HyperlocalStory.fromMap(doc.data(), doc.id))
          .toList();

      // Cache the stories
      for (final story in stories) {
        await _cacheStory(story);
      }

      return stories;
    } catch (e) {
      print('[HyperlocalContentService] Error fetching from Firestore: $e');
      // Fallback to cache
      return _getStoriesFromCache(teacherId);
    }
  }

  Future<HyperlocalStory?> getStoryById(String teacherId, String storyId) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('hyperlocal_stories')
          .doc(storyId)
          .get();

      if (doc.exists) {
        return HyperlocalStory.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('[HyperlocalContentService] Error fetching story: $e');
      return null;
    }
  }

  Future<void> deleteStory(String teacherId, String storyId) async {
    try {
      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('hyperlocal_stories')
          .doc(storyId)
          .delete();

      // Remove from cache
      await _storyBox.delete('${teacherId}_$storyId');
    } catch (e) {
      print('[HyperlocalContentService] Error deleting story: $e');
    }
  }

  // ==================== AUDIO GENERATION ====================

  Future<String?> generateAudio(String storyText, String language) async {
    try {
      // Set language for TTS
      final ttsLanguage = _getTTSLanguage(language);
      await _flutterTts.setLanguage(ttsLanguage);
      
      // Generate audio file
      final audioPath = await _flutterTts.speak(storyText);
      return audioPath;
    } catch (e) {
      print('[HyperlocalContentService] Error generating audio: $e');
      return null;
    }
  }

  String _getTTSLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':
        return 'hi-IN';
      case 'english':
        return 'en-US';
      case 'marathi':
        return 'mr-IN';
      case 'gujarati':
        return 'gu-IN';
      case 'tamil':
        return 'ta-IN';
      case 'telugu':
        return 'te-IN';
      case 'kannada':
        return 'kn-IN';
      case 'malayalam':
        return 'ml-IN';
      case 'bengali':
        return 'bn-IN';
      case 'punjabi':
        return 'pa-IN';
      default:
        return 'en-US';
    }
  }

  Future<void> playAudio(String storyText, String language) async {
    try {
      final ttsLanguage = _getTTSLanguage(language);
      await _flutterTts.setLanguage(ttsLanguage);
      await _flutterTts.speak(storyText);
    } catch (e) {
      print('[HyperlocalContentService] Error playing audio: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('[HyperlocalContentService] Error stopping audio: $e');
    }
  }

  // ==================== CACHING ====================

  Future<void> _cacheStory(HyperlocalStory story) async {
    final key = '${story.teacherId}_${story.id}';
    await _storyBox.put(key, {
      'id': story.id,
      'teacherId': story.teacherId,
      'topic': story.topic,
      'grade': story.grade,
      'language': story.language,
      'storyText': story.storyText,
      'audioUrl': story.audioUrl,
      'createdAt': story.createdAt.millisecondsSinceEpoch,
      'lastUpdated': story.lastUpdated.millisecondsSinceEpoch,
    });
  }

  List<HyperlocalStory> _getStoriesFromCache(String teacherId) {
    final stories = <HyperlocalStory>[];
    final keys = _storyBox.keys.where((key) => key.toString().startsWith('${teacherId}_'));
    
    for (final key in keys) {
      final data = _storyBox.get(key);
      if (data != null) {
        stories.add(HyperlocalStory(
          id: data['id'],
          teacherId: data['teacherId'],
          topic: data['topic'],
          grade: data['grade'],
          language: data['language'],
          storyText: data['storyText'],
          audioUrl: data['audioUrl'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated']),
        ));
      }
    }
    
    return stories;
  }

  // ==================== UTILITY METHODS ====================

  List<String> getAvailableGrades() {
    return [
      'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
      'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
      'Class 11', 'Class 12'
    ];
  }

  List<String> getAvailableLanguages() {
    return [
      'English', 'Hindi', 'Marathi', 'Gujarati', 'Tamil',
      'Telugu', 'Kannada', 'Malayalam', 'Bengali', 'Punjabi'
    ];
  }

  void dispose() {
    _flutterTts.stop();
  }
} 