import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase_config.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  final Uuid _uuid = Uuid();
  late Future<List<dynamic>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _conversationsFuture = _fetchConversations();
    });
  }

  Future<List<dynamic>> _fetchConversations() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // Busca conversas onde o usuário atual é participante
      final response = await _client
          .from('participants')
          .select('''
            conversation:conversations(
              id,
              name,
              created_at,
              created_by,
              participants!inner(user_id),
              messages(id, content, created_at, type)
            )
          ''')
          .eq('user_id', currentUserId);

      // Extrai as conversas da resposta
      final conversations = (response as List<dynamic>)
          .map((item) => item['conversation'] as Map<String, dynamic>)
          .toList();

      return conversations;
    } catch (e) {
      print('Erro ao carregar conversas: $e');
      return [];
    }
  }

  // MÉTODO CORRIGIDO PARA CRIAR CONVERSA
  void _createNewConversation(BuildContext context) {
    final TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Nova Conversa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome da conversa',
                    hintText: 'Ex: Minhas Notas',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Você será o primeiro participante da conversa',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  
                  if (name.isEmpty) {
                    _showSnackbar(context, 'Digite um nome para a conversa');
                    return;
                  }

                  // Mostrar loading
                  setDialogState(() {});

                  try {
                    await _createConversation(name);
                    Navigator.pop(context); // Fecha o dialog
                    _loadConversations(); // Recarrega a lista
                    _showSnackbar(context, 'Conversa criada com sucesso!', isError: false);
                  } catch (e) {
                    _showSnackbar(context, 'Erro: $e');
                  }
                },
                child: Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // MÉTODO SIMPLIFICADO E CORRIGIDO
  Future<void> _createConversation(String name) async {
    try {
      final currentUserId = _client.auth.currentUser!.id;

      // 1. Cria a conversa
      final conversationId = _uuid.v4();
      
      await _client.from('conversations').insert({
        'id': conversationId,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': currentUserId,
      });
      
      // 2. Adiciona o usuário atual como participante
      await _client.from('participants').insert({
        'id': _uuid.v4(),
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // 3. Cria uma mensagem de boas-vindas
      await _client.from('messages').insert({
        'id': _uuid.v4(),
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': 'Conversa "$name" iniciada!',
        'type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Conversa criada: $conversationId');
      
    } catch (e) {
      print('❌ Erro ao criar conversa: $e');
      throw Exception('Erro ao criar conversa: $e');
    }
  }

  void _showSnackbar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Agora';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Zapiz - Conversas'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Erro ao carregar conversas'),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }
          
          final conversations = snapshot.data ?? [];
          
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma conversa encontrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toque no botão + para iniciar uma conversa',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _createNewConversation(context),
                    icon: Icon(Icons.add),
                    label: Text('Criar Primeira Conversa'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (ctx, i) {
                final conv = conversations[i];
                final name = conv['name'] ?? 'Chat';
                final id = conv['id'];
                
                // Extrair informações da última mensagem
                final messages = conv['messages'] as List<dynamic>? ?? [];
                final lastMessage = messages.isNotEmpty ? messages.last : null;
                final lastMessageText = lastMessage != null 
                  ? (lastMessage['content'] ?? 'Imagem')
                  : 'Nenhuma mensagem';
                
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessageText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    trailing: messages.isNotEmpty 
                      ? Text(
                          _formatTime(lastMessage?['created_at']),
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      : null,
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        RoutesEnum.chat, 
                        arguments: {'conversationId': id}
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () => _createNewConversation(context),
      ),
    );
  }
}