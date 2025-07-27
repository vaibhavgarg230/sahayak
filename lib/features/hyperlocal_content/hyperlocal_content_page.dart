import 'package:flutter/material.dart';
import '../../services/hyperlocal_content_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/story_display_widget.dart';

class HyperlocalContentPage extends StatefulWidget {
  const HyperlocalContentPage({super.key});

  @override
  State<HyperlocalContentPage> createState() => _HyperlocalContentPageState();
}

class _HyperlocalContentPageState extends State<HyperlocalContentPage> {
  final _hyperlocalService = HyperlocalContentService();
  final _authService = AuthService();

  // Form controllers
  final _topicController = TextEditingController();

  // Form state
  String? _selectedGrade;
  String? _selectedLanguage;
  List<HyperlocalStory> _stories = [];
  HyperlocalStory? _currentStory;
  bool _isGenerating = false;
  bool _isLoading = true;
  bool _isOffline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _hyperlocalService.initialize();
      await _loadStories();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final stories = await _hyperlocalService.getTeacherStories(teacherId);
      setState(() {
        _stories = stories;
        _isOffline = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading stories: $e';
        _isOffline = true;
      });
      _showErrorSnackBar('Error loading stories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateStory() async {
    if (!_validateForm()) return;

    setState(() => _isGenerating = true);

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final story = await _hyperlocalService.generateStory(
        teacherId: teacherId,
        topic: _topicController.text.trim(),
        grade: _selectedGrade!,
        language: _selectedLanguage!,
      );

      setState(() {
        _currentStory = story;
        _stories.insert(0, story);
        _isOffline = false;
      });

      _showSuccessSnackBar('Story generated successfully!');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating story: $e';
        _isOffline = true;
      });
      _showErrorSnackBar('Error generating story: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  bool _validateForm() {
    if (_topicController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a topic');
      return false;
    }
    if (_selectedGrade == null) {
      _showErrorSnackBar('Please select a grade');
      return false;
    }
    if (_selectedLanguage == null) {
      _showErrorSnackBar('Please select a language');
      return false;
    }
    return true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyperlocal Stories'),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadStories,
            tooltip: 'Refresh Stories',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildStoryGeneratorForm(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildStoriesList()),
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
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isOffline = false;
              });
              _initializeAndLoadData();
            },
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

  Widget _buildStoryGeneratorForm() {
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
                  'Generate New Story',
                  style: Theme.of(context).textTheme.titleLarge,
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic/Concept',
                hintText: 'e.g., Addition, Photosynthesis, Democracy',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                    ),
                    items: _hyperlocalService.getAvailableGrades().map((grade) {
                      return DropdownMenuItem(value: grade, child: Text(grade));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedGrade = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                    ),
                    items: _hyperlocalService.getAvailableLanguages().map((language) {
                      return DropdownMenuItem(value: language, child: Text(language));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedLanguage = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateStory,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Story'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesList() {
    if (_stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Stories Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first hyperlocal story above',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _stories.length,
      itemBuilder: (context, index) {
        final story = _stories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(
                Icons.book,
                color: Colors.white,
              ),
            ),
            title: Text(
              story.topic,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${story.grade} • ${story.language}'),
                const SizedBox(height: 4),
                Text(
                  story.storyText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playStory(story),
              tooltip: 'Play Story',
            ),
            onTap: () => _showStoryDetails(story),
          ),
        );
      },
    );
  }

  void _playStory(HyperlocalStory story) async {
    try {
      await _hyperlocalService.playAudio(story.storyText, story.language);
    } catch (e) {
      _showErrorSnackBar('Error playing audio: $e');
    }
  }

  void _showStoryDetails(HyperlocalStory story) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StoryDisplayWidget(
          story: story,
          onPlayAudio: () => _playStory(story),
        ),
      ),
    );
  }
}