part of '../main.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final TextEditingController codeController = TextEditingController();
  bool isSubmitting = false;
  bool isResending = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isSubmitting) {
      return;
    }
    setState(() {
      isSubmitting = true;
    });
    try {
      await widget.controller.verifyCode(codeController.text);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (isSubmitting || isResending) {
      return;
    }
    setState(() {
      isResending = true;
    });
    try {
      await widget.controller.requestCode(widget.controller.pendingEmail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AuthCard(
            title: 'Код подтверждения',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Код',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Подтвердить'),
                ),
                const SizedBox(height: 10),
                Align(
                  child: TextButton(
                    onPressed: isSubmitting || isResending ? null : _resendCode,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isResending ? 'Отправка...' : 'Отправить код еще раз',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  child: TextButton(
                    onPressed: isSubmitting || isResending
                        ? null
                        : widget.controller.goBackToEmail,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Сменить почту'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
