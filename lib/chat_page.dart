import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_group.dart';
import 'chat_message.dart';
import 'dart:math';
import 'group_call_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  ChatGroup? _selectedGroup;
  bool _isInCall = false;

  void _createNewGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _groupNameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final inviteCode = _generateInviteCode();
    final group = ChatGroup(
      id: '',
      name: name,
      creatorId: user.uid,
      members: [user.uid],
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('chat_groups')
        .add(group.toMap());
    
    _groupNameController.clear();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _joinGroup() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: _inviteCodeController,
          decoration: const InputDecoration(
            labelText: 'Enter Invite Code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _inviteCodeController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final groupQuery = await FirebaseFirestore.instance
        .collection('chat_groups')
        .where('inviteCode', isEqualTo: code)
        .get();

    if (groupQuery.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid invite code')),
        );
      }
      return;
    }

    final groupDoc = groupQuery.docs.first;
    final group = ChatGroup.fromMap(groupDoc.id, groupDoc.data());

    if (!group.members.contains(user.uid)) {
      await groupDoc.reference.update({
        'members': [...group.members, user.uid],
        'updatedAt': DateTime.now(),
      });
    }
    
    _inviteCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to use chat'));
    }

    return Scaffold(
      body: Column(
        children: [
          _buildGroupList(user),
          if (_selectedGroup != null) _buildChatArea(user),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _createNewGroup,
            heroTag: 'createGroup',
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _joinGroup,
            heroTag: 'joinGroup',
            child: const Icon(Icons.link),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_groups')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data!.docs.map((doc) {
          return ChatGroup.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedGroup = group),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedGroup?.id == group.id
                        ? Colors.blue
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      group.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChatArea(User user) {
    return Expanded(
      child: Column(
        children: [
          _buildMessages(user),
          _buildMessageInput(user),
        ],
      ),
    );
  }

  Widget _buildMessages(User user) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_messages')
            .where('groupId', isEqualTo: _selectedGroup!.id)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs.map((doc) {
            return ChatMessage.fromMap(
                doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMe = message.senderId == user.uid;

              return _buildMessageBubble(message, isMe);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (message.type == MessageType.text)
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              )
            else if (message.type == MessageType.voiceNote)
              _buildVoiceNotePlayer(message)
            else if (message.type == MessageType.attachment)
              _buildAttachment(message),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNotePlayer(ChatMessage message) {
    // Implement voice note player UI
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            // Implement voice note playback
          },
        ),
        const Text('Voice Note'),
      ],
    );
  }

  Widget _buildAttachment(ChatMessage message) {
    // Implement attachment preview
    return InkWell(
      onTap: () {
        // Open attachment
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attachment),
          const SizedBox(width: 8),
          Text(message.content),
        ],
      ),
    );
  }

  Widget _buildMessageInput(User user) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              // Implement file attachment
            },
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: () {
              // Implement voice note recording
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(user),
          ),
          IconButton(
            icon: Icon(_isInCall ? Icons.call_end : Icons.call),
            onPressed: () => _toggleGroupCall(user),
          ),
        ],
      ),
    );
  }

  void _sendMessage(User user) async {
    if (_messageController.text.trim().isEmpty) return;

    final message = ChatMessage(
      id: '',
      groupId: _selectedGroup!.id,
      senderId: user.uid,
      senderName: user.displayName ?? 'Unknown',
      content: _messageController.text,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('chat_messages')
        .add(message.toMap());

    _messageController.clear();
  }

void _toggleGroupCall(User user) {
  if (_selectedGroup == null) return;
  
  setState(() {
    _isInCall = !_isInCall;
    if (_isInCall) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: GroupCallView(
            groupId: _selectedGroup!.id,
            userId: user.uid,
            onLeaveCall: () {
              Navigator.pop(context);
              setState(() => _isInCall = false);
            },
          ),
        ),
      );
    }
  });
}

  @override
  void dispose() {
    _messageController.dispose();
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }
}