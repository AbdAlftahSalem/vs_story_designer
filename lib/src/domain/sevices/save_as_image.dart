import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> takePicture({
  required GlobalKey contentKey,
  required BuildContext context,
  required bool saveToGallery,
  required String fileName,
}) async {
  try {
    /// Convert widget to image
    RenderRepaintBoundary boundary =
        contentKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    ui.Image image = await boundary.toImage(pixelRatio: 3);

    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    /// Create file
    final String dir = (await getApplicationDocumentsDirectory()).path;
    String imagePath =
        '$dir/${fileName}_${DateTime.now().millisecondsSinceEpoch}.png';
    File capturedFile = File(imagePath);
    await capturedFile.writeAsBytes(pngBytes);

    /// Save to gallery if requested
    if (saveToGallery) {
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "${fileName}_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      if (result == null || !result['isSuccess']) {
        debugPrint('Failed to save image to gallery');
      }
    }

    /// Return the image path
    return imagePath;
  } catch (e) {
    debugPrint('exception => $e');
    return null;
  }
}
