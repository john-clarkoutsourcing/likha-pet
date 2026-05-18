import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _err('Please fill in all fields');
      return;
    }
    await ref.read(authProvider.notifier).login(email: email, password: password);
    if (!mounted) return;
    final s = ref.read(authProvider);
    if (s == AuthState.authenticated) {
      // HomeScreen owns setUserId + initialize — just navigate there.
      if (mounted) context.go('/home');
    } else if (s == AuthState.error) {
      _err(ref.read(authErrorProvider) ?? 'Login failed');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg,
              style: const TextStyle(fontFamily: 'Fredoka', fontSize: 13)),
          backgroundColor: const Color(0xFFFF3355),
          duration: const Duration(seconds: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) == AuthState.authenticating;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: Stack(children: [
        // ── Animated background glow ─────────────────────────────────────────
        AnimatedBuilder(
          animation: _glow,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.7),
                radius: 1.2,
                colors: [
                  const Color(0xFF4AC4D9)
                      .withValues(alpha: 0.06 + _glow.value * 0.04),
                  const Color(0xFF050810),
                ],
              ),
            ),
          ),
        ),
        // ── Content ──────────────────────────────────────────────────────────
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _LogoBadge(glow: _glow),
                    const SizedBox(height: 16),

                    // Title
                    Text('LIKHA PET',
                        style: const TextStyle(
                          fontFamily: 'LilitaOne',
                          color: Color(0xFFEAFBFF),
                          fontSize: 36,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                                color: Color(0xFF4AC4D9),
                                blurRadius: 18,
                                offset: Offset(0, 0)),
                          ],
                        )),
                    const SizedBox(height: 4),
                    Text('Filipino-inspired Pet Battle Game',
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFF4AC4D9).withValues(alpha: 0.7),
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        )),

                    const SizedBox(height: 32),

                    // Card panel
                    _AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('WELCOME BACK',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          const Text('Enter the arena',
                              style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  color: Colors.white38,
                                  fontSize: 12),
                              textAlign: TextAlign.center),

                          const SizedBox(height: 20),

                          _GameField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'your@email.com',
                            icon: Icons.alternate_email_rounded,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _GameField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            enabled: !isLoading,
                            obscure: _obscure,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                          ),

                          const SizedBox(height: 20),

                          // Login button
                          _GameButton(
                            label: isLoading ? null : 'ENTER THE ARENA',
                            loading: isLoading,
                            onTap: isLoading ? null : _handleLogin,
                            color: const Color(0xFF4AC4D9),
                          ),

                          const SizedBox(height: 16),

                          // Register link
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("New to Likha Pet?  ",
                                    style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        color: Colors.white38,
                                        fontSize: 12)),
                                GestureDetector(
                                  onTap: () => context.go('/register'),
                                  child: Text('Create Account',
                                      style: GoogleFonts.rajdhani(
                                        color: const Color(0xFFCE93D8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      )),
                                ),
                              ]),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Feature pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: const [
                        _FeaturePill('🐾 Collect Pets'),
                        _FeaturePill('⚔ 3v3 Battle'),
                        _FeaturePill('🧬 DNA Genetics'),
                        _FeaturePill('🏆 PvP Arena'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Register Screen ───────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureA = true;
  bool _obscureB = true;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _err('Please fill in all fields');
      return;
    }
    if (pass != confirm) {
      _err('Passwords do not match');
      return;
    }
    await ref.read(authProvider.notifier).register(email: email, password: pass);
    if (!mounted) return;
    final s = ref.read(authProvider);
    if (s == AuthState.authenticated) {
      if (mounted) context.go('/home');
    } else if (s == AuthState.error) {
      _err(ref.read(authErrorProvider) ?? 'Registration failed');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg,
              style: const TextStyle(fontFamily: 'Fredoka', fontSize: 13)),
          backgroundColor: const Color(0xFFFF3355),
          duration: const Duration(seconds: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) == AuthState.authenticating;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: Stack(children: [
        AnimatedBuilder(
          animation: _glow,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, -0.5),
                radius: 1.2,
                colors: [
                  const Color(0xFF9C27B0)
                      .withValues(alpha: 0.06 + _glow.value * 0.04),
                  const Color(0xFF050810),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LogoBadge(glow: _glow, color: const Color(0xFFCE93D8)),
                    const SizedBox(height: 16),

                    Text('LIKHA PET',
                        style: const TextStyle(
                          fontFamily: 'LilitaOne',
                          color: Color(0xFFEAFBFF),
                          fontSize: 36,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                                color: Color(0xFF9C27B0),
                                blurRadius: 18),
                          ],
                        )),
                    const SizedBox(height: 4),
                    Text('Begin your legend',
                        style: GoogleFonts.rajdhani(
                          color:
                              const Color(0xFFCE93D8).withValues(alpha: 0.7),
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        )),

                    const SizedBox(height: 32),

                    _AuthCard(
                      accentColor: const Color(0xFF9C27B0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('CREATE ACCOUNT',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          const Text('Your journey awaits',
                              style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  color: Colors.white38,
                                  fontSize: 12),
                              textAlign: TextAlign.center),

                          const SizedBox(height: 20),

                          _GameField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'your@email.com',
                            icon: Icons.alternate_email_rounded,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            accentColor: const Color(0xFFCE93D8),
                          ),
                          const SizedBox(height: 12),
                          _GameField(
                            controller: _passCtrl,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            enabled: !isLoading,
                            obscure: _obscureA,
                            onToggleObscure: () =>
                                setState(() => _obscureA = !_obscureA),
                            accentColor: const Color(0xFFCE93D8),
                          ),
                          const SizedBox(height: 12),
                          _GameField(
                            controller: _confirmCtrl,
                            label: 'Confirm Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            enabled: !isLoading,
                            obscure: _obscureB,
                            onToggleObscure: () =>
                                setState(() => _obscureB = !_obscureB),
                            accentColor: const Color(0xFFCE93D8),
                          ),

                          const SizedBox(height: 20),

                          _GameButton(
                            label: isLoading ? null : 'BEGIN JOURNEY',
                            loading: isLoading,
                            onTap: isLoading ? null : _handleRegister,
                            color: const Color(0xFF9C27B0),
                          ),

                          const SizedBox(height: 16),

                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Already a Trainer?  ",
                                    style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        color: Colors.white38,
                                        fontSize: 12)),
                                GestureDetector(
                                  onTap: () => context.go('/login'),
                                  child: Text('Sign In',
                                      style: GoogleFonts.rajdhani(
                                        color: const Color(0xFF4AC4D9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      )),
                                ),
                              ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final AnimationController glow;
  final Color color;
  const _LogoBadge({required this.glow, this.color = const Color(0xFF4AC4D9)});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1224),
          border: Border.all(
              color: color.withValues(alpha: 0.5 + glow.value * 0.3),
              width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2 + glow.value * 0.2),
              blurRadius: 20 + glow.value * 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Text('🐾', style: TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  const _AuthCard({
    required this.child,
    this.accentColor = const Color(0xFF4AC4D9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accentColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool enabled;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final Color accentColor;

  const _GameField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.accentColor = const Color(0xFF4AC4D9),
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
          fontFamily: 'Fredoka', color: Color(0xFFEAFBFF), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: 'Fredoka',
            color: accentColor.withValues(alpha: 0.6),
            fontSize: 12),
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.white24, fontFamily: 'Fredoka'),
        prefixIcon:
            Icon(icon, color: accentColor.withValues(alpha: 0.5), size: 18),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white24,
                  size: 18,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF060D1C),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  final String? label;
  final bool loading;
  final VoidCallback? onTap;
  final Color color;

  const _GameButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap != null
                ? [color, color.withValues(alpha: 0.75)]
                : [Colors.white12, Colors.white10],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String text;
  const _FeaturePill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4AC4D9).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF4AC4D9).withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Fredoka',
                color: Colors.white38,
                fontSize: 10)),
      );
}
