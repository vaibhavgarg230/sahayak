import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agents/agent_manager.dart';
import 'agents/test_agent.dart';
import 'agents/whisper_mode_agent.dart';
import 'agents/ask_me_later_agent.dart';
import 'agents/visual_aid_generator_agent.dart';
import 'agents/memory/teacher_memory.dart';
import 'services/lesson_service.dart';
import 'services/ai_service.dart';
import 'services/voice_service.dart';
import 'services/vertex_ai_service.dart';
import 'services/visual_aid_service.dart';
import 'features/whisper_mode/whisper_mode_page.dart';
import 'features/ask_me_later/ask_me_later_page.dart';
import 'features/visual_aid/visual_aid_page.dart';
import 'features/authentication/login_page.dart';
import 'features/profile_setup/profile_setup_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/planner/curriculum_upload_page.dart';
import 'features/planner/weekly_planner_page.dart';
import 'features/hyperlocal_content/hyperlocal_content_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Google Cloud services
  final vertexAIService = VertexAIService();
  await vertexAIService.initialize();
  
  final voiceService = VoiceService();
  await voiceService.initialize();

  final agentManager = AgentManager();
  final testAgent = TestAgent();
  agentManager.registerAgent(testAgent);

  final teacherMemory = TeacherMemory();
  final lessonService = LessonService();
  final aiService = AIService();
  
  final whisperModeAgent = WhisperModeAgent(
    teacherMemory: teacherMemory,
    lessonService: lessonService,
    voiceService: voiceService,
    aiService: aiService,
  );
  agentManager.registerAgent(whisperModeAgent);

  final askMeLaterAgent = AskMeLaterAgent(
    teacherMemory: teacherMemory,
    aiService: aiService,
    voiceService: voiceService,
  );
  agentManager.registerAgent(askMeLaterAgent);

  final visualAidService = VisualAidService();
  
  final visualAidGeneratorAgent = VisualAidGeneratorAgent(
    voiceService: voiceService,
    aiService: aiService,
    teacherMemory: teacherMemory,
    visualAidService: visualAidService,
  );
  agentManager.registerAgent(visualAidGeneratorAgent);

  runApp(MyApp(
    agentManager: agentManager,
    whisperModeAgent: whisperModeAgent,
    askMeLaterAgent: askMeLaterAgent,
    visualAidGeneratorAgent: visualAidGeneratorAgent,
  ));
}

class MyApp extends StatelessWidget {
  final AgentManager agentManager;
  final WhisperModeAgent whisperModeAgent;
  final AskMeLaterAgent askMeLaterAgent;
  final VisualAidGeneratorAgent visualAidGeneratorAgent;
  
  const MyApp({
    super.key,
    required this.agentManager,
    required this.whisperModeAgent,
    required this.askMeLaterAgent,
    required this.visualAidGeneratorAgent,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sahayak - Rural Education AI Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => DashboardPage(),
        '/profile-setup': (context) => const ProfileSetupPage(),
        '/curriculum-upload': (context) => const CurriculumUploadPage(),
        '/weekly-planner': (context) => const WeeklyPlannerPage(),
        '/hyperlocal-content': (context) => const HyperlocalContentPage(),
        '/visual-library': (context) => Scaffold(
          appBar: AppBar(title: const Text('Visual Library')),
          body: const Center(child: Text('Visual Library coming soon!')),
        ),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          // User is authenticated, check if profile is complete
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserProfile(snapshot.data!.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final profile = profileSnapshot.data;
              final isProfileComplete = profile?['isProfileComplete'] ?? false;
              
              if (isProfileComplete) {
                // Navigate to dashboard
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pushReplacementNamed('/dashboard');
                });
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              } else {
                // Navigate to profile setup
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pushReplacementNamed('/profile-setup');
                });
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            },
          );
        }
        
        // User is not authenticated, show login page
        return const LoginPage();
      },
    );
  }
  
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}
