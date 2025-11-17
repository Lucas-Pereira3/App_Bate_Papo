import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/search_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isSearchingUsers = true;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> results;
      
      if (_isSearchingUsers) {
        results = await _searchService.searchUsers(query);
      } else {
        results = await _searchService.searchGroups(query);
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro na busca: $e');
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
      
      _showSnackbar('Erro ao realizar busca');
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _startConversation(Map<String, dynamic> user) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser?.id;

      if (currentUserId == null) {
        _showSnackbar('Usuário não autenticado');
        return;
      }

      final otherUserId = user['id'];
      final otherUserName = user['full_name'] ?? 'Chat';
      
      final conversationId = await chatService.findOrCreateConversation(
        otherUserId,
        otherUserName,
      );
      
      if (!context.mounted) return;

      Navigator.pushReplacementNamed(
        context, 
        '/chat',
        arguments: {'conversationId': conversationId, 'conversationName': otherUserName}
      );

      _showSnackbar('Conversa iniciada!', isError: false);
    } catch (e) {
      print('Erro ao iniciar conversa: $e');
      _showSnackbar('Erro ao iniciar conversa: $e');
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser?.id;

      if (currentUserId == null) {
        _showSnackbar('Usuário não autenticado');
        return;
      }

      // 1. Pega o ID do grupo existente
      final String groupId = group['id'];
      final String groupName = group['name'] ?? 'Grupo';

      // 2. Chama a nova função 'joinGroup'
      await chatService.joinGroup(groupId, currentUserId);

      // 3. Navega para o grupo existente
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(
        context, 
        '/chat',
        arguments: {'conversationId': groupId, 'conversationName': groupName}
      );

      _showSnackbar('Entrou no grupo!', isError: false);
    } catch (e) {
      print('Erro ao entrar no grupo: $e');
      _showSnackbar('Erro ao entrar no grupo: $e');
    }
  }

  Widget _buildUserResult(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            (user['full_name']?[0] ?? 'U').toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user['full_name'] ?? 'Usuário'),
        subtitle: Text(user['email'] ?? ''),
        trailing:const  Icon(Icons.chat),
        onTap: () => _startConversation(user),
      ),
    );
  }

  Widget _buildGroupResult(Map<String, dynamic> group) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.group, color: Colors.white),
        ),
        title: Text(group['name'] ?? 'Grupo'),
        subtitle: Text(group['is_public'] == true ? 'Público' : 'Privado'),
        trailing: const Icon(Icons.group_add),
        onTap: () => _joinGroup(group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Buscar',style: TextStyle(color: Color(0xFFFF6F4F)),),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: const Color(0xFFFF6F4F),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(
                  color: Colors.white70, 
                  ),
                  decoration: InputDecoration(
                    hintText: 'Digite para buscar...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  onChanged: _performSearch,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Usuários'),
                        selected: _isSearchingUsers,
                        onSelected: (selected) {
                          setState(() {
                            _isSearchingUsers = true;
                          });
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Grupos'),
                        selected: !_isSearchingUsers,
                        onSelected: (selected) {
                          setState(() {
                            _isSearchingUsers = false;
                          });
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Digite para buscar'
                              : 'Nenhum resultado encontrado',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final item = _searchResults[i];
                      return _isSearchingUsers
                          ? _buildUserResult(item)
                          : _buildGroupResult(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}