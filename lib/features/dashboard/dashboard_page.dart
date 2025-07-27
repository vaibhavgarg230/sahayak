import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../agents/agent_manager.dart';
import '../../agents/whisper_mode_agent.dart';
import '../../agents/ask_me_later_agent.dart';
import '../../agents/visual_aid_generator_agent.dart';
import '../../services/lesson_service.dart';
import '../../services/ai_service.dart';
import '../../services/voice_service.dart';
import '../../services/vertex_ai_service.dart';
import '../../agents/memory/teacher_memory.dart';
import '../../services/visual_aid_service.dart';
import '../whisper_mode/whisper_mode_page.dart';
import '../ask_me_later/ask_me_later_page.dart';
import '../visual_aid/visual_aid_page.dart';
import '../profile_setup/profile_setup_page.dart';
import '../students/student_list_page.dart';
import '../planner/curriculum_upload_page.dart';
import '../planner/weekly_planner_page.dart';
import '../hyperlocal_content/hyperlocal_content_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  AgentManager? _agentManager;
  WhisperModeAgent? _whisperModeAgent;
  AskMeLaterAgent? _askMeLaterAgent;
  VisualAidGeneratorAgent? _visualAidGeneratorAgent;
  
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _initializeAgents();
    _loadUserProfile();
  }

  Future<void> _initializeAgents() async {
    try {
      final vertexAIService = VertexAIService();
      await vertexAIService.initialize();

      final voiceService = VoiceService();
      await voiceService.initialize();

      _agentManager = AgentManager();
      
      final teacherMemory = TeacherMemory();
      final lessonService = LessonService();
      final aiService = AIService();
      final visualAidService = VisualAidService();

      _whisperModeAgent = WhisperModeAgent(
        teacherMemory: teacherMemory,
        lessonService: lessonService,
        voiceService: voiceService,
        aiService: aiService,
      );
      _agentManager!.registerAgent(_whisperModeAgent!);

      _askMeLaterAgent = AskMeLaterAgent(
        teacherMemory: teacherMemory,
        aiService: aiService,
        voiceService: voiceService,
      );
      _agentManager!.registerAgent(_askMeLaterAgent!);

      _visualAidGeneratorAgent = VisualAidGeneratorAgent(
        voiceService: voiceService,
        aiService: aiService,
        teacherMemory: teacherMemory,
        visualAidService: visualAidService,
      );
      _agentManager!.registerAgent(_visualAidGeneratorAgent!);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize agents: $e';
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      // Wait for auth service to load profile
      await Future.delayed(const Duration(milliseconds: 500));
      
      final profile = _authService.currentUserProfile;
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user profile: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = '';
                    _isLoading = true;
                  });
                  _initializeAgents();
                  _loadUserProfile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sahayak Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              
              // Quick Actions
              _buildQuickActionsSection(),
              const SizedBox(height: 24),
              
              // Grade-Subject Combinations
              _buildGradeSubjectSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userName = _userProfile?['name'] ?? 'Teacher';
    // EMERGENCY FIX: Safe type conversion from List<dynamic> to List<String>
    final grades = List<String>.from((_userProfile?['grades'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? ''));
    final subjects = List<String>.from((_userProfile?['subjects'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? ''));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $userName!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to inspire your students?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (grades.isNotEmpty || subjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (grades.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${grades.length} Grade${grades.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (subjects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${subjects.length} Subject${subjects.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.mic,
                title: 'Whisper Mode',
                subtitle: 'Voice lessons',
                color: Colors.blue[600]!,
                onTap: _openWhisperMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.question_answer,
                title: 'Ask Me Later',
                subtitle: 'AI Q&A queue',
                color: Colors.purple[600]!,
                onTap: _openAskMeLater,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.upload_file,
                title: 'Curriculum',
                subtitle: 'Upload syllabus',
                color: Colors.indigo[600]!,
                onTap: _openCurriculumUpload,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.auto_awesome,
                title: 'Weekly Planner',
                subtitle: 'Auto-schedule topics',
                color: Colors.green[600]!,
                onTap: _openWeeklyPlanner,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.people,
                title: 'Students',
                subtitle: 'Manage class',
                color: Colors.orange[600]!,
                onTap: () => _openClassDashboard('Class 5', 'Mathematics'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.auto_stories,
                title: 'Hyperlocal Stories',
                subtitle: 'AI village tales',
                color: Colors.purple[600]!,
                onTap: _openHyperlocalContent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.image,
                title: 'Visual Aids',
                subtitle: 'Create diagrams',
                color: Colors.teal[600]!,
                onTap: _openVisualAidGenerator,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradeSubjectSection() {
    // EMERGENCY FIX: Safe type conversion from List<dynamic> to List<String>
    final grades = List<String>.from((_userProfile?['grades'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? ''));
    final subjects = List<String>.from((_userProfile?['subjects'] as List<dynamic>? ?? []).map((e) => e?.toString() ?? ''));

    if (grades.isEmpty || subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange[600],
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your grades and subjects to get personalized features.',
              style: TextStyle(
                color: Colors.orange[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _completeProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Complete Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Classes',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildGradeSubjectCombinations(grades, subjects),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSubjectCombinations(List<String> grades, List<String> subjects) {
    final combinations = <Map<String, String>>[];
    
    for (final grade in grades) {
      for (final subject in subjects) {
        combinations.add({
          'grade': grade,
          'subject': subject,
        });
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: combinations.length,
      itemBuilder: (context, index) {
        final combination = combinations[index];
        return _buildClassCard(
          grade: combination['grade']!,
          subject: combination['subject']!,
        );
      },
    );
  }

  Widget _buildClassCard({required String grade, required String subject}) {
    return GestureDetector(
      onTap: () => _openClassDashboard(grade, subject),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.class_,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grade,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.people,
                    label: 'Students',
                    onTap: () => _openClassDashboard(grade, subject),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.assessment,
                    label: 'Progress',
                    onTap: () => _openClassDashboard(grade, subject),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _openWhisperMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WhisperModePage(
          agent: _whisperModeAgent!,
        ),
      ),
    );
  }

  void _openAskMeLater() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AskMeLaterPage(
          agent: _askMeLaterAgent!,
        ),
      ),
    );
  }

  void _openVisualAidGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VisualAidPage(
          agent: _visualAidGeneratorAgent!,
          voiceService: VoiceService(),
        ),
      ),
    );
  }

  void _openCurriculumUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CurriculumUploadPage(),
      ),
    );
  }

  void _openWeeklyPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WeeklyPlannerPage(),
      ),
    );
  }

  void _openHyperlocalContent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HyperlocalContentPage(),
      ),
    );
  }

  void _openStudentManagement() {
    // Navigate to student management - for now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Management'),
        content: const Text('Student management features are now available! Navigate to your classes to manage students.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openAttendanceManagement() {
    // Navigate to attendance management - for now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Management'),
        content: const Text('Attendance tracking features are now available! Navigate to your classes to mark attendance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openPerformanceManagement() {
    // Navigate to performance management - for now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Management'),
        content: const Text('Performance tracking features are now available! Navigate to your classes to enter scores.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openAnalytics() {
    // Navigate to analytics - for now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: const Text('Analytics features are now available! View detailed statistics for your classes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openClassDashboard(String grade, String subject) {
    // Navigate to student list page for the specific class
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentListPage(
          grade: grade,
          subject: subject,
        ),
      ),
    );
  }

  void _completeProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupPage(),
      ),
    );
  }
} 