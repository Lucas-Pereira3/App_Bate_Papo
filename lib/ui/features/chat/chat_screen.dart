import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
import '../../../ui/widgets/message_bubble.dart';
import '../../../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<Message>>? _messagesSubscription;
  List<Message> _messages = [];
  String _conversationId = '';
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeChat();
  }

  void _initializeChat() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _conversationId = args?['conversationId'] ?? '';
    
    if (_conversationId.isNotEmpty) {
      await _loadInitialMessages();
      _subscribeToMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final messages = await chatService.fetchMessages(_conversationId);
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      print('❌ Erro ao carregar mensagens: $e');
      _showErrorSnackbar('Erro ao carregar mensagens');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    // Cancela subscription anterior se existir
    _messagesSubscription?.cancel();
    
    _messagesSubscription = chatService.subscribeMessages(_conversationId).listen(
      (newMessages) {
        print('📨 Nova mensagem recebida via stream. Total: ${newMessages.length}');
        
        setState(() {
          _messages = newMessages;
        });
        
        _scrollToBottom();
      },
      onError: (error) {
        print('❌ Erro na subscription: $error');
        _showErrorSnackbar('Erro na conexão em tempo real');
        
        // Tenta reconectar após 3 segundos
        Future.delayed(Duration(seconds: 3), () {
          if (_conversationId.isNotEmpty) {
            _subscribeToMessages();
          }
        });
      },
      onDone: () {
        print('ℹ️ Stream de mensagens finalizado');
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    if (userId.isEmpty) {
      _showErrorSnackbar('Usuário não autenticado');
      return;
    }

    if (_conversationId.isEmpty) {
      _showErrorSnackbar('Conversa não encontrada');
      return;
    }

    try {
      // Limpa o campo de texto imediatamente
      _textController.clear();
      
      // Mostra mensagem de enviando
      _showSuccessSnackbar('Enviando mensagem...');
      
      await chatService.sendTextMessage(_conversationId, userId, text);
      
      print('✅ Mensagem enviada com sucesso');
      
    } catch (e) {
      print('❌ Erro ao enviar mensagem: $e');
      _showErrorSnackbar('Erro ao enviar mensagem: $e');
      
      // Devolve o texto para o campo se deu erro
      _textController.text = text;
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadInitialMessages();
              _showSuccessSnackbar('Atualizando mensagens...');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de carregamento
          if (_isLoading)
            LinearProgressIndicator(minHeight: 2),
          
          // Indicador de conexão
          if (_messagesSubscription != null)
            Container(
              height: 2,
              color: Colors.green,
            ),
          
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Nenhuma mensagem ainda',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'Seja o primeiro a enviar uma mensagem!',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadInitialMessages,
                              child: Text('Recarregar'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (ctx, i) {
                          final message = _messages[i];
                          final isMine = message.senderId == userId;
                          
                          return MessageBubble(
                            text: message.content,
                            mine: isMine,
                            type: message.type,
                            timestamp: message.createdAt,
                          );
                        },
                      ),
          ),
          
          // Área de input de mensagem
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Botão para adicionar imagem
                    IconButton(
                      onPressed: () {
                        _showImageOptionDialog();
                      }, 
                      icon: Icon(Icons.photo_library, color: Colors.blue),
                    ),
                    
                    // Campo de texto
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    
                    // Botão enviar
                    IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send, color: 
                        _textController.text.trim().isEmpty ? Colors.grey : Colors.blue
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageOptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enviar imagem'),
        content: Text('Funcionalidade de envio de imagem em desenvolvimento...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}