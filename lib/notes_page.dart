import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'note_model.dart';
import 'note_editor_sheet.dart';
import 'auth_page.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = authSnapshot.data;
        if (user == null) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              },
              child: const Text('Sign In to View Notes'),
            ),
          );
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notes')
                        .where('userID', isEqualTo: user.uid)
                        .orderBy('updatedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final notes = snapshot.data?.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Note.fromMap(doc.id, data);
                      }).toList() ?? [];

                      if (notes.isEmpty) {
                        return const Center(
                          child: Text(
                            'No notes yet. Create one!',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return Expanded(
                        child: ListView.builder(
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                title: Text(
                                  note.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Last updated: ${DateFormat.yMMMd().format(note.updatedAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _showNoteEditor(context, note),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteNote(context, note.id!),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 75,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _showNoteEditor(context),
                backgroundColor: const Color(0xFF6448FE),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNote(BuildContext context, String noteId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(noteId)
          .delete();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: ${e.toString()}')),
        );
      }
    }
  }

  void _showNoteEditor(BuildContext context, [Note? existingNote]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => NoteEditorSheet(note: existingNote),
    );
  }
}