import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final AuthService _authService = AuthService();
  
  List<String> _selectedGrades = [];
  List<String> _selectedSubjects = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome to Sahayak!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Let\'s personalize your experience by selecting the grades and subjects you teach.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Error Message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[600], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Grades Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSection(
                  title: 'Grades You Teach',
                  subtitle: 'Select all grades you currently teach',
                  icon: Icons.grade,
                  children: [
                    _buildMultiSelectGrid(
                      items: _authService.getAvailableGrades(),
                      selectedItems: _selectedGrades,
                      onSelectionChanged: (grades) {
                        setState(() {
                          _selectedGrades = grades;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
            
            // Subjects Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSection(
                  title: 'Subjects You Teach',
                  subtitle: 'Select all subjects you currently teach',
                  icon: Icons.book,
                  children: [
                    _buildMultiSelectGrid(
                      items: _authService.getAvailableSubjects(),
                      selectedItems: _selectedSubjects,
                      onSelectionChanged: (subjects) {
                        setState(() {
                          _selectedSubjects = subjects;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
            
            // Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canContinue() && !_isLoading ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Continue to Dashboard',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Skip for now option
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _skipProfileSetup,
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom padding for safe area
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMultiSelectGrid({
    required List<String> items,
    required List<String> selectedItems,
    required Function(List<String>) onSelectionChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth > 600 ? 3.0 : 2.5, // Responsive aspect ratio
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = selectedItems.contains(item);
            
            return GestureDetector(
              onTap: () {
                final newSelection = List<String>.from(selectedItems);
                if (isSelected) {
                  newSelection.remove(item);
                } else {
                  newSelection.add(item);
                }
                onSelectionChanged(newSelection);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[600] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _canContinue() {
    return _selectedGrades.isNotEmpty && _selectedSubjects.isNotEmpty;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.updateGradesAndSubjects(_selectedGrades, _selectedSubjects);
      
      setState(() {
        _isLoading = false;
      });

      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DashboardPage(),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
        _isLoading = false;
      });
    }
  }

  void _skipProfileSetup() {
    // Navigate to dashboard without completing profile
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DashboardPage(),
      ),
    );
  }
} 