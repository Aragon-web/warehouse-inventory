import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40, height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 16),
                  Text('جاري التحميل...',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        if (auth.isSetup) return const _SetupForm();
        if (auth.isLogin) return const _LoginForm();
        return child;
      },
    );
  }
}

class _SetupForm extends StatefulWidget {
  const _SetupForm();

  @override
  State<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<_SetupForm> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().setup(
      _userCtrl.text.trim(),
      _passCtrl.text,
      _pass2Ctrl.text,
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<AuthProvider>().error;
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('إعداد الحساب',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _errorBox(error),
                    ),
                  TextField(
                    controller: _userCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass2Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? 'جاري الإنشاء...' : 'إنشاء الحساب'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<AuthProvider>().error;
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تسجيل الدخول',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _errorBox(error),
                    ),
                  TextField(
                    controller: _userCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? 'جاري الدخول...' : 'دخول'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _errorBox(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x77FFE4E6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x33F43F5E)),
    ),
    child: Text(message,
      style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
  );
}
