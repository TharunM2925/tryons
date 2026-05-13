import 'dart:typed_data';

/// Model representing an individual tattoo cropped from a sheet.
class TattooItem {
  final int id;
  final Uint8List imageBytes;
  final int row;
  final int column;
  bool isSelected;

  TattooItem({
    required this.id,
    required this.imageBytes,
    required this.row,
    required this.column,
    this.isSelected = false,
  });
}
