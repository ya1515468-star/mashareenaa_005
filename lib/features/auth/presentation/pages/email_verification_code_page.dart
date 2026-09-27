import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../gamification/domain/usecases/apply_referral_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/premium_auth_scaffold.dart';
import '../widgets/premium/premium_button.dart';

class EmailVerificationCodePage extends ConsumerStatefulWidget {
  final String uid;
  final String email;
  final String? referralUsername;

  const EmailVerificationCodePage({
    super.key,
    required this.uid,
    required this.email,
    this.referralUsername,
  });

  @override
  ConsumerState<EmailVerificationCodePage> createState() =>
      _EmailVerificationCodePageState();
}

class _EmailVerificationCodePageState
    extends ConsumerState<EmailVerificationCodePage> {
  final _codeController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  bool _loading = false;
  String? _error;
  bool _canResend = true;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.getUser();
      final confirmedAt = response.user?.emailConfirmedAt;
      if (confirmedAt != null) {
        if (widget.referralUsername != null &&
            widget.referralUsername!.isNotEmpty) {
          await sl<ApplyReferralUseCase>().call(
            referrerUsername: widget.referralUsername!,
            newMemberUid: widget.uid,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تأكيد بريدك الإلكتروني بنجاح! ✓')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      setState(() {
        _loading = false;
        _error = 'لم يتم تأكيد البريد بعد. افتح رسالة Supabase ثم عُد للتطبيق.';
      });
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'تعذّر التحقق من حالة البريد: $e';
      });
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (!mounted) return;
      setState(() {
        _canResend = false;
        _secondsLeft = 60;
      });
      while (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() => _secondsLeft--);
      }
      if (mounted) setState(() => _canResend = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إعادة إرسال رسالة التأكيد.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
        _secondsLeft = 0;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
        _secondsLeft = 0;
        _error = 'تعذّرت إعادة الإرسال: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return PremiumAuthScaffold(
      child: ShakeWidget(
        key: _shakeKey,
        child: SingleChildScrollView(
          child: StaggeredEntrance(
            children: [
              Icon(Icons.mark_email_read_outlined, size: 48, color: p.accent),
              const SizedBox(height: 12),
              Text(
                'تأكيد بريدك الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'تحقق من رسالة تأكيد Supabase المرسلة إلى:\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Text(
                'بعد الضغط على رابط التأكيد في البريد، اضغط «تحققت من البريد» أدناه.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: p.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              PremiumButton(
                  label: 'تحققت من البريد',
                  isLoading: _loading,
                  onPressed: _verify),
              const SizedBox(height: 16),
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resend,
                        child: Text('إعادة إرسال رسالة التأكيد',
                            style: TextStyle(color: p.accent)),
                      )
                    : Text(
                        'إعادة الإرسال في $_secondsLeft ثانية',
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعتمد عملية إنشاء الحساب على تأكيد البريد الرسمي في Supabase. إذا لم تصل الرسالة، افحص البريد غير المرغوب أو أعد الإرسال.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
