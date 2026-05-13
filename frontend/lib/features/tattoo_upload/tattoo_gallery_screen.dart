import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_routes.dart';
import '../../core/utils/tattoo_processor.dart';
import '../../data/models/tattoo_item.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import '../camera_tryon/camera_tryon_screen.dart';

/// Screen for selecting a tattoo from the processed sheet grid.
class TattooGalleryScreen extends StatefulWidget {
  const TattooGalleryScreen({super.key});

  @override
  State<TattooGalleryScreen> createState() => _TattooGalleryScreenState();
}

class _TattooGalleryScreenState extends State<TattooGalleryScreen> {
  List<TattooItem>? _tattoos;
  TattooItem? _selectedTattoo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTattoos();
  }

  Future<void> _loadTattoos() async {
    try {
      // 1. Try to load user's single uploaded background-removed photos
      final singleAssetPaths = [
        'assets/tattoos/wings.png',
        'assets/tattoos/dragon.png',
        'assets/tattoos/infinity.png',
        'assets/tattoos/tribal.png',
        'assets/tattoos/anchor.png',
      ];
      
      List<TattooItem> items = await TattooSheetProcessor.processSingleTattoos(singleAssetPaths, 0);

      // 2. Load the old sheet grid
      final sheetItems = await TattooSheetProcessor.processTattooSheet(
        'assets/tattoos/tattoo_sheet.png',
        startId: items.length,
      );
      
      items.addAll(sheetItems);

      setState(() {
        _tattoos = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error processing tattoo sheet: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onTryOn() {
    if (_selectedTattoo == null) return;
    
    debugPrint("Selected tattoo bytes: ${_selectedTattoo!.imageBytes.length}");
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraTryOnScreen(
          selectedTattooBytes: _selectedTattoo!.imageBytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Choose Your Tattoo'),
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingWidget())
          : Column(
              children: [
                Expanded(
                  child: _tattoos == null || _tattoos!.isEmpty
                      ? const Center(
                          child: Text(
                            'Failed to load tattoo sheet.\nEnsure assets/tattoos/tattoo_sheet.png exists.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: _tattoos!.length,
                          itemBuilder: (context, index) {
                            final item = _tattoos![index];
                            final isSelected = _selectedTattoo?.id == item.id;

                            return GestureDetector(
                              onTap: () => setState(() => _selectedTattoo = item),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white, // White background for black ink icons
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primary.withOpacity(0.4),
                                            blurRadius: 10,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.memory(
                                    item.imageBytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Try On Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: PrimaryButton(
                    label: 'Try On Selected',
                    icon: Icons.camera_alt_rounded,
                    onPressed: _selectedTattoo != null ? _onTryOn : null,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }
}
