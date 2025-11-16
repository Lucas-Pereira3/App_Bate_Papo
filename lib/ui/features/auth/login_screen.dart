import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_button.dart';
import '../../../core/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); 

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordObscured = true;

  void _showSnack(BuildContext ctx, String text, {bool err = false}) {
    if (!ctx.mounted) return; 
    final snack = SnackBar(
        content: Text(text),
        backgroundColor: err ? Colors.red : Colors.green);
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
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width:
                        constraints.maxWidth > 768 ? 768 : constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logos/logo_login.png', height: 200),
                        const SizedBox(height: 32),
                        const SizedBox(
                            width: double.infinity,
                            child: Text('Login',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 66, 66, 66),
                                ))),
                        const SizedBox(height: 24),
                        CustomInput(
                            hint: 'Digite seu email',
                            label: 'Email',
                            controller: emailController),
                        const SizedBox(height: 16),
                        
                        CustomInput(
                          hint: 'Digite sua senha',
                          label: 'Senha',
                          controller: passwordController,
                          obscure: _isPasswordObscured, 
                          suffixIcon: IconButton(
                            icon: Icon(
                              
                              _isPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                             
                              setState(() {
                                _isPasswordObscured = !_isPasswordObscured;
                              });
                            },
                          ),
                        ),
                        
                        Align(
                          alignment: Alignment.centerRight,
                          child: CustomTextButton(
                              buttonText: 'Esqueci minha senha',
                              buttonAction: () {
                                Navigator.pushNamed(
                                    context, RoutesEnum.forgotPassword);
                              }),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          buttonText: 'Entrar',
                          backgroundColor: const Color(0xFF424242),
                          buttonAction: () async {
                            try {
                              final res = await auth.signIn(
                                  emailController.text.trim(),
                                  passwordController.text);

                              if (!context.mounted) return;

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
                        const SizedBox(height: 12),
                        CustomTextButton(
                          buttonText: 'Não tem uma conta? Cadastre-se',
                          buttonAction: () =>
                              Navigator.pushNamed(context, '/register'),
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