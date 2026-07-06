import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../application/auth_providers.dart';

enum _AuthMode { signIn, signUp, forgot }

/// MVP authentication screen: sign in / sign up / forgot password.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l10n) => switch (_mode) {
        _AuthMode.signIn => l10n.authSignInTab,
        _AuthMode.signUp => l10n.authSignUpTab,
        _AuthMode.forgot => l10n.authForgotPassword,
      };

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.authEmailRequired;
    // Simple, permissive email shape check.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return l10n.authEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations l10n) {
    final v = value ?? '';
    if (v.isEmpty) return l10n.authPasswordRequired;
    if (v.length < 6) return l10n.authPasswordTooShort;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final repo = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    final password = _password.text;
    final name = _displayName.text.trim();

    final Result<void> result = switch (_mode) {
      _AuthMode.signIn => await repo.signIn(email: email, password: password),
      _AuthMode.signUp => await repo.signUp(
          email: email,
          password: password,
          displayName: name.isEmpty ? null : name,
        ),
      _AuthMode.forgot => await repo.sendPasswordReset(email),
    };

    if (!mounted) return;
    setState(() => _submitting = false);
    final l10n = AppLocalizations.of(context);
    result.when(
      ok: (_) => _onSuccess(l10n),
      err: (failure) => _showSnack(_failureMessage(l10n, failure)),
    );
  }

  void _onSuccess(AppLocalizations l10n) {
    if (_mode == _AuthMode.forgot) {
      _showSnack(l10n.authResetEmailSent);
      setState(() => _mode = _AuthMode.signIn);
      return;
    }
    // Signed in / signed up: return to where the user came from.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  String _failureMessage(AppLocalizations l10n, Failure failure) {
    if (failure is BackendUnavailableFailure) {
      return l10n.authBackendNotConfigured;
    }
    if (failure is ValidationFailure || failure is UnauthorizedFailure) {
      return failure.message.isNotEmpty ? failure.message : l10n.authGenericError;
    }
    return l10n.authGenericError;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setMode(_AuthMode mode) {
    setState(() => _mode = mode);
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backendConfigured = ref.watch(backendConfiguredProvider);
    final showPassword = _mode != _AuthMode.forgot;
    final showDisplayName = _mode == _AuthMode.signUp;

    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              if (!backendConfigured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _InfoBanner(message: l10n.authBackendNotConfigured),
                ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.authEmailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) => _validateEmail(v, l10n),
              ),
              if (showDisplayName) ...<Widget>[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayName,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.authDisplayNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
              ],
              if (showPassword) ...<Widget>[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.authPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) => _validatePassword(v, l10n),
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(switch (_mode) {
                        _AuthMode.signIn => l10n.authSignInButton,
                        _AuthMode.signUp => l10n.authSignUpButton,
                        _AuthMode.forgot => l10n.authResetButton,
                      }),
              ),
              const SizedBox(height: 8),
              ..._modeLinks(l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _modeLinks(AppLocalizations l10n) {
    switch (_mode) {
      case _AuthMode.signIn:
        return <Widget>[
          TextButton(
            onPressed: _submitting ? null : () => _setMode(_AuthMode.signUp),
            child: Text(l10n.authSignUpTab),
          ),
          TextButton(
            onPressed: _submitting ? null : () => _setMode(_AuthMode.forgot),
            child: Text(l10n.authForgotPassword),
          ),
        ];
      case _AuthMode.signUp:
        return <Widget>[
          TextButton(
            onPressed: _submitting ? null : () => _setMode(_AuthMode.signIn),
            child: Text(l10n.authBackToSignIn),
          ),
        ];
      case _AuthMode.forgot:
        return <Widget>[
          TextButton(
            onPressed: _submitting ? null : () => _setMode(_AuthMode.signIn),
            child: Text(l10n.authBackToSignIn),
          ),
        ];
    }
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
