// Pantalla de Inicio de Sesión con autenticación manual + Google

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pase_de_asistencia/screens/home_screen.dart';
import 'dart:convert';

// Firebase y Google
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _imageError = false;
  String? _errorMessage;

  Future<List<Map<String, dynamic>>> _loadSupervisores() async {
    try {
      final String jsonString =
      await rootBundle.loadString('assets/supervisores.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      return jsonData.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error cargando supervisores: $e');
      return [];
    }
  }

  Future<void> _loadImage() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/login.jpg'),
        context,
      );
      if (mounted) setState(() => _imageError = false);
    } catch (e) {
      if (mounted) setState(() => _imageError = true);
      debugPrint('Error loading image: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supervisores = await _loadSupervisores();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final supervisorValido = supervisores.any((sup) =>
      sup['email'] == email && sup['password'] == password);

      if (supervisorValido && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Credenciales incorrectas');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error al validar credenciales');
      debugPrint('Error en login: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      //1.- Cerrar cualquier sesion previa
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      //2.- Iniciar el flujo de autenticacion
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      //Cierra sesión previa para forzar seleccion de cuenta
      await googleSignIn.signOut();
      //final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      //3.- Obtener el token de autenticacion
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      //4.- Crear credenciales para Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      //5.- Autenticar con Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      //6.- Verificar si el usuario es autorizado
      final userEmail = userCredential.user?.email;
      final supervisores = await _loadSupervisores();
      final isAutorizado = supervisores.any((sup) => sup['email'] == userEmail);

      if (isAutorizado && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (mounted) {
          setState(() {
            _errorMessage = 'Correo no Autorizado';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error en autenticación con Google';
          _isLoading = false;
        });
      }
      debugPrint('Google Sign-In error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    double formPosition = keyboardHeight > 0
        ? screenHeight - keyboardHeight - 340
        : screenHeight * 0.40;
    formPosition = formPosition.clamp(0.0, screenHeight * 0.40);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[200]);
              },
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            top: formPosition,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'INICIAR SESIÓN',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo Electrónico',
                          labelStyle: const TextStyle(
                            color: Colors.grey,
                          ),
                          hintText: 'Ingrese su correo',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                          ),
                          prefixIcon: const Icon(Icons.email),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Color(0xFF193863),
                              width: 2.0,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blueAccent),
                          ),
                        ),
                        validator: _validarCorreo,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecorationConToggle(),
                        validator: _validarContrasena,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 15),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF193863),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      //const Text("Inicia Sesión con Google"),
                      const SizedBox(height: 0.8),
                      OutlinedButton.icon(
                        icon: Image.asset(
                          'assets/images/google_logo.png',
                          height: 24,
                          width: 24,
                        ),
                        label: const Text(
                          "Continuar con Google",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  InputDecoration _inputDecorationConToggle() {
    return InputDecoration(
      labelText: 'Contraseña',
      labelStyle: const TextStyle(
        color: Colors.grey
      ),
      hintText: 'Ingrese su contraseña',
      hintStyle: const TextStyle(
        color: Colors.grey,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Color(0xFF193863),
          width: 2.0,
        ),
      ),
      prefixIcon: const Icon(Icons.lock),
      suffixIcon: IconButton(
        icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  String? _validarCorreo(String? value) {
    if (value == null || value.isEmpty) return 'Ingrese su correo';
    if (!value.contains('@')) return 'Correo inválido';
    return null;
  }

  String? _validarContrasena(String? value) {
    if (value == null || value.isEmpty) return 'Ingrese su contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }
}
