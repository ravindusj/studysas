import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class ImageToTextDialog extends StatefulWidget {
  final Function(String) onAddToNote;

  const ImageToTextDialog({super.key, required this.onAddToNote});

  @override
  State<ImageToTextDialog> createState() => _ImageToTextDialogState();
}

class _ImageToTextDialogState extends State<ImageToTextDialog> {
  final ImagePicker _picker = ImagePicker();
  final textRecognizer = TextRecognizer();
  String _extractedText = '';
  bool _isLoading = false;

  Future<void> _processImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _extractedText = '';
      });

      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      final inputImage = InputImage.fromFile(File(image.path));
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        _extractedText = recognizedText.text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing image')),
        );
      }
    }
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _processImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _processImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_extractedText.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_extractedText),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          widget.onAddToNote(_extractedText);
                          Navigator.pop(context);
                        },
                        child: const Text('Add to Note'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}