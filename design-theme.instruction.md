This is the single source of truth for the project's visual language. Every new screen should follow these rules so it instantly feels like part of the same game.

---

## 1. Quick Start — New Page Template

Use this widget structure as the skeleton for any new screen. It wraps the viewport in a rigid 16:9 frame, injects the radial background gradients, provides inner scrolling, and sets up the game header.

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MyNewPage extends StatelessWidget {
  final VoidCallback? onBack;

  const MyNewPage({Key? key, this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        // 16:9 Canvas Cap Constraints
        constraints: const BoxConstraints(maxWidth: 1600, minHeight: 600),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ],
              gradient: const RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF0E1A33), Color(0xFF050810)],
                stops: [0.0, 0.7],
              ),
            ),
            child: Stack(
              children: [
                // Faint rune backdrop glimmer
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.6, -0.8),
                          radius: 0.35,
                          colors: [Color(0xFF7FE3F5), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.7, 0.4),
                          radius: 0.35,
                          colors: [Color(0xFFE85AA8), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Scrollable Inner Content Area
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 24),
                          // --- Page content goes here ---
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1224).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4AC4D9).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                size: 16,
                color: Color(0xFFBFF0FA),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page Title',
                style: TextStyle(
                  fontFamily: 'LilitaOne',
                  fontSize: 32,
                  letterSpacing: 0.5,
                  color: const Color(0xFFEAFBFF),
                  shadows: GameEffects.textOutlineShadow(
                    glowColor: const Color(0xFF4AC4D9).withOpacity(0.6),
                    outlineColor: const Color(0xFF0A1224),
                    thickness: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Subtitle in Fredoka',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 14,
                  color: Color(0x99BFF0FA),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
Then wire it into your application state or routing layer by adding to your view state configuration.2. Color PaletteThese are the ONLY colors you should reach for. Avoid introducing new hues.SurfacesTokenHexUseBase background#050810The dark void behind everythingDeep navy "wood"#0A1224Cards, modals, dark UI chromeMid plank#1F2C47Subtle borders, inset surfacesLighter plank#2A3A5CHover backgrounds, raised tilesWood highlight#5B7AA8Top edge highlights on wood elementsAccentsTokenHexUseCyan deep#4AC4D9Primary accent, default rim glowCyan light#7FE3F5Hover/active glow, icon accentCyan ice#BFF0FAHighlight/text on cyan elementsMagenta#E85AA8Secondary accent — PVP, active states, dangerMagenta light#FFC9E4Highlight/text on magenta elementsMagenta deep#9C2872Used sparingly for pressed/deep statesTextTokenHex/AlphaUseDefault text#EAFBFFAll body and label text on dark backgroundsMuted0x99BFF0FASubtitles, helper text (cyan ice at 60%)Faint0x66BFF0FACaptions, meta-data (cyan ice at 40%)Dartclass GameColors {
  static const Color baseBackground  = Color(0xFF050810);
  static const Color deepNavyWood   = Color(0xFF0A1224);
  static const Color midPlank        = Color(0xFF1F2C47);
  static const Color lighterPlank    = Color(0xFF2A3A5C);
  static const Color woodHighlight   = Color(0xFF5B7AA8);

  static const Color cyanDeep        = Color(0xFF4AC4D9);
  static const Color cyanLight       = Color(0xFF7FE3F5);
  static const Color cyanIce         = Color(0xFFBFF0FA);
  static const Color magenta         = Color(0xFFE85AA8);
  static const Color magentaLight    = Color(0xFFFFC9E4);
  static const Color magentaDeep     = Color(0xFF9C2872);

  static const Color textDefault     = Color(0xFFEAFBFF);
  static const Color textMuted       = Color(0x99BFF0FA);
  static const Color textFaint       = Color(0x66BFF0FA);
}
Rule: Cyan is the dominant accent. Magenta is the secondary, used only for active states, PVP/danger, or to mirror a cyan element (split screens, ACTIVE chips). Never gradient between random colors — only cyanDeep -> cyanDarker or magenta -> magentaDeep.3. TypographyTwo fonts only. Register them in your pubspec.yaml.YAMLflutter:
  fonts:
    - family: LilitaOne
      fonts:
        - asset: assets/fonts/LilitaOne-Regular.ttf
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
UsageFontHow to applyPage titleLilita OnefontFamily: 'LilitaOne', fontSize: 32Section headingLilita OnefontFamily: 'LilitaOne', fontSize: 18, letterSpacing: 0.5Button labelLilita OnefontFamily: 'LilitaOne', fontSize: 14, letterSpacing: 0.5Chip / tagLilita OnefontFamily: 'LilitaOne', fontSize: 10, letterSpacing: 1.2Body / subtitleFredokafontFamily: 'Fredoka'Meta / numbersSystem MonofontFamily: 'monospace', fontSize: 10Lilita One labels MUST have an outline. Use this text shadow helper matrix:Dartclass GameEffects {
  static List<Shadow> textOutlineShadow({
    Color glowColor = const Color(0x994AC4D9),
    Color outlineColor = const Color(0xFF0A1224),
    double thickness = 2.0,
  }) {
    return [
      Shadow(blurRadius: 12.0, color: glowColor, offset: Offset.zero),
      Shadow(offset: Offset(-thickness, -thickness), color: outlineColor),
      Shadow(offset: Offset(thickness, -thickness), color: outlineColor),
      Shadow(offset: Offset(-thickness, thickness), color: outlineColor),
      Shadow(offset: Offset(thickness, thickness), color: outlineColor),
    ];
  }
}
Smaller labels can drop the outline thickness to 1.0.4. Layout & ResponsivenessThe CanvasEvery page is mounted inside a 16:9 capped canvas that scales with the viewport using constraints and AspectRatio:DartContainer(
  constraints: const BoxConstraints(maxWidth: 1600, minHeight: 600),
  child: AspectRatio(
    aspectRatio: 16 / 9,
    child: Container( /* Canvas Content */ ),
  ),
)
maxWidth: 1600 — never wider than 1600px.AspectRatio(aspectRatio: 16 / 9) — keeps the 16:9 ratio.clipBehavior: Clip.antiAlias — clips children inside the rounded decoration frame.Scrolling ContentWrap content sections inside a SingleChildScrollView (or standard ListView) configured inside the absolute Stack space so it scrolls inside the canvas instead of altering the canvas size metrics:DartPositioned.fill(
  child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column( ... ),
  ),
)
Padding & GapsUse these consistently:Page padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24)Card padding: EdgeInsets.all(12) for compact, EdgeInsets.all(16) or EdgeInsets.all(20) for prominentSection spacing: SizedBox(height: 20) or SizedBox(height: 24) between major blocksGrid/flex gaps: Spacers or spacing attributes at 8 for chips, 12 for cards in lists, 16 for gridsResponsive GridsUse LayoutBuilder alongside GridView.builder to dynamically pivot cross-axis structures depending on standard canvas widths:DartWidget buildResponsiveGrid(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      int crossAxisCount = 1;
      if (constraints.maxWidth > 1200) crossAxisCount = 4;
      else if (constraints.maxWidth > 800) crossAxisCount = 3;
      else if (constraints.maxWidth > 550) crossAxisCount = 2;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        itemCount: 8,
        itemBuilder: (context, index) => const GameCard(child: SizedBox()),
      );
    },
  );
}
Rule: Never require horizontal scroll. Everything wraps, shrinks, or maps conditionally through layout parameters.5. Component PatternsCard (rounded-2xl, dark gradient, cyan border)Dartclass GameCard extends StatelessWidget {
  final Widget child;
  
  const GameCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFF4AC4D9).withOpacity(0.25),
          width: 2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1A33), Color(0xFF0A1224), Color(0xFF050810)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: child,
    );
  }
}
Primary Button (chunky cyan CTA / hover interactive scale)Dartclass GamePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isMagenta;

  const GamePrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isMagenta = false,
  }) : super(key: key);

  @override
  State<GamePrimaryButton> createState() => _GamePrimaryButtonState();
}

class _GamePrimaryButtonState extends State<GamePrimaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isMagenta ? const Color(0xFFE85AA8) : const Color(0xFF4AC4D9);
    final deepColor = widget.isMagenta ? const Color(0xFF9C2872) : const Color(0xFF2B8A9C);
    final lightHighlight = widget.isMagenta ? const Color(0xFFFFC9E4) : const Color(0xFF7FE3F5);
    final shadowColor = widget.isMagenta ? const Color(0x8CE85AA8) : const Color(0x8C4AC4D9);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: lightHighlight, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [baseColor, deepColor],
              ),
              boxShadow: [
                BoxShadow(color: shadowColor, blurRadius: 24),
                BoxShadow(
                  color: const Color(0xFF0A1224).withOpacity(0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'LilitaOne',
                fontSize: 14,
                letterSpacing: 0.5,
                color: Colors.white,
                shadows: [
                  Shadow(offset: const Offset(-1, -1), color: const Color(0xFF0A1224)),
                  Shadow(offset: const Offset(1, -1), color: const Color(0xFF0A1224)),
                  Shadow(offset: const Offset(-1, 1), color: const Color(0xFF0A1224)),
                  Shadow(offset: const Offset(1, 1), color: const Color(0xFF0A1224)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
Secondary Button (subtle)Dartclass GameSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const GameSecondaryButton({Key? key, required this.label, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4AC4D9).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.5), width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: 14,
            letterSpacing: 0.5,
            color: Color(0xFFBFF0FA),
          ),
        ),
      ),
    );
  }
}
Icon Button (40×40 square)DartWidget buildIconButton(IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.3), width: 2),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFFBFF0FA)),
    ),
  );
}
Chip / TagDartclass GameChip extends StatelessWidget {
  final String label;
  
  const GameChip({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4AC4D9).withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.55), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'LilitaOne',
          fontSize: 10,
          letterSpacing: 1.2,
          color: Color(0xFFEAFBFF),
        ),
      ),
    );
  }
}
Input (search / text)Dartclass GameTextField extends StatelessWidget {
  final String hintText;
  final IconData? prefixIcon;

  const GameTextField({Key? key, required this.hintText, this.prefixIcon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050810),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.25)),
      ),
      child: TextField(
        style: const TextStyle(fontFamily: 'Fredoka', color: Color(0xFFEAFBFF), fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: const Color(0xFFBFF0FA).withOpacity(0.3), fontSize: 14),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF4AC4D9)) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
Modal / Overlay Router DialogDartvoid showGameModal(BuildContext context, Widget content) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xFF050810).withOpacity(0.85),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            maxWidth: 800,
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1224),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.40), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4AC4D9).withOpacity(0.35), blurRadius: 60),
              ],
            ),
            child: content,
          ),
        ),
      );
    },
  );
}
Empty StateDartclass GameEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const GameEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF7FE3F5).withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontFamily: 'LilitaOne', fontSize: 18, color: Color(0xFFBFF0FA), letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontFamily: 'Fredoka', fontSize: 14, color: Color(0x80BFF0FA)),
          ),
        ],
      ),
    );
  }
}
Info Banner (tip / rule)Dartclass GameInfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const GameInfoBanner({Key? key, required this.text, this.icon = LucideIcons.shield}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4AC4D9).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4AC4D9).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7FE3F5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Fredoka', fontSize: 12, color: Color(0xCCBFF0FA), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
6. EffectsCyan Glow HaloDartBoxDecoration(
  boxShadow: [
    BoxShadow(
      color: Color(0xFF4AC4D9).withOpacity(0.5),
      blurRadius: 20.0,
    ),
  ],
)
Magenta Glow (active / PVP)DartBoxDecoration(
  boxShadow: [
    BoxShadow(
      color: Color(0xFFE85AA8).withOpacity(0.45),
      blurRadius: 24.0,
    ),
  ],
)
Pulse Animation ControllerWrap widgets in standard animation states or custom controllers using AnimationController:Dartclass GamePulseEffect extends StatefulWidget {
  final Widget child;
  const GamePulseEffect({Key? key, required this.child}) : super(key: key);

  @override
  State<GamePulseEffect> createState() => _GamePulseEffectState();
}

class _GamePulseEffectState extends State<GamePulseEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.55, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(opacity: _opacityAnimation, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
Pet Sprite Bob AnimationDartclass GameBobEffect extends StatefulWidget {
  final Widget child;
  const GameBobEffect({Key? key, required this.child}) : super(key: key);

  @override
  State<GameBobEffect> createState() => _GameBobEffectState();
}

class _GameBobEffectState extends State<GameBobEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _translationAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translationAnimation,
      builder: (context, child) => Transform.translate(offset: Offset(0, _translationAnimation.value), child: child),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
7. Class Colors (for pet-related UI)Always look up values using a dedicated map setup tracking data structures.Dartclass PetClassStyle {
  final Color accent;
  final Color tagBg;
  final Color tagBorder;

  const PetClassStyle({required this.accent, required this.tagBg, required this.tagBorder});
}

class PetClasses {
  static final Map<String, PetClassStyle> styles = {
    'BUG': const PetClassStyle(
      accent: Color(0xFFE85AA8),
      tagBg: Color(0x2EE85AA8),
      tagBorder: Color(0x8CE85AA8),
    ),
    'BEAST': const PetClassStyle(
      accent: Color(0xFFF0A040),
      tagBg: Color(0x2EF0A040),
      tagBorder: Color(0x8CF0A040),
    ),
    'REPTILE': const PetClassStyle(
      accent: Color(0xFF4ADC7A),
      tagBg: Color(0x2E4ADC7A),
      tagBorder: Color(0x8C4ADC7A),
    ),
    'AQUATIC': const PetClassStyle(
      accent: Color(0xFF4AC4D9),
      tagBg: Color(0x2E4AC4D9),
      tagBorder: Color(0x8C4AC4D9),
    ),
    'PLANT': const PetClassStyle(
      accent: Color(0xFFA8D94A),
      tagBg: Color(0x2EA8D94A),
      tagBorder: Color(0x8CA8D94A),
    ),
    'BIRD': const PetClassStyle(
      accent: Color(0xFFF586A0),
      tagBg: Color(0x2EF586A0),
      tagBorder: Color(0x8CF586A0),
    ),
  };
}
8. IconsUse lucide_icons package properties exclusively.ContextIcon Token MappingBack / navLucideIcons.arrowLeftPets / rosterLucideIcons.pawPrintTeamsLucideIcons.usersHomeLucideIcons.homePVP / battleLucideIcons.swords, LucideIcons.zapSettingsLucideIcons.settingsInventory / AssetsLucideIcons.packageStars / rarityLucideIcons.starSearchLucideIcons.searchFilter / sortLucideIcons.arrowUpDownConfirmLucideIcons.checkCancel / closeLucideIcons.xEditLucideIcons.pencilDeleteLucideIcons.trash2InfoLucideIcons.info, LucideIcons.shieldDefault configuration sizes: 16.0 on buttons, 12.0 on layout tags, 48.0 inside empty view state definitions.9. Wiring Views into Main App ArchitectureRegister your screens inside a root enum value or navigation provider configuration:Dartenum GameView { home, match, pets, teams, myNewView }

// Core App View Switcher implementation inside stateful parent parameters
Widget buildActiveView(GameView currentView) {
  switch (currentView) {
    case GameView.home:
      return const GameHomePage();
    case GameView.myNewView:
      return MyNewPage(onBack: () => updateView(GameView.home));
    default:
      return const GameHomePage();
  }
}
10. Do's and Don'ts✅ DoUse ONLY the colors and fonts configured inside your theme structures.Wrap pages explicitly inside the 16:9 canvas model constraint system using AspectRatio.Outline every chunky display label using custom Shadow collections.Utilize transition configurations for hovering and asset state modifications.Reference color tokens from the global map matrices when resolving class aesthetics.❌ Don'tDon't inject custom colors outside your unified game styling dictionary.Don't construct continuous rainbow gradients or multi-hue interpolation paths.Don't introduce material layout defaults or native system type variations.Don't structure continuous strings using the display font variant; limit its use strictly to headings and titles.Don't allow main context wrappers to extend over or outside the fixed aspect canvas workspace boundaries.Don't fetch icons using random custom SVG imports; rely strictly on definitions provided by LucideIcons.