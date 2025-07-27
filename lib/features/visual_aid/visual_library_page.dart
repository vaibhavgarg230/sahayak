import 'package:flutter/material.dart';
import '../../agents/visual_aid_generator_agent.dart';
import '../../services/voice_service.dart';

class VisualLibraryPage extends StatefulWidget {
  final VisualAidGeneratorAgent agent;
  final VoiceService voiceService;

  const VisualLibraryPage({
    Key? key,
    required this.agent,
    required this.voiceService,
  }) : super(key: key);

  @override
  State<VisualLibraryPage> createState() => _VisualLibraryPageState();
}

class _VisualLibraryPageState extends State<VisualLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myVisualAids = [];
  List<Map<String, dynamic>> _sharedVisualAids = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load teacher's visual aids
      final myAids = await widget.agent.getTeacherVisualLibrary();
      
      // Load shared visual aids
      final sharedAids = await widget.agent.getSharedVisualAids();
      
      // Load analytics
      final analytics = await widget.agent.getAnalytics();

      setState(() {
        _myVisualAids = myAids;
        _sharedVisualAids = sharedAids;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _searchVisualAids(String query) async {
    if (query.isEmpty) {
      await _loadData();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await widget.agent.searchVisualAids(query);
      setState(() {
        _myVisualAids = results.where((aid) => aid['teacherId'] == 'default_teacher').toList();
        _sharedVisualAids = results.where((aid) => aid['shared'] == true).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rateVisualAid(String visualAidId, int rating) async {
    try {
      await widget.agent.rateVisualAid(visualAidId, rating);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating submitted successfully!')),
      );
      await _loadData(); // Reload to update analytics
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    }
  }

  Future<void> _shareVisualAid(String visualAidId, bool shared) async {
    try {
      await widget.agent.shareVisualAid(visualAidId, shared);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shared ? 'Visual aid shared!' : 'Visual aid unshared!')),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing visual aid: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Visual Aid Library'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'My Library', icon: Icon(Icons.person)),
            Tab(text: 'Shared', icon: Icon(Icons.share)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.purple],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search visual aids...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _loadData();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _searchVisualAids(value);
                  },
                ),
              ),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    _buildFilterChip('math', 'Math'),
                    _buildFilterChip('science', 'Science'),
                    _buildFilterChip('english', 'English'),
                    _buildFilterChip('hindi', 'Hindi'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyLibraryTab(),
                    _buildSharedTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
          _applyFilter();
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.orange,
        checkmarkColor: Colors.white,
      ),
    );
  }

  void _applyFilter() {
    // Apply filter logic here
    _loadData();
  }

  Widget _buildMyLibraryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_myVisualAids.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'No visual aids yet.\nGenerate some to see them here!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myVisualAids.length,
      itemBuilder: (context, index) {
        final visualAid = _myVisualAids[index];
        return _buildVisualAidCard(visualAid, true);
      },
    );
  }

  Widget _buildSharedTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_sharedVisualAids.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'No shared visual aids yet.\nShare yours to help other teachers!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sharedVisualAids.length,
      itemBuilder: (context, index) {
        final visualAid = _sharedVisualAids[index];
        return _buildVisualAidCard(visualAid, false);
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Total Visual Aids',
                  '${_analytics['totalVisualAids'] ?? 0}',
                  Icons.image,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Total Usage',
                  '${_analytics['totalUsage'] ?? 0}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Avg Effectiveness',
                  '${(_analytics['averageEffectiveness'] ?? 0).toStringAsFixed(1)}/5',
                  Icons.star,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Shared',
                  '${_myVisualAids.where((aid) => aid['shared'] == true).length}',
                  Icons.share,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Subject Distribution
          const Text(
            'Subject Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_analytics['subjectDistribution'] != null)
            ...(_analytics['subjectDistribution'] as Map<String, dynamic>).entries.map(
              (entry) => _buildSubjectDistributionItem(entry.key, entry.value),
            ),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_analytics['recentActivity'] != null)
            ...(_analytics['recentActivity'] as List).map(
              (activity) => _buildRecentActivityItem(activity),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDistributionItem(String subject, int count) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSubjectColor(subject),
          child: Text(
            subject[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(subject.toUpperCase()),
        trailing: Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityItem(Map<String, dynamic> activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Colors.grey),
        title: Text(activity['topic'] ?? 'Unknown'),
        subtitle: Text('Used ${activity['usageCount'] ?? 0} times'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildVisualAidCard(Map<String, dynamic> visualAid, bool isOwn) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visualAid['topic'] ?? 'Unknown Topic',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Text(
                        '${visualAid['subject']?.toString().toUpperCase()} • ${visualAid['gradeLevel'] ?? 'Primary'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'share':
                          _shareVisualAid(visualAid['id'], !(visualAid['shared'] ?? false));
                          break;
                        case 'delete':
                          _showDeleteDialog(visualAid['id']);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(
                              visualAid['shared'] == true ? Icons.share : Icons.share_outlined,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 8),
                            Text(visualAid['shared'] == true ? 'Unshare' : 'Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Visual Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                visualAid['visualContent'] ?? 'No content',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Explanation
            if (visualAid['explanation'] != null) ...[
              const Text(
                'Explanation:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                visualAid['explanation'],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            
            // Stats and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${visualAid['usageCount'] ?? 0}'),
                    const SizedBox(width: 16),
                    Icon(Icons.star, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${visualAid['effectiveness'] ?? 0}'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 20),
                      onPressed: () => _speakExplanation(visualAid['explanation']),
                      tooltip: 'Speak explanation',
                    ),
                    if (!isOwn)
                      IconButton(
                        icon: const Icon(Icons.star_border, size: 20),
                        onPressed: () => _showRatingDialog(visualAid['id']),
                        tooltip: 'Rate effectiveness',
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'math':
        return Colors.blue;
      case 'science':
        return Colors.green;
      case 'english':
        return Colors.orange;
      case 'hindi':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _speakExplanation(String? explanation) async {
    if (explanation == null) return;
    
    try {
      await widget.voiceService.speak(explanation);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error speaking explanation: $e')),
      );
    }
  }

  void _showRatingDialog(String visualAidId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Effectiveness'),
        content: const Text('How effective was this visual aid?'),
        actions: List.generate(5, (index) {
          return TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rateVisualAid(visualAidId, index + 1);
            },
            child: Text('${index + 1}'),
          );
        }),
      ),
    );
  }

  void _showDeleteDialog(String visualAidId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Visual Aid'),
        content: const Text('Are you sure you want to delete this visual aid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement delete functionality
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
} 