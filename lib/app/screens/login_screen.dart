import 'package:flutter/material.dart';

import '../../diagram/io/api_client.dart';

/// Sign-in screen. Prefilled with the developer's credentials for quick
/// testing/demos — see [_prefillUsername]/[_prefillPassword].
///
/// SECURITY: the prefilled password ships in the binary. Fine for a personal
/// test build; clear the prefill (or wire --dart-define) before a client/store
/// release.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  // Prefill with Tobias's account.
  static const _prefillUsername = 'gtobias';
  static const _prefillPassword = 'UUUiii111!!!';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _username =
      TextEditingController(text: LoginScreen._prefillUsername);
  late final _password =
      TextEditingController(text: LoginScreen._prefillPassword);
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance
          .login(_username.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Login failed — check your username and password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'StepChat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E)),
                ),
                const SizedBox(height: 4),
                Text('Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                const SizedBox(height: 32),
                TextField(
                  controller: _username,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Username'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _busy ? null : _login(),
                  decoration: _decoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFFF3B30), fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Log In',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
