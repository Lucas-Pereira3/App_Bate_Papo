import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_button.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _showSnack(BuildContext ctx, String text, {bool err = false}) {
    final snack = SnackBar(
      content: Text(text), 
      backgroundColor: err ? Colors.red : Colors.green
    );
    ScaffoldMessenger.of(ctx).showSnackBar(snack);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: Center(
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
                      SizedBox(
                        width: double.infinity, 
                        child: Text('Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                      ),
                      SizedBox(height: 12),
                      CustomInput(
                        hint: 'Digite seu email', 
                        label: 'Email', 
                        controller: emailController
                      ),
                      SizedBox(height: 12),
                      CustomInput(
                        hint: 'Digite sua senha', 
                        label: 'Senha', 
                        controller: passwordController, 
                        obscure: true
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CustomTextButton(
                          buttonText: 'Esqueci minha senha', 
                          buttonAction: () {}
                        ),
                      ),
                      SizedBox(height: 12),
                      CustomButton(
                        buttonText: 'Entrar',
                        backgroundColor: Color(0xFF03A9F4),
                        buttonAction: () async {
                          try {
                            final res = await auth.signIn(
                              emailController.text.trim(), 
                              passwordController.text
                            );
                            
                            if (res.session == null) {
                              _showSnack(context, 'Erro no login', err: true);
                              return;
                            }
                            
                            _showSnack(context, 'Logado com sucesso');
                            Navigator.pushReplacementNamed(context, '/home');
                          } catch (e) {
                            _showSnack(context, e.toString(), err: true);
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      CustomTextButton(
                        buttonText: 'Não tem uma conta? Cadastre-se',
                        buttonAction: () => Navigator.pushNamed(context, '/register'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}