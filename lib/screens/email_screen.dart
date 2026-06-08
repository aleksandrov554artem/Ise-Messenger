part of '../main.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  late final TextEditingController emailController;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(
      text: widget.controller.pendingEmail,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
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
      await widget.controller.requestCode(emailController.text);
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

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AuthCard(
            title: 'Вход по почте',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Почта',
                    prefixIcon: Icon(Icons.mail_rounded),
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
                      : const Text('Получить код'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
