import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Thin wrapper over the static `FlutterOverlayWindow` API so the call flow
/// can be tested with a fake.
class OverlayGateway {
  const OverlayGateway();

  Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isActive() => FlutterOverlayWindow.isActive();

  /// Full-width window at the top of the screen. [heightPx] is in physical pixels.
  Future<void> show({required int heightPx}) => FlutterOverlayWindow.showOverlay(
    height: heightPx,
    width: WindowSize.matchParent,
    alignment: OverlayAlignment.topCenter,
    // focusPointer lets the note field receive keyboard input while
    // touches outside the window still reach the dialer.
    flag: OverlayFlag.focusPointer,
    enableDrag: true,
    positionGravity: PositionGravity.none,
    visibility: NotificationVisibility.visibilityPrivate,
    overlayTitle: 'SmartBroker',
    overlayContent: 'Call notes',
  );

  Future<void> shareData(Object data) async {
    await FlutterOverlayWindow.shareData(data);
  }
}
