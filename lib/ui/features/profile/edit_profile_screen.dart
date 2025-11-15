import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/profile_service.dart';
import '../../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentAvatarUrl;

  // Flag para marcar a remoção
  bool _removeImageFlag = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final profileService = Provider.of<ProfileService>(context, listen: false);
      final profile = profileService.currentProfile;
      
      if (profile != null) {
        setState(() {
          _nameController.text = profile['full_name'] ?? '';
          _currentAvatarUrl = profile['avatar_url']; 
          _isInitialized = true;
        });
      } else {
        await profileService.initializeProfile();
        final newProfile = profileService.currentProfile;
        if (newProfile != null) {
           setState(() {
             _nameController.text = newProfile['full_name'] ?? '';
             _currentAvatarUrl = newProfile['avatar_url'];
             _isInitialized = true;
           });
        }
      }
    } catch (e) {
      print('Erro ao carregar perfil: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _removeImageFlag = false; // Se escolheu foto, não está removendo
        });
      }
    } catch (e) {
      print('Erro ao selecionar imagem: $e');
      _showSnackbar('Erro ao selecionar imagem');
    }
  }

  // Função para o botão de remover
  void _removeImage() {
    setState(() {
      _imageBytes = null; 
      _currentAvatarUrl = null; 
      _removeImageFlag = true; 
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      _showSnackbar('O nome não pode estar vazio');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profileService = Provider.of<ProfileService>(context, listen: false);
      
      // Passa a flag de remoção
      await profileService.updateProfile(
        _nameController.text, 
        _imageBytes,
        removeImage: _removeImageFlag,
      );
      
      _showSnackbar('Perfil atualizado com sucesso!', isError: false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackbar('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          if (_isInitialized)
            IconButton(
              onPressed: _isLoading ? null : _saveProfile,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      body: _isInitialized
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _imageBytes != null
                              ? MemoryImage(_imageBytes!)
                              : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _currentAvatarUrl! 
                                    )
                                  : null) as ImageProvider?,
                          child: _imageBytes == null && (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white) 
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botão de remover foto
                  TextButton(
                    onPressed: _removeImage,
                    child: const Text(
                      'Remover foto',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  
                  const SizedBox(height: 12), 
                  
                  TextFormField(
                    initialValue: Provider.of<ProfileService>(context).currentProfile?['email'] ?? 
                                  Provider.of<AuthService>(context).currentUser?.email ?? '',
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                      hintText: 'Digite seu nome completo',
                    ),
                  ),
                 const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const  SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}