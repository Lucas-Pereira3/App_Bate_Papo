import 'package:flutter/material.dart';

class AppStateService extends ChangeNotifier {
  String? _currentChatId;

  String? get currentChatId => _currentChatId;

  // Define qual chat o usuário está vendo agora
  void setCurrentChat(String? conversationId) {
    _currentChatId = conversationId;
    notifyListeners();
  }
}