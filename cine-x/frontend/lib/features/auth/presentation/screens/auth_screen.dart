import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/backend_connection_banner.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController(text: 'owner@cinex.local');
  final _password = TextEditingController(text: 'CineX@123');
  final _confirm = TextEditingController(text: 'CineX@123');
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        children: [
          const _StudioBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 44 : 20,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: wide
                          ? Row(
                              children: [
                                const Expanded(child: _BrandPanel()),
                                const SizedBox(width: 36),
                                SizedBox(
                                  width: 430,
                                  child: _AuthCard(
                                    formKey: _formKey,
                                    name: _name,
                                    email: _email,
                                    password: _password,
                                    confirm: _confirm,
                                    register: _register,
                                    obscure: _obscure,
                                    loading: auth.loading,
                                    error: auth.error,
                                    onToggleMode: _toggleMode,
                                    onTogglePassword: () => setState(
                                      () => _obscure = !_obscure,
                                    ),
                                    onSubmit: _submit,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _MobileBrandHeader(),
                                const SizedBox(height: 24),
                                _AuthCard(
                                  formKey: _formKey,
                                  name: _name,
                                  email: _email,
                                  password: _password,
                                  confirm: _confirm,
                                  register: _register,
                                  obscure: _obscure,
                                  loading: auth.loading,
                                  error: auth.error,
                                  onToggleMode: _toggleMode,
                                  onTogglePassword: () => setState(
                                    () => _obscure = !_obscure,
                                  ),
                                  onSubmit: _submit,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMode() {
    setState(() => _register = !_register);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (_register) {
      await auth.register(
        _name.text,
        _email.text,
        _password.text,
        _confirm.text,
      );
    } else {
      await auth.login(_email.text, _password.text);
    }
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.confirm,
    required this.register,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool register;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CineXPalette.card.withAlpha(228),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withAlpha(18)),
            boxShadow: [
              BoxShadow(
                color: CineXPalette.primary.withAlpha(32),
                blurRadius: 52,
                offset: const Offset(0, 28),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Column(
                      key: ValueKey(register),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          register ? 'Create your studio' : 'Welcome back',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: CineXPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          register
                              ? 'Start planning scripts, scenes, locations, and production boards.'
                              : 'Sign in to your screenplay planning workspace.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: CineXPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const BackendConnectionBanner(),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: register
                        ? Column(
                            key: const ValueKey('name-field'),
                            children: [
                              TextFormField(
                                controller: name,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Display name',
                                  prefixIcon: Icon(Icons.badge_rounded),
                                ),
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Enter your display name'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('no-name')),
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (!text.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    textInputAction:
                        register ? TextInputAction.next : TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: onTogglePassword,
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 8) return 'Use at least 8 characters';
                      if (!RegExp('[A-Z]').hasMatch(text) ||
                          !RegExp('[a-z]').hasMatch(text) ||
                          !RegExp(r'\d').hasMatch(text)) {
                        return 'Use uppercase, lowercase, and a number';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!register) onSubmit();
                    },
                  ),
                  if (register) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirm,
                      obscureText: obscure,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (value) => value != password.text
                          ? 'Passwords do not match'
                          : null,
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.error.withAlpha(24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              Theme.of(context).colorScheme.error.withAlpha(80),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: loading ? null : onSubmit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            register
                                ? Icons.person_add_alt_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(register ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: loading ? null : onToggleMode,
                    child: Text(
                      register
                          ? 'Already have an account? Sign in'
                          : 'New to CINE-X? Create an account',
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

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BrandMark(size: 84),
        const SizedBox(height: 28),
        Text(
          'CINE-X',
          style: theme.textTheme.displaySmall?.copyWith(
            color: CineXPalette.textPrimary,
            fontSize: 54,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'A premium workspace for screenplay planning, visual boards, cast tracking, and production analytics.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: CineXPalette.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FeaturePill(icon: Icons.view_kanban_rounded, label: 'Storyboard'),
            _FeaturePill(icon: Icons.groups_rounded, label: 'Characters'),
            _FeaturePill(icon: Icons.location_on_rounded, label: 'Locations'),
            _FeaturePill(icon: Icons.pie_chart_rounded, label: 'Analytics'),
          ],
        ),
      ],
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BrandMark(size: 54),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'CINE-X',
            style: TextStyle(
              color: CineXPalette.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CineXPalette.primary,
            CineXPalette.secondary,
            Color(0xFF191C24),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: CineXPalette.primary.withAlpha(72),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Icon(
        Icons.movie_filter_rounded,
        color: Colors.white,
        size: size * 0.48,
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CineXPalette.surface.withAlpha(170),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: CineXPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: CineXPalette.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: CineXPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F1115),
                Color(0xFF171A23),
                Color(0xFF11131A),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _FilmGridPainter()),
        ),
      ],
    );
  }
}

class _FilmGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 96) {
      canvas.drawLine(Offset(x, 0), Offset(x + 260, size.height), paint);
    }
    final accent = Paint()
      ..color = CineXPalette.primary.withAlpha(28)
      ..strokeWidth = 1.2;
    for (var y = 80.0; y < size.height; y += 180) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 100), accent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
