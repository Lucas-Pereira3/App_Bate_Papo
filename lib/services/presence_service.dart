import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class PresenceService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final Map<String, bool> _typingUsers = {};
  final Map<String, bool> _onlineUsers = {};

  Map<String, bool> get typingUsers => _typingUsers;
  Map<String, bool> get onlineUsers => _onlineUsers;

  Future<void> setUserOnline() async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('user_status').upsert({
        'user_id': userId,
        'online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro no setUserOnline: $e');
    }
  }

  Future<void> setUserOffline() async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('user_status').upsert({
        'user_id': userId,
        'online': false,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro no setUserOffline: $e');
    }
  }

  Stream<Map<String, dynamic>> subscribeToUserStatus(String userId) {
    return _client
        .from('user_status')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((events) {
          if (events.isNotEmpty) {
            return events.first;
          }
          return {};
        });
  }

  
  Future<void> startTyping(String conversationId, String userName) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('typing_indicators').upsert({
        'user_id': userId,
        'conversation_id': conversationId,
        'user_name': userName, 
        'typing': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro no startTyping: $e');
    }
  }
  
  Future<void> stopTyping(String conversationId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('typing_indicators').upsert({
        'user_id': userId,
        'conversation_id': conversationId,
        'typing': false,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro no stopTyping: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeToTyping(String conversationId) {
    final stream = _client
        .from('typing_indicators')
        .stream(primaryKey: ['user_id', 'conversation_id']);
    
    return stream.map((events) {
      return events.where((event) {
        return event['conversation_id'] == conversationId && 
               event['typing'] == true;
      }).toList();
    });
  }
}