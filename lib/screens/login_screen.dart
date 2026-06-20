import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.iniciarSesion(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      // La navegación real ocurre en main.dart, escuchando cambiosSesion.
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión. Verifica tus datos.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 64, color: AppTheme.primario),
                const SizedBox(height: 12),
                const Text(
                  'Mr Barril',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primario),
                ),
                const Text(
                  'Gestión de pedidos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textoSecundario),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _iniciarSesion(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.peligro)),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _cargando ? null : _iniciarSesion,
                  child: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ingresar'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tu cuenta es creada manualmente por el administrador de la plataforma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
