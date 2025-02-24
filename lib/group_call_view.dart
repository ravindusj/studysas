import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_service.dart';

class GroupCallView extends StatefulWidget {
  final String groupId;
  final String userId;
  final VoidCallback onLeaveCall;

  const GroupCallView({
    Key? key,
    required this.groupId,
    required this.userId,
    required this.onLeaveCall,
  }) : super(key: key);

  @override
  State<GroupCallView> createState() => _GroupCallViewState();
}

class _GroupCallViewState extends State<GroupCallView> {
  late WebRTCService _webRTCService;
  bool _isMuted = false;
  bool _isVideoOff = false;
  
  @override
  void initState() {
    super.initState();
    _webRTCService = WebRTCService(
      groupId: widget.groupId,
      userId: widget.userId,
    );
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _webRTCService.joinCall();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          Expanded(
            child: _buildParticipantsGrid(),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    final streams = [
      if (_webRTCService.localStream != null)
        _buildVideoView(_webRTCService.localStream!, isLocal: true),
      ..._webRTCService.remoteStreams.entries.map(
        (entry) => _buildVideoView(entry.value, isLocal: false),
      ),
    ];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: streams.length <= 2 ? 1 : 2,
        childAspectRatio: 3 / 4,
      ),
      itemCount: streams.length,
      itemBuilder: (context, index) => streams[index],
    );
  }

  Widget _buildVideoView(MediaStream stream, {required bool isLocal}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: RTCVideoView(
          RTCVideoRenderer()..srcObject = stream,
          mirror: isLocal,
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
            ),
            onPressed: _toggleMute,
          ),
          IconButton(
            icon: const Icon(
              Icons.call_end,
              color: Colors.red,
            ),
            onPressed: _leaveCall,
          ),
          IconButton(
            icon: Icon(
              _isVideoOff ? Icons.videocam_off : Icons.videocam,
              color: Colors.white,
            ),
            onPressed: _toggleVideo,
          ),
        ],
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _webRTCService.localStream?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
      _webRTCService.localStream?.getVideoTracks().forEach((track) {
        track.enabled = !_isVideoOff;
      });
    });
  }

  void _leaveCall() async {
    await _webRTCService.leaveCall();
    widget.onLeaveCall();
  }

  @override
  void dispose() {
    _webRTCService.leaveCall();
    super.dispose();
  }
}