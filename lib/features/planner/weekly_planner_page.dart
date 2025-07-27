import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/curriculum.dart';
import '../../services/planner_service.dart';
import '../../services/auth_service.dart';
import 'curriculum_upload_page.dart';

class WeeklyPlannerPage extends StatefulWidget {
  const WeeklyPlannerPage({super.key});

  @override
  State<WeeklyPlannerPage> createState() => _WeeklyPlannerPageState();
}

class _WeeklyPlannerPageState extends State<WeeklyPlannerPage> {
  final _plannerService = PlannerService();
  final _authService = AuthService();

  List<Curriculum> _curricula = [];
  Curriculum? _selectedCurriculum;
  List<WeeklyPlan> _weeklyPlans = [];
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isOffline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _plannerService.initialize();
      await _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize planner: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final curricula = await _plannerService.getTeacherCurricula(teacherId);
      setState(() {
        _curricula = curricula;
        if (curricula.isNotEmpty) {
          _selectedCurriculum = curricula.first;
        }
      });

      if (_selectedCurriculum != null) {
        await _loadWeeklyPlans();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isOffline = true;
      });
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeeklyPlans() async {
    if (_selectedCurriculum == null) return;

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) return;

      final plans = await _plannerService.getWeeklyPlans(teacherId, _selectedCurriculum!.id);
      setState(() {
        _weeklyPlans = plans;
        _isOffline = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading weekly plans: $e';
        _isOffline = true;
      });
      _showErrorSnackBar('Error loading weekly plans: $e');
    }
  }

  Future<void> _updateTopicStatus(WeeklyPlan plan, WeeklyTopic topic, TopicStatus newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      await _plannerService.updateTopicStatus(
        teacherId: teacherId,
        planId: plan.id,
        topicId: topic.topicId,
        status: newStatus,
      );

      // Reload weekly plans to get updated data
      await _loadWeeklyPlans();
      _showSuccessSnackBar('Topic status updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error updating topic status: $e');
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _createNewCurriculum() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CurriculumUploadPage(),
      ),
    );

    if (result != null) {
      // Reload data after creating new curriculum
      await _loadData();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor(TopicStatus status) {
    switch (status) {
      case TopicStatus.completed:
        return Colors.green;
      case TopicStatus.incomplete:
        return Colors.red;
      case TopicStatus.pending:
        return Colors.orange;
    }
  }

  String _getStatusText(TopicStatus status) {
    switch (status) {
      case TopicStatus.completed:
        return 'Completed';
      case TopicStatus.incomplete:
        return 'Incomplete';
      case TopicStatus.pending:
        return 'Pending';
    }
  }

  IconData _getStatusIcon(TopicStatus status) {
    switch (status) {
      case TopicStatus.completed:
        return Icons.check_circle;
      case TopicStatus.incomplete:
        return Icons.cancel;
      case TopicStatus.pending:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Planner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewCurriculum,
            tooltip: 'Create New Curriculum',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _curricula.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildCurriculumSelector(),
                        Expanded(child: _buildWeeklyPlansList()),
                      ],
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Curriculum Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first curriculum to start planning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewCurriculum,
            icon: const Icon(Icons.add),
            label: const Text('Create Curriculum'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Select Curriculum',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isOffline)
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Curriculum>(
              value: _selectedCurriculum,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _curricula.map((curriculum) {
                return DropdownMenuItem(
                  value: curriculum,
                  child: Text(
                    '${curriculum.grade} - ${curriculum.subject} (${curriculum.board})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (curriculum) async {
                setState(() => _selectedCurriculum = curriculum);
                if (curriculum != null) {
                  await _loadWeeklyPlans();
                }
              },
            ),
            if (_selectedCurriculum != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Topics',
                      '${_selectedCurriculum!.topics.length}',
                      Icons.book,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Weeks',
                      '${_weeklyPlans.length}',
                      Icons.calendar_view_week,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Duration',
                      '${_selectedCurriculum!.startDate.difference(_selectedCurriculum!.endDate).inDays.abs()} days',
                      Icons.schedule,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlansList() {
    if (_weeklyPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_view_week_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Weekly Plans',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Weekly plans will be generated automatically',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _weeklyPlans.length,
      itemBuilder: (context, index) {
        final plan = _weeklyPlans[index];
        return _buildWeeklyPlanCard(plan);
      },
    );
  }

  Widget _buildWeeklyPlanCard(WeeklyPlan plan) {
    final completedTopics = plan.topics.where((t) => t.status == TopicStatus.completed).length;
    final totalTopics = plan.topics.length;
    final progressPercentage = totalTopics > 0 ? (completedTopics / totalTopics) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${DateFormat('MMM dd').format(plan.weekStart)} - ${DateFormat('MMM dd').format(plan.weekEnd)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${completedTopics}/${totalTopics} topics completed',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getProgressColor(progressPercentage).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(progressPercentage * 100).toInt()}%',
                style: TextStyle(
                  color: _getProgressColor(progressPercentage),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progressPercentage)),
            ),
          ],
        ),
        children: [
          if (plan.topics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No topics assigned to this week',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            ...plan.topics.map((topic) => _buildTopicTile(plan, topic)).toList(),
        ],
      ),
    );
  }

  Widget _buildTopicTile(WeeklyPlan plan, WeeklyTopic topic) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(topic.status).withValues(alpha: 0.1),
        child: Icon(
          _getStatusIcon(topic.status),
          color: _getStatusColor(topic.status),
          size: 20,
        ),
      ),
      title: Text(
        topic.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topic.description.isNotEmpty)
            Text(
              topic.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(topic.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusText(topic.status),
              style: TextStyle(
                color: _getStatusColor(topic.status),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (topic.notes != null && topic.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                topic.notes!,
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
      trailing: _isUpdatingStatus
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<TopicStatus>(
              onSelected: (status) => _updateTopicStatus(plan, topic, status),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: TopicStatus.pending,
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Mark as Pending'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: TopicStatus.completed,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark as Completed'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: TopicStatus.incomplete,
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Mark as Incomplete'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(topic.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: _getStatusColor(topic.status),
                ),
              ),
            ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.5) return Colors.orange;
    return Colors.red;
  }
} 