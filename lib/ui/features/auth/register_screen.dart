import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_button.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmationController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();

  void _showSnack(BuildContext ctx, String text, {bool err = false}) {
    final snack = SnackBar(content: Text(text), backgroundColor: err ? Colors.red : Colors.green);
    ScaffoldMessenger.of(ctx).showSnackBar(snack);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: constraints.maxWidth > 768 ? 768 : constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logos/logo_login.png', height: 200),
                        SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: Text('Registro', style: TextStyle(fontSize: 20))),
                        SizedBox(height: 12),
                        CustomInput(hint: 'Digite seu email', label: 'Email', controller: emailController),
                        SizedBox(height: 12),
                        CustomInput(hint: 'Digite seu nome completo', label: 'Nome', controller: fullNameController),
                        SizedBox(height: 12),
                        CustomInput(hint: 'Digite sua senha', label: 'Senha', controller: passwordController, obscure: true),
                        SizedBox(height: 12),
                        CustomInput(hint: 'Confirme sua senha', label: 'Confirmação da senha', controller: passwordConfirmationController, obscure: true),
                        SizedBox(height: 12),
                        CustomButton(
                          buttonText: 'Registrar',
                          backgroundColor: Color(0xFF03A9F4),
                          buttonAction: () async {
                            if (emailController.text.isEmpty) { _showSnack(context, 'O email não pode ser vazio', err: true); return; }
                            if (fullNameController.text.isEmpty) { _showSnack(context, 'O nome não pode ser vazio', err: true); return; }
                            if (passwordController.text.isEmpty) { _showSnack(context, 'A senha não pode ser vazia', err: true); return; }
                            if (passwordController.text != passwordConfirmationController.text) { _showSnack(context, 'As senhas não coincidem', err: true); return; }

                            try {
                              final res = await auth.signUp(emailController.text.trim(), passwordController.text);
                              if (res.user != null) {
                                _showSnack(context, 'Registrado! Verifique seu email para confirmar a conta.');
                                Navigator.pushReplacementNamed(context, '/login');
                              } else {
                                _showSnack(context, 'Erro no registro', err: true);
                              }
                            } catch (e) {
                              _showSnack(context, e.toString(), err: true);
                            }
                          },
                        ),
                        SizedBox(height: 12),
                        CustomTextButton(
                          buttonText: 'Já tem uma conta? Faça login',
                          buttonAction: () => Navigator.pushNamed(context, '/login'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}