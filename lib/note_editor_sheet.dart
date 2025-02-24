import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'note_model.dart';
import 'image_to_text_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteEditorSheet extends StatefulWidget {
  final Note? note;

  const NoteEditorSheet({super.key, this.note});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

 void _showImageToTextDialog() {
    showDialog(
      context: context,
      builder: (context) => ImageToTextDialog(
        onAddToNote: (text) {
          final currentText = _contentController.text;
          final newText = currentText.isEmpty 
              ? text 
              : '$currentText\n\n$text';
          _contentController.text = newText;
        },
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!mounted) return;

    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content cannot be empty')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save notes')),
      );
      return;
    }

    try {
      final note = Note(
        id: widget.note?.id,
        title: _titleController.text,
        content: _contentController.text,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userID: currentUser.uid,
      );

      if (widget.note?.id != null) {
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.note!.id)
            .update(note.toMap());
      } else {
        await FirebaseFirestore.instance
            .collection('notes')
            .add(note.toMap());
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving note: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: 'Content',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _saveNote,
                child: Text(widget.note == null ? 'Create Note' : 'Update Note'),
              ),
              ElevatedButton.icon(
                onPressed: _showImageToTextDialog,
                icon: const Icon(Icons.image_search),
                label: const Text('Image to Text'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
