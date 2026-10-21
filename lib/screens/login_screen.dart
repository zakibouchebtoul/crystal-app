import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/countries.dart';
import '../services/auth_service.dart';
import '../widgets/doodle_background.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/primary_button.dart';
import 'account_type_screen.dart';
import 'home_screen.dart';

/// Phone-number sign-in. Existing accounts go straight home; new numbers
/// continue to choosing an account type.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  // Side-to-side shake of the field when the number is invalid.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _phone.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final digits = _phone.text;
    if (digits.length != Qatar.digits) {
      HapticFeedback.mediumImpact();
      setState(() => _error = 'Enter a valid ${Qatar.name} mobile number');
      _shake.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final phoneNumber = '${Qatar.dialCode}$digits';
    try {
      final registered = await authService.isRegistered(phoneNumber);
      if (!mounted) return;
      if (registered) {
        _goHome();
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountTypeScreen(phoneNumber: phoneNumber),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: DoodleBackground.login()),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, right: 4),
                          child: _SkipButton(onPressed: _goHome),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const FadeSlideIn(
                        child: _Title('Login or create an account'),
                      ),
                      const SizedBox(height: 20),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: AnimatedBuilder(
                          animation: _shake,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              math.sin(_shake.value * math.pi * 6) *
                                  10 *
                                  (1 - _shake.value),
                              0,
                            ),
                            child: child,
                          ),
                          child: _PhoneField(
                            controller: _phone,
                            hasError: _error != null,
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                            onSubmitted: (_) => _continue(),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _error == null
                            ? const SizedBox(height: 12)
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  10,
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: PrimaryButton(
                          label: 'Continue',
                          loading: _loading,
                          onPressed: _continue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 300),
                        child: _Disclaimer(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large one-line title; shrinks to fit narrow screens instead of wrapping.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F6FF),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Text(
            'Skip',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Theme.of(context).colorScheme.error
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 12, 0),
            child: Row(
              children: [
                _Flag(width: 27),
                SizedBox(width: 10),
                Text(
                  Qatar.dialCode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(Qatar.digits),
              ],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: const InputDecoration.collapsed(
                hintText: 'Mobile Number',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: AppColors.placeholder,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

/// Qatar's oval flag from the design.
class _Flag extends StatelessWidget {
  const _Flag({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(Qatar.flagAsset, width: width, height: width * 76 / 104);
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: AppColors.textMuted,
        ),
        children: [
          TextSpan(
            text:
                'We’ll send you one-time code via SMS or Whatsapp (if SMS '
                'fails) to verify your number. Message and Data rates may '
                'apply . By clicking “Continue”, you agree to our\n',
          ),
          TextSpan(
            text: 'Terms and Conditions',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
