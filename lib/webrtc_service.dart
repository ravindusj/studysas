import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebRTCService {
  final String groupId;
  final String userId;
  Map<String, RTCPeerConnection> peerConnections = {};
  Map<String, MediaStream> remoteStreams = {};
  MediaStream? localStream;
  
  // Signal collection reference for handling WebRTC signaling
  final _signalCollection = FirebaseFirestore.instance.collection('signals');
  
  WebRTCService({required this.groupId, required this.userId});

  Future<void> initializeWebRTC() async {
    // Get local media stream
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    // Listen for new participants
    _signalCollection
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          if (data['from'] != userId) {
            handleSignalingMessage(data);
          }
        }
      });
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    final configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    };

    final pc = await createPeerConnection(configuration);

    // Add local tracks to the peer connection
    localStream?.getTracks().forEach((track) {
      pc.addTrack(track, localStream!);
    });

    // Handle remote stream
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStreams[remoteUserId] = event.streams[0];
      }
    };

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignalingMessage({
        'type': 'candidate',
        'candidate': candidate.toMap(),
        'from': userId,
        'to': remoteUserId,
        'groupId': groupId,
      });
    };

    return pc;
  }

  Future<void> joinCall() async {
    await initializeWebRTC();

    // Notify other participants
    await _sendSignalingMessage({
      'type': 'join',
      'from': userId,
      'groupId': groupId,
    });
  }

  Future<void> leaveCall() async {
    // Close all peer connections
    for (var pc in peerConnections.values) {
      await pc.close();
    }
    peerConnections.clear();

    // Stop local stream
    localStream?.getTracks().forEach((track) => track.stop());
    localStream = null;

    // Clear remote streams
    remoteStreams.clear();

    // Notify other participants
    await _sendSignalingMessage({
      'type': 'leave',
      'from': userId,
      'groupId': groupId,
    });
  }

  Future<void> handleSignalingMessage(Map<String, dynamic> message) async {
    final type = message['type'];
    final from = message['from'];

    switch (type) {
      case 'join':
        // Create new peer connection for the joining user
        final pc = await _createPeerConnection(from);
        peerConnections[from] = pc;

        // Create and send offer
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        await _sendSignalingMessage({
          'type': 'offer',
          'from': userId,
          'to': from,
          'groupId': groupId,
          'sdp': offer.toMap(),
        });
        break;

      case 'offer':
        if (message['to'] == userId) {
          // Create peer connection if it doesn't exist
          var pc = peerConnections[from];
          if (pc == null) {
            pc = await _createPeerConnection(from);
            peerConnections[from] = pc;
          }

          // Set remote description and create answer
          await pc.setRemoteDescription(
            RTCSessionDescription(
              message['sdp']['sdp'],
              message['sdp']['type'],
            ),
          );

          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          await _sendSignalingMessage({
            'type': 'answer',
            'from': userId,
            'to': from,
            'groupId': groupId,
            'sdp': answer.toMap(),
          });
        }
        break;

      case 'answer':
        if (message['to'] == userId) {
          final pc = peerConnections[from];
          if (pc != null) {
            await pc.setRemoteDescription(
              RTCSessionDescription(
                message['sdp']['sdp'],
                message['sdp']['type'],
              ),
            );
          }
        }
        break;

      case 'candidate':
        if (message['to'] == userId) {
          final pc = peerConnections[from];
          if (pc != null) {
            await pc.addCandidate(
              RTCIceCandidate(
                message['candidate']['candidate'],
                message['candidate']['sdpMid'],
                message['candidate']['sdpMLineIndex'],
              ),
            );
          }
        }
        break;

      case 'leave':
        // Remove peer connection and stream for the leaving user
        final pc = peerConnections.remove(from);
        if (pc != null) {
          await pc.close();
        }
        remoteStreams.remove(from);
        break;
    }
  }

  Future<void> _sendSignalingMessage(Map<String, dynamic> message) async {
    await _signalCollection.add({
      ...message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}