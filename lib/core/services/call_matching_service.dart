import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/call_event.dart';
import '../../models/call_entry.dart';
import '../../models/contact.dart';
import '../../models/phone_contact.dart';
import '../repositories/call_repository.dart';
import '../repositories/contact_repository.dart';
import 'call_detection_service.dart';
import 'notification_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';
import 'settings_service.dart';

/// Matches incoming CallEvents to SmartBroker contacts and auto-logs them.
class CallMatchingService {
  static final CallMatchingService _instance = CallMatchingService._internal();
  factory CallMatchingService() => _instance;
  CallMatchingService._internal();

  final CallRepository _callRepo = CallRepository();
  final ContactRepository _contactRepo = ContactRepository();
  final CallDetectionService _detectionService = CallDetectionService();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  final StreamController<CallEntry> _onCallLoggedController = StreamController<CallEntry>.broadcast();

  /// Stream of recently logged calls, used to auto-refresh UI
  Stream<CallEntry> get onCallLogged => _onCallLoggedController.stream;

  /// Start listening for call events and auto-logging them.
  void startListening() {
    _subscription?.cancel();
    _subscription = _detectionService.callEvents.listen(_handleRawEvent);
    debugPrint('CallMatchingService: started listening for call events');
  }

  /// Stop listening for call events.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('CallMatchingService: stopped listening');
  }

  /// Process a single call event — match to contact, log, update lastInteraction.
  /// Exposed publicly so the "Simulate Call" debug tool can call it directly.
  Future<void> handleCallEvent(CallEvent event) => _handleCallEvent(event);

  Future<void> _handleRawEvent(Map<String, dynamic> data) async {
    final eventName = data['event'] as String?;
    
    if (eventName == 'state') {
      final stateStr = data['state'] as String?;
      final settings = SettingsService();
      final showOverlay = await settings.getShowCallOverlay();
      
      if (showOverlay) {
        try {
          if (stateStr == 'offhook') {
            final perm = await FlutterOverlayWindow.isPermissionGranted();
            if (perm) {
              await FlutterOverlayWindow.showOverlay(
                enableDrag: true,
                flag: OverlayFlag.defaultFlag,
                alignment: OverlayAlignment.center,
                visibility: NotificationVisibility.visibilityPrivate,
                positionGravity: PositionGravity.auto,
              );
              await FlutterOverlayWindow.shareData(jsonEncode({
                'action': 'active',
              }));
            }
          } else if (stateStr == 'idle') {
            await FlutterOverlayWindow.shareData(jsonEncode({
              'action': 'ended',
            }));
          }
        } catch (e) {
          debugPrint('Overlay error: $e');
        }
      }
    } else if (eventName == 'call_logged') {
      final event = CallEvent.fromMap(data);
      await _handleCallEvent(event);
    }
  }

  Future<void> _handleCallEvent(CallEvent event) async {
    try {
      final normalizedNumber = PhoneContact.normalizePhoneNumber(event.phoneNumber);
      debugPrint('CallMatchingService: processing call from $normalizedNumber (${event.type.name})');

      if (normalizedNumber.isEmpty) {
        debugPrint('CallMatchingService: empty phone number, skipping');
        return;
      }

      // 1. Try to find a matching contact by phone number
      String contactId;
      final contacts = await _contactRepo.getAll();
      final match = contacts.cast<Contact?>().firstWhere(
        (c) => PhoneContact.normalizePhoneNumber(c!.phoneNumber) == normalizedNumber,
        orElse: () => null,
      );

      if (match != null) {
        contactId = match.id;
        debugPrint('CallMatchingService: matched to contact "${match.name}"');

        // Update lastInteraction
        await _contactRepo.update(match.copyWith(
          lastInteraction: event.timestamp,
        ));
      } else {
        // Auto-create a temporary contact with the phone number as name
        final tempContact = Contact(
          id: '',
          name: normalizedNumber,
          phoneNumber: event.phoneNumber,
          lastInteraction: event.timestamp,
        );
        contactId = await _contactRepo.insert(tempContact);
        debugPrint('CallMatchingService: created temp contact "$normalizedNumber" → $contactId');
      }

      // 2. Log the call
      final callEntry = CallEntry(
        id: '',
        contactId: contactId,
        type: event.type,
        duration: event.duration,
        timestamp: event.timestamp,
      );
      await _callRepo.insert(callEntry);
      debugPrint('CallMatchingService: logged ${event.type.name} call (${event.duration.inSeconds}s)');
      
      _onCallLoggedController.add(callEntry);

      // 3. Trigger Post-Call Prompt
      final settings = SettingsService();
      final promptEnabled = await settings.getPromptAfterCall();
      final minDuration = await settings.getMinCallDuration();

      if (promptEnabled && event.duration.inSeconds >= minDuration) {
        // Need the full Contact object for the notification
        final contactForPrompt = match ?? await _contactRepo.getById(contactId);
        if (contactForPrompt != null) {
          await NotificationService().showPostCallPrompt(contactForPrompt, callEntry);
        }
      }
    } catch (e) {
      debugPrint('CallMatchingService: error processing call event: $e');
    }
  }
}
