
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // GoRouter redirects to /home after successful login.
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),

                    const SizedBox(height: 36),

                    // Galaxy login card.
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: GalaxyColors.surface
                            .withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: GalaxyColors.purple
                              .withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: GalaxyColors.purple
                                .withValues(alpha: 0.10),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome Back!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GalaxyColors.textPrimary,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Sign in to continue your adventure',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GalaxyColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 25),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF572637)
                                    .withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFF6B82)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFFF91A4),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC6D0),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 17),
                          ],

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: GalaxyColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  !value.trim().contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 17),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_loading) _login();
                            },
                            style: const TextStyle(
                              color: GalaxyColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: GalaxyColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscure = !_obscure;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 26),

                          // Neon gradient sign-in button.
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8054DF),
                                  Color(0xFFA78BFA),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: GalaxyColors.purple
                                      .withValues(alpha: 0.32),
                                  blurRadius: 19,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _loading ? null : _login,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 23,
                                          height: 23,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.login_rounded,
                                              color: Colors.white,
                                              size: 21,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
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
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: GalaxyColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.push('/register'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: GalaxyColors.purple,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Center(
                      child: Text(
                        'STUDY  •  FOCUS  •  GROW',
                        style: TextStyle(
                          color: GalaxyColors.textSecondary,
                          letterSpacing: 2,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                GalaxyColors.purple.withValues(alpha: 0.32),
                GalaxyColors.purple.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(
            Icons.pets_rounded,
            color: GalaxyColors.purple,
            size: 76,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'AralPet',
          style: TextStyle(
            fontSize: 39,
            fontWeight: FontWeight.w900,
            color: GalaxyColors.textPrimary,
            letterSpacing: -1,
            shadows: [
              Shadow(
                color: Color(0xAA8B5CF6),
                blurRadius: 22,
              ),
            ],
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Your Study Companion in a Galaxy of Progress',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: GalaxyColors.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 13),

        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              color: GalaxyColors.gold,
              size: 14,
            ),
            SizedBox(width: 15),
            Icon(
              Icons.auto_awesome_rounded,
              color: GalaxyColors.blue,
              size: 19,
            ),
            SizedBox(width: 15),
            Icon(
              Icons.star_rounded,
              color: GalaxyColors.pink,
              size: 14,
            ),
          ],
        ),
      ],
    );
  }
}
