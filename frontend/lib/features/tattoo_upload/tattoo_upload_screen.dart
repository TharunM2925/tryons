import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_routes.dart';
import '../../data/models/tattoo_model.dart';
import '../../data/services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import 'tattoo_provider.dart';

/// Screen for uploading and selecting tattoo designs.
class TattooUploadScreen extends StatefulWidget {
  const TattooUploadScreen({super.key});

  @override
  State<TattooUploadScreen> createState() => _TattooUploadScreenState();
}

class _TattooUploadScreenState extends State<TattooUploadScreen> {
  final _nameController = TextEditingController();
  XFile? _pickedFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TattooProvider>().loadTattoos();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedFile = picked);
      // Pre-fill name from filename
      if (_nameController.text.isEmpty) {
        final name = picked.name.split('.').first.replaceAll('_', ' ');
        _nameController.text = name;
      }
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) {
      _showSnack('Please select an image first');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter a name for your tattoo');
      return;
    }

    final provider = context.read<TattooProvider>();
    final tattoo = await provider.uploadTattoo(
      file: _pickedFile!,
      name: _nameController.text.trim(),
    );

    if (mounted) {
      if (tattoo != null) {
        _showSnack('Tattoo uploaded successfully! ✓', isSuccess: true);
        setState(() {
          _pickedFile = null;
          _nameController.clear();
        });
      } else {
        _showSnack(provider.error ?? 'Upload failed');
      }
    }
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.accent : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Tattoo Gallery'),
        backgroundColor: AppTheme.bgDark,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.cameraTryOn),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Try On'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        ],
      ),
      body: Consumer<TattooProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              // Upload Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _UploadCard(
                    pickedFile: _pickedFile,
                    nameController: _nameController,
                    isUploading: provider.isUploading,
                    onPickImage: _pickImage,
                    onUpload: _upload,
                  ),
                ),
              ),

              // Gallery Title
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Saved Tattoos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),

              // Gallery Grid
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: AppLoadingWidget()),
                )
              else if (provider.tattoos.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(onUpload: _pickImage),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _TattooCard(
                        tattoo: provider.tattoos[index],
                        isSelected: provider.selectedTattoo?.id ==
                            provider.tattoos[index].id,
                        apiService: context.read<ApiService>(),
                        onTap: () {
                          provider.selectTattoo(provider.tattoos[index]);
                          Navigator.pushNamed(context, AppRoutes.cameraTryOn);
                        },
                      ),
                      childCount: provider.tattoos.length,
                    ),
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────── Sub-widgets ─────────────────────────────────────

class _UploadCard extends StatelessWidget {
  final XFile? pickedFile;
  final TextEditingController nameController;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onUpload;

  const _UploadCard({
    required this.pickedFile,
    required this.nameController,
    required this.isUploading,
    required this.onPickImage,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload New Tattoo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PNG recommended for best transparency results',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // Image picker area
            GestureDetector(
              onTap: onPickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: pickedFile != null
                        ? AppTheme.primary
                        : AppTheme.divider,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: pickedFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: kIsWeb
                            ? Image.network(pickedFile!.path, fit: BoxFit.contain)
                            : Image.file(File(pickedFile!.path),
                                fit: BoxFit.contain),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppTheme.primary, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'Tap to pick from gallery',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'PNG / JPG / WEBP',
                            style: TextStyle(
                              color: AppTheme.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Name field
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tattoo name (e.g. Dragon Sleeve)',
                hintStyle: const TextStyle(
                    color: AppTheme.textDisabled, fontSize: 14),
                filled: true,
                fillColor: AppTheme.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Upload button
            SizedBox(
              width: double.infinity,
              child: isUploading
                  ? const Center(child: AppLoadingWidget())
                  : PrimaryButton(
                      label: 'Upload Tattoo',
                      icon: Icons.upload_rounded,
                      onPressed: onUpload,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TattooCard extends StatelessWidget {
  final TattooModel tattoo;
  final bool isSelected;
  final ApiService apiService;
  final VoidCallback onTap;

  const _TattooCard({
    required this.tattoo,
    required this.isSelected,
    required this.apiService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                apiService.buildImageUrl(tattoo.imageUrl),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppTheme.textDisabled, size: 40),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: AppLoadingWidget());
                },
              ),
            ),
            // Selected badge
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppTheme.bgDark, size: 14),
                ),
              ),
            // Name label
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  tattoo.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🖋️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'No tattoos yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your first tattoo design above',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Pick from Gallery'),
          ),
        ],
      ),
    );
  }
}
