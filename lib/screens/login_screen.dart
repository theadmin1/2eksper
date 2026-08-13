import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const navy = Color(0xFF0F172A);
  static const iceBlue = Color(0xFF0EA5E9);
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final success = await auth.login(username.text.trim(), password.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Giriş yapılamadı.')),
      );
    }
  }

  Future<void> serverSettings() async {
    final controller = TextEditingController(text: ApiService.baseUrl);
    final messenger = ScaffoldMessenger.of(context);
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Sunucu Adresi'),
        content: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'https://sunucu.com/api/v1',
            padding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final previous = ApiService.baseUrl;
                try {
                  await ApiService.setBaseUrl(controller.text);
                  await ApiService.checkConnection();
                } on ApiException catch (error) {
                  await ApiService.setBaseUrl(previous);
                  if (!dialogContext.mounted) return;
                  messenger
                      .showSnackBar(SnackBar(content: Text(error.message)));
                  return;
                }
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Sunucu bağlantısı doğrulandı.')),
                );
              }
            },
            child: const Text('Test Et ve Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appTheme = context.read<AppThemeProvider>();
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = colors.onSurface;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        tooltip: dark ? 'Açık moda geç' : 'Koyu moda geç',
                        onPressed: () => appTheme.toggleBrightness(
                          Theme.of(context).brightness,
                        ),
                        icon: Icon(
                          dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 310),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: dark ? .24 : .08,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/brand_splash_logo.png',
                        fit: BoxFit.contain,
                        semanticLabel: '2EKSPER',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oto Ekspertiz & Galeri Yönetimi',
                      style: TextStyle(
                        color:
                            (dark ? Colors.white : navy).withValues(alpha: .58),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colors.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: iceBlue.withValues(alpha: dark ? .15 : .05),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tekrar hoş geldiniz',
                              style: TextStyle(
                                color: text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Operasyon panelinize güvenli giriş yapın.',
                              style: TextStyle(
                                color: text.withValues(alpha: .55),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: username,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Kullanıcı adı veya e-posta',
                                prefixIcon: Icon(CupertinoIcons.person),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Kullanıcı adınızı girin.'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: password,
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => submit(),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(CupertinoIcons.lock),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(obscure
                                      ? CupertinoIcons.eye_slash
                                      : CupertinoIcons.eye),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Şifrenizi girin.'
                                      : null,
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: auth.isLoading ? null : submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: iceBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: serverSettings,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('Sunucu bağlantı ayarları'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
