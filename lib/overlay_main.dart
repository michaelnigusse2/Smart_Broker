import 'package:flutter/material.dart';
import 'features/calls/screens/call_overlay_screen.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CallOverlayScreen(),
  ));
}
