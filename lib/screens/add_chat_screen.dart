part of '../main.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isSubmitting = false;

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
      await widget.controller.addContactByEmail(emailController.text);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат добавлен');
      Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(
        leading: buildPlainBackButton(context),
        title: const Text('Добавить чат'),
        flexibleSpace: buildGradientAppBarBackground(buildSettingsGradient()),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: buildSettingsGradient()),
        child: SafeArea(
          child: AppScreenSurface(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Почта чата',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text('Добавить'),
                      ),
                    ],
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
