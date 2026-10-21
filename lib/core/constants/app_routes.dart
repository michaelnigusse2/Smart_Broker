import 'package:flutter/material.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

  static const String shell = '/';
  static const String contactDetail = '/contact_detail';
  static const String contactForm = '/contact-form';
  static const String noteDetail = '/note-detail';
  static const String notesList = '/notes-list';
  static const String tasks = '/tasks';
  static const String addNote = '/add-note';
  static const String aiReview = '/ai-review';
  static const String phoneContactDetail = '/phone_contact_detail';
  static const String reminderDetail = '/reminder-detail';
  static const String settings = '/settings';
  static const String calendar = '/calendar';

  /// No leading slash: as the first route it's pushed alone, not on top of '/'.
  static const String onboarding = 'onboarding';
}
