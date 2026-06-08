part of '../main.dart';

class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key, required this.controller, required this.call});

  final MessengerController controller;
  final ActiveCall call;

  @override
  Widget build(BuildContext context) {
    final showIncomingActions = call.stage == CallStage.incoming;
    final showDialingActions = call.stage == CallStage.outgoing;
    final showLiveActions =
        call.stage == CallStage.connecting || call.stage == CallStage.connected;
    final showRemoteVideo = showLiveActions && callHasRemoteVideo(call);
    final showLocalVideo = showLiveActions && callHasLocalVideo(call);
    final showLocalPreview = call.isVideo && showLiveActions;
    final remoteCameraOff =
        call.isVideo && showLiveActions && !call.remoteCameraEnabled;
    final showCallDetails = !remoteCameraOff || !showLiveActions;
    final useWhiteWaitingSurface = !showRemoteVideo;
    final waitingTitleColor = useWhiteWaitingSurface
        ? const Color(0xFF172033)
        : Colors.white;
    final waitingSubtitleColor = useWhiteWaitingSurface
        ? const Color(0xFF64748B)
        : const Color(0xFFE2E8F0);
    return PopScope(
      canPop: false,
      child: Material(
        color: useWhiteWaitingSurface ? Colors.white : appSurfaceColor,
        child: Stack(
          children: [
            Positioned.fill(
              child: showRemoteVideo
                  ? RTCVideoView(
                      call.remoteRenderer,
                      mirror: false,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: useWhiteWaitingSurface
                          ? Colors.white
                          : Colors.black,
                    ),
            ),
            if (showRemoteVideo)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.16),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ),
            if (!showRemoteVideo)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      remoteCameraOff
                          ? Icon(
                              Icons.videocam_off_rounded,
                              color: useWhiteWaitingSurface
                                  ? appPrimaryColor
                                  : Colors.white,
                              size: 58,
                            )
                          : ProfileAvatar(
                              name: call.contact.name,
                              imageUrl: call.contact.avatarUrl,
                              radius: 46,
                              backgroundColor: useWhiteWaitingSurface
                                  ? appPrimaryColor
                                  : Colors.white.withValues(alpha: 0.16),
                              foregroundColor: Colors.white,
                            ),
                      if (showCallDetails) ...[
                        const SizedBox(height: 18),
                        Text(
                          call.contact.name,
                          style: TextStyle(
                            color: waitingTitleColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          call.statusText.isEmpty
                              ? callStageTitle(call.stage)
                              : call.statusText,
                          style: TextStyle(
                            color: waitingSubtitleColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (showLocalPreview)
              Positioned(
                right: 16,
                bottom: 126,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 108,
                      height: 148,
                      child: showLocalVideo
                          ? RTCVideoView(
                              call.localRenderer,
                              mirror: false,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          : const ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: Icon(
                                  Icons.videocam_off_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 34,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: showIncomingActions
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CallActionButton(
                                  icon: Icons.call_end_rounded,
                                  backgroundColor: const Color(0xFFE53935),
                                  onTap: controller.rejectIncomingCall,
                                ),
                                const SizedBox(width: 28),
                                CallActionButton(
                                  icon: call.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.call_rounded,
                                  backgroundColor: const Color(0xFF16A34A),
                                  onTap: controller.acceptIncomingCall,
                                ),
                              ],
                            )
                          : showDialingActions
                          ? Center(
                              child: CallActionButton(
                                icon: Icons.call_end_rounded,
                                backgroundColor: const Color(0xFFE53935),
                                onTap: controller.endCall,
                              ),
                            )
                          : !showLiveActions
                          ? const SizedBox.shrink()
                          : Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CallActionButton(
                                      icon: call.isMuted
                                          ? Icons.mic_off_rounded
                                          : Icons.mic_rounded,
                                      backgroundColor: call.isMuted
                                          ? const Color(0xFF9ABFD9)
                                          : appPrimaryColor,
                                      onTap: controller.toggleMute,
                                    ),
                                    const SizedBox(width: 12),
                                    CallActionButton(
                                      icon: call.isSoundOn
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_off_rounded,
                                      backgroundColor: call.isSoundOn
                                          ? appPrimaryColor
                                          : const Color(0xFF9ABFD9),
                                      onTap: controller.toggleSound,
                                    ),
                                    if (call.isVideo) ...[
                                      const SizedBox(width: 12),
                                      CallActionButton(
                                        icon: call.isCameraEnabled
                                            ? Icons.videocam_rounded
                                            : Icons.videocam_off_rounded,
                                        backgroundColor: appPrimaryColor,
                                        onTap: controller.toggleCamera,
                                      ),
                                      const SizedBox(width: 12),
                                      CallActionButton(
                                        icon: Icons.cameraswitch_rounded,
                                        backgroundColor: appPrimaryColor,
                                        onTap: controller.switchCamera,
                                      ),
                                    ],
                                    const SizedBox(width: 12),
                                    CallActionButton(
                                      icon: Icons.call_end_rounded,
                                      backgroundColor: const Color(0xFFE53935),
                                      onTap: controller.endCall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
