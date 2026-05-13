import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../data/models/tattoo_item.dart';

/// Utility to process a tattoo sheet image: split it into a grid and remove background.
class TattooSheetProcessor {
  static const int tattooColumns = 4;
  static const int tattooRows = 10; // Matches generated sheet

  /// Loads the sheet from assets, crops it, and removes the light background.
  static Future<List<TattooItem>> processTattooSheet(String assetPath, {int startId = 0}) async {
    // 1. Load asset bytes
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();

    // 2. Decode image
    final img.Image? fullImage = img.decodeImage(bytes);
    if (fullImage == null) return [];

    final int cellWidth = fullImage.width ~/ tattooColumns;
    final int cellHeight = fullImage.height ~/ tattooRows;
    
    List<TattooItem> items = [];
    int idCounter = startId;

    for (int r = 0; r < tattooRows; r++) {
      for (int c = 0; c < tattooColumns; c++) {
        // 3. Crop cell
        img.Image cropped = img.copyCrop(
          fullImage,
          x: c * cellWidth,
          y: r * cellHeight,
          width: cellWidth,
          height: cellHeight,
        );

        // 4. Remove background (make near-white pixels transparent)
        // Background on the sheet is around #F2F2F2 or lighter.
        img.Image transparent = _removeBackground(cropped);

        // 5. Convert to PNG bytes
        final Uint8List finalBytes = Uint8List.fromList(img.encodePng(transparent));

        items.add(TattooItem(
          id: idCounter++,
          imageBytes: finalBytes,
          row: r,
          column: c,
        ));
      }
    }

    return items;
  }

  /// Loads individual background-removed images directly without thresholding.
  static Future<List<TattooItem>> processSingleTattoos(List<String> assetPaths, int startId) async {
    List<TattooItem> items = [];
    int idCounter = startId;
    
    for (String path in assetPaths) {
      try {
        final ByteData data = await rootBundle.load(path);
        final Uint8List bytes = data.buffer.asUint8List();
        
        final img.Image? fullImage = img.decodeImage(bytes);
        if (fullImage != null) {
          // Apply background removal to single uploaded images as well
          img.Image transparent = _removeBackground(fullImage);
          final Uint8List finalBytes = Uint8List.fromList(img.encodePng(transparent));

          items.add(TattooItem(
            id: idCounter++,
            imageBytes: finalBytes,
            row: 0,
            column: 0,
          ));
        }
      } catch (e) {
        // Asset not found yet, skip
      }
    }
    return items;
  }

  /// Simple thresholding to make light pixels transparent.
  static img.Image _removeBackground(img.Image image) {
    // Ensure the image has an alpha channel
    if (image.numChannels < 4) {
      image = image.convert(numChannels: 4);
    }

    for (var frame in image.frames) {
      for (var pixel in frame) {
        // Simple brightness check: (R + G + B) / 3
        // If brightness > 220 (near white), set alpha to 0
        final num r = pixel.r;
        final num g = pixel.g;
        final num b = pixel.b;
        
        final num brightness = (r + g + b) / 3;

        if (brightness > 180) {
          pixel.a = 0;
        } else {
          num calculatedAlpha = 255 - brightness;
          calculatedAlpha = (calculatedAlpha * 1.5).clamp(120, 255);
          pixel.a = calculatedAlpha;
        }
      }
    }
    return image;
  }
}
