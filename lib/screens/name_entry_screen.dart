part of '../main.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController nameController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
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
      await widget.controller.completeRegistration(nameController.text);
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
            title: 'Ваше имя',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person_rounded),
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
                      : const Text('Продолжить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
