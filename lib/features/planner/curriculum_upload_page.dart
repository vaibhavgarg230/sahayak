import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/curriculum.dart';
import '../../services/planner_service.dart';
import '../../services/auth_service.dart';

class CurriculumUploadPage extends StatefulWidget {
  const CurriculumUploadPage({super.key});

  @override
  State<CurriculumUploadPage> createState() => _CurriculumUploadPageState();
}

class _CurriculumUploadPageState extends State<CurriculumUploadPage> {
  final _plannerService = PlannerService();
  final _authService = AuthService();

  // Selected values
  String? _selectedBoard;
  String? _selectedGrade;
  String? _selectedSubject;
  DateTime? _startDate;
  DateTime? _endDate;

  // Topics management
  final List<CurriculumTopic> _topics = [];
  final _topicTitleController = TextEditingController();
  final _topicDescriptionController = TextEditingController();

  // File upload
  File? _selectedPDF;
  String? _pdfUrl;
  String? _pdfName;
  bool _isUploadingPDF = false;

  // Loading states
  bool _isSaving = false;
  bool _isOffline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _plannerService.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize service: $e';
        _isOffline = true;
      });
    }
  }

  @override
  void dispose() {
    _topicTitleController.dispose();
    _topicDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedPDF = File(file.path!);
          _pdfName = file.name;
          _isUploadingPDF = true;
        });

        await _uploadPDF();
      }
    } catch (e) {
      _showErrorSnackBar('Error picking PDF: $e');
    }
  }

  Future<void> _uploadPDF() async {
    if (_selectedPDF == null) return;

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final url = await _plannerService.uploadCurriculumPDF(teacherId, _selectedPDF!);
      setState(() {
        _pdfUrl = url;
        _isUploadingPDF = false;
      });
      _showSuccessSnackBar('PDF uploaded successfully');
    } catch (e) {
      setState(() => _isUploadingPDF = false);
      _showErrorSnackBar('Error uploading PDF: $e');
    }
  }

  void _addTopic() {
    final title = _topicTitleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('Please enter a topic title');
      return;
    }

    final topic = CurriculumTopic(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: _topicDescriptionController.text.trim(),
      order: _topics.length + 1,
      createdAt: DateTime.now(),
    );

    setState(() {
      _topics.add(topic);
      _topicTitleController.clear();
      _topicDescriptionController.clear();
    });
  }

  void _removeTopic(int index) {
    setState(() {
      _topics.removeAt(index);
      // Reorder remaining topics
      for (int i = 0; i < _topics.length; i++) {
        _topics[i] = _topics[i].copyWith(order: i + 1);
      }
    });
  }

  void _moveTopicUp(int index) {
    if (index > 0) {
      setState(() {
        final topic = _topics[index];
        _topics[index] = _topics[index - 1];
        _topics[index - 1] = topic;
        // Update order
        _topics[index] = _topics[index].copyWith(order: index + 1);
        _topics[index - 1] = _topics[index - 1].copyWith(order: index);
      });
    }
  }

  void _moveTopicDown(int index) {
    if (index < _topics.length - 1) {
      setState(() {
        final topic = _topics[index];
        _topics[index] = _topics[index + 1];
        _topics[index + 1] = topic;
        // Update order
        _topics[index] = _topics[index].copyWith(order: index + 1);
        _topics[index + 1] = _topics[index + 1].copyWith(order: index + 2);
      });
    }
  }

  Future<void> _saveCurriculum() async {
    if (!_validateForm()) return;

    setState(() => _isSaving = true);

    try {
      final teacherId = _authService.currentUser?.uid;
      if (teacherId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final curriculumId = await _plannerService.createCurriculum(
        teacherId: teacherId,
        board: _selectedBoard!,
        grade: _selectedGrade!,
        subject: _selectedSubject!,
        startDate: _startDate!,
        endDate: _endDate!,
        topics: _topics,
        pdfUrl: _pdfUrl,
        pdfName: _pdfName,
      );

      _showSuccessSnackBar('Curriculum created successfully!');
      Navigator.of(context).pop(curriculumId);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating curriculum: $e';
        _isOffline = true;
      });
      _showErrorSnackBar('Error creating curriculum: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _validateForm() {
    if (_selectedBoard == null) {
      _showErrorSnackBar('Please select a board');
      return false;
    }
    if (_selectedGrade == null) {
      _showErrorSnackBar('Please select a grade');
      return false;
    }
    if (_selectedSubject == null) {
      _showErrorSnackBar('Please select a subject');
      return false;
    }
    if (_startDate == null) {
      _showErrorSnackBar('Please select a start date');
      return false;
    }
    if (_endDate == null) {
      _showErrorSnackBar('Please select an end date');
      return false;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showErrorSnackBar('End date must be after start date');
      return false;
    }
    if (_topics.isEmpty) {
      _showErrorSnackBar('Please add at least one topic');
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
        title: const Text('Create Curriculum'),
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
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfoSection(),
                  const SizedBox(height: 16),
                  _buildDateSelectionSection(),
                  const SizedBox(height: 16),
                  _buildPDFUploadSection(),
                  const SizedBox(height: 16),
                  _buildTopicsSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
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
              _initializeService();
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

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Basic Information',
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
            DropdownButtonFormField<String>(
              value: _selectedBoard,
              decoration: const InputDecoration(
                labelText: 'Board',
                border: OutlineInputBorder(),
              ),
              items: _plannerService.getAvailableBoards().map((board) {
                return DropdownMenuItem(value: board, child: Text(board));
              }).toList(),
              onChanged: (value) => setState(() => _selectedBoard = value),
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
                    items: _plannerService.getAvailableGrades().map((grade) {
                      return DropdownMenuItem(value: grade, child: Text(grade));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedGrade = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _plannerService.getAvailableSubjects().map((subject) {
                      return DropdownMenuItem(value: subject, child: Text(subject));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSubject = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Select Date',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'Select Date',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPDFUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Curriculum PDF (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_pdfName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.file_present, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pdfName!,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedPDF = null;
                          _pdfUrl = null;
                          _pdfName = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No PDF selected',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploadingPDF ? null : _pickPDF,
                icon: _isUploadingPDF
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingPDF ? 'Uploading...' : 'Upload PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Curriculum Topics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildAddTopicForm(),
            const SizedBox(height: 16),
            if (_topics.isNotEmpty) ...[
              Text(
                'Topics (${_topics.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  return _buildTopicItem(_topics[index], index);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddTopicForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _topicTitleController,
            decoration: const InputDecoration(
              labelText: 'Topic Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _topicDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _addTopic,
            icon: const Icon(Icons.add),
            label: const Text('Add Topic'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicItem(CurriculumTopic topic, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            '${topic.order}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(topic.title),
        subtitle: topic.description.isNotEmpty ? Text(topic.description) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: index > 0 ? () => _moveTopicUp(index) : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: index < _topics.length - 1 ? () => _moveTopicDown(index) : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeTopic(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveCurriculum,
        icon: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Creating...' : 'Create Curriculum'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
} 