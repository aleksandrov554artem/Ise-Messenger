part of '../main.dart';

bool callHasRemoteVideo(ActiveCall call) {
  return call.isVideo &&
      call.remoteCameraEnabled &&
      call.remoteStream != null &&
      call.remoteStream!.getVideoTracks().isNotEmpty;
}

bool callHasLocalVideo(ActiveCall call) {
  return call.isVideo &&
      call.isCameraEnabled &&
      call.localStream != null &&
      call.localStream!.getVideoTracks().isNotEmpty;
}
