import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/register_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _onBack(context, state.step),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            children: [
              _StepIndicator(step: state.step),
              const SizedBox(height: AppDimensions.lg),
              Expanded(child: _buildStepBody(state.step)),
            ],
          ),
        ),
      ),
    );
  }

  void _onBack(BuildContext context, RegisterStep step) {
    final notifier = ref.read(registerProvider.notifier);
    switch (step) {
      case RegisterStep.search:
        context.go('/login');
        break;
      case RegisterStep.verifyInfo:
        notifier.goToStep(RegisterStep.search);
        break;
      case RegisterStep.otp:
        notifier.goToStep(RegisterStep.verifyInfo);
        break;
      case RegisterStep.password:
        notifier.goToStep(RegisterStep.otp);
        break;
      case RegisterStep.done:
        context.go('/login');
        break;
    }
  }

  Widget _buildStepBody(RegisterStep step) {
    switch (step) {
      case RegisterStep.search:
        return const _SearchEmployeeStep();
      case RegisterStep.verifyInfo:
        return const _VerifyInfoStep();
      case RegisterStep.otp:
        return const _OtpStep();
      case RegisterStep.password:
        return const _PasswordStep();
      case RegisterStep.done:
        return const _DoneStep();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final RegisterStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final index = RegisterStep.values.indexOf(step);
    const total = 4;
    final clamped = index >= total ? total : index;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= clamped;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.neutral100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Step 1: Search Employee ───────────────────────────────────────────
class _SearchEmployeeStep extends ConsumerStatefulWidget {
  const _SearchEmployeeStep();

  @override
  ConsumerState<_SearchEmployeeStep> createState() =>
      _SearchEmployeeStepState();
}

class _SearchEmployeeStepState extends ConsumerState<_SearchEmployeeStep> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = ref.read(registerProvider);
    if (s.lastSearchedFirst != null) _firstName.text = s.lastSearchedFirst!;
    if (s.lastSearchedLast != null) _lastName.text = s.lastSearchedLast!;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(registerProvider.notifier).searchEmployee(
          firstname: _firstName.text.trim(),
          lastname: _lastName.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);
    final notifier = ref.read(registerProvider.notifier);
    final matched = state.matchedEmployee;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Find your record',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your registered first and last name to look up your employee profile.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'First Name',
              hint: 'e.g. Juan',
              controller: _firstName,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'First name is required' : null,
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'Last Name',
              hint: 'e.g. Dela Cruz',
              controller: _lastName,
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.search,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
            ),
            const SizedBox(height: AppDimensions.md),
            AppButton(
              label: state.isLoading ? 'Searching…' : 'Search',
              icon: Icons.search,
              isLoading: state.isLoading,
              onPressed: state.isLoading ? null : _search,
            ),
            if (state.error != null) ...[
              const SizedBox(height: AppDimensions.md),
              _ErrorBanner(message: state.error!),
            ],
            if (state.lastNotFoundQuery != null && matched == null) ...[
              const SizedBox(height: AppDimensions.md),
              _ErrorBanner(
                message:
                    'No employee found matching "${state.lastNotFoundQuery}". Please double-check your name and try again.',
              ),
            ],
            if (matched != null) ...[
              const SizedBox(height: AppDimensions.lg),
              const Text(
                'MATCHING RECORD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              _EmployeeCard(
                employee: matched,
                onTap: () => notifier.selectEmployee(matched),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeRecord employee;
  final VoidCallback onTap;
  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                employee.firstName.isNotEmpty
                    ? employee.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${employee.employeeId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Verify Info ───────────────────────────────────────────────
class _VerifyInfoStep extends ConsumerStatefulWidget {
  const _VerifyInfoStep();

  @override
  ConsumerState<_VerifyInfoStep> createState() => _VerifyInfoStepState();
}

class _VerifyInfoStepState extends ConsumerState<_VerifyInfoStep> {
  bool _sending = false;

  Future<void> _continue() async {
    setState(() => _sending = true);
    final notifier = ref.read(registerProvider.notifier);
    await notifier.sendOtp(advanceStep: true);
    if (!mounted) return;
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final emp = ref.watch(registerProvider).selectedEmployee;
    if (emp == null) {
      return const Center(child: Text('No employee selected'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirm your details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Make sure this is you. Your contact number is partially hidden for your security.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.md),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Employee ID',
                value: emp.employeeId,
              ),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: emp.fullName,
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Contact Number',
                value: emp.maskedContactNumber,
                trailing: const _SecuredBadge(),
                isLast: true,
              ),
            ],
          ),
        ),
        const Spacer(),
        AppButton(
          label: _sending ? 'Sending OTP…' : 'Send OTP',
          icon: Icons.sms_outlined,
          isLoading: _sending,
          onPressed: _sending ? null : _continue,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool isLast;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SecuredBadge extends StatelessWidget {
  const _SecuredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 11, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Hashed',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: OTP ───────────────────────────────────────────────────────
class _OtpStep extends ConsumerStatefulWidget {
  const _OtpStep();

  @override
  ConsumerState<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends ConsumerState<_OtpStep> {
  final _otpController = TextEditingController();
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _resending = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRemaining();
      _startTicker();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _refreshRemaining();
    });
  }

  void _refreshRemaining() {
    final remaining =
        ref.read(registerProvider.notifier).remainingResendCooldown();
    if (remaining != _remaining) {
      setState(() => _remaining = remaining);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    final code = await ref.read(registerProvider.notifier).sendOtp();
    if (!mounted) return;
    setState(() => _resending = false);
    if (code != null) {
      _otpController.clear();
      _refreshRemaining();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A new OTP has been sent. (Demo code: $code)'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit OTP.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _verifying = true);
    final ok = await ref
        .read(registerProvider.notifier)
        .verifyOtp(_otpController.text);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) {
      final err = ref.read(registerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);
    final emp = state.selectedEmployee;
    final username = emp?.suggestedUsername ?? '';
    final canResend = _remaining == Duration.zero;
    final demoCode = state.generatedOtp;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Verify your identity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We sent a 6-digit OTP to ${emp?.maskedContactNumber ?? ''}.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR USERNAME',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (demoCode != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo OTP: $demoCode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.lg),
          AppTextField(
            label: 'Enter OTP',
            hint: '••••••',
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            prefixIcon: Icons.password_outlined,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppDimensions.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _resending
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Sending another OTP…',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : canResend
                    ? GestureDetector(
                        onTap: _resend,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Text(
                        'You can request a new OTP in ${_format(_remaining)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
          ),
          const SizedBox(height: AppDimensions.xl),
          AppButton(
            label: 'Verify OTP',
            icon: Icons.verified_outlined,
            isLoading: _verifying,
            onPressed: _verifying ? null : _verify,
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Password ──────────────────────────────────────────────────
class _PasswordStep extends ConsumerStatefulWidget {
  const _PasswordStep();

  @override
  ConsumerState<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends ConsumerState<_PasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide1 = true;
  bool _hide2 = true;
  bool _submitting = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await ref.read(registerProvider.notifier).completeRegistration(
          password: _password.text,
          confirmPassword: _confirm.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      await _showSuccessAlert();
    } else {
      final err = ref.read(registerProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showSuccessAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 10),
            Text('Account Created'),
          ],
        ),
        content: const Text(
          'Your account has been created successfully. You can now sign in with your username and password.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Proceed to Login'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    ref.read(registerProvider.notifier).reset();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create your password',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a strong password with at least 8 characters.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.lg),
            AppTextField(
              label: 'Password',
              hint: '••••••••',
              controller: _password,
              obscureText: _hide1,
              prefixIcon: Icons.lock_outline,
              suffix: GestureDetector(
                onTap: () => setState(() => _hide1 = !_hide1),
                child: Icon(
                  _hide1
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'At least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              label: 'Confirm Password',
              hint: '••••••••',
              controller: _confirm,
              obscureText: _hide2,
              prefixIcon: Icons.lock_outline,
              suffix: GestureDetector(
                onTap: () => setState(() => _hide2 = !_hide2),
                child: Icon(
                  _hide2
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm password';
                if (v != _password.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.xl),
            AppButton(
              label: 'Create Account',
              icon: Icons.person_add_alt_1,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 5: Done (fallback, normally we redirect after dialog) ────────
class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: AppDimensions.md),
          const Text(
            'Account Created',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          AppButton(
            label: 'Go to Login',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
