part of '../main.dart';

enum _SettingsMenuAction { pickAvatar, removeAvatar, logout, deleteAccount }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController nameController;
  late final Listenable _screenListenable;
  bool isSavingName = false;
  bool isPickingAvatar = false;
  bool isRemovingAvatar = false;
  bool isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _screenListenable = widget.controller.sessionListenable;
    nameController = TextEditingController(
      text: widget.controller.user?.name ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (isSavingName) {
      return;
    }
    setState(() {
      isSavingName = true;
    });
    try {
      await widget.controller.updateProfileName(nameController.text);
      if (!mounted) {
        return;
      }
      nameController.text = widget.controller.user?.name ?? nameController.text;
      showSuccessToast(context, 'Настройки сохранены');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isSavingName = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (isPickingAvatar ||
        isRemovingAvatar ||
        isDeletingAccount ||
        isSavingName) {
      return;
    }
    setState(() {
      isPickingAvatar = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final path = picked.files.single.path;
      if (path == null || path.isEmpty) {
        throw Exception('Не удалось открыть изображение');
      }
      await widget.controller.setProfileAvatar(path);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Настройки сохранены');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isPickingAvatar = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    if (isPickingAvatar ||
        isRemovingAvatar ||
        isDeletingAccount ||
        isSavingName) {
      return;
    }
    setState(() {
      isRemovingAvatar = true;
    });
    try {
      await widget.controller.clearProfileAvatar();
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Настройки сохранены');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isRemovingAvatar = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await widget.controller.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount() async {
    if (isDeletingAccount) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить аккаунт?'),
          content: const Text('Все данные будут удалены.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB84040),
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      isDeletingAccount = true;
    });
    try {
      await widget.controller.deleteAccount();
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Аккаунт удален');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> _handleMenuAction(_SettingsMenuAction action) async {
    switch (action) {
      case _SettingsMenuAction.pickAvatar:
        await _pickAvatar();
      case _SettingsMenuAction.removeAvatar:
        await _removeAvatar();
      case _SettingsMenuAction.logout:
        await _logout();
      case _SettingsMenuAction.deleteAccount:
        await _deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final user = widget.controller.user;
        final previewName = nameController.text.trim().isEmpty
            ? ((user?.name.trim().isNotEmpty ?? false)
                  ? user!.name.trim()
                  : 'Профиль')
            : nameController.text.trim();
        return Scaffold(
          appBar: AppBar(
            leading: buildPlainBackButton(context),
            title: const Text('Настройки'),
            actions: [
              PopupMenuButton<_SettingsMenuAction>(
                tooltip: 'Меню',
                enabled:
                    !isPickingAvatar &&
                    !isRemovingAvatar &&
                    !isDeletingAccount &&
                    !isSavingName,
                onSelected: (action) => unawaited(_handleMenuAction(action)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _SettingsMenuAction.pickAvatar,
                    child: Row(
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: appPrimaryColor),
                        SizedBox(width: 12),
                        Text('Сменить аватар'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _SettingsMenuAction.removeAvatar,
                    child: Row(
                      children: [
                        Icon(
                          Icons.no_photography_rounded,
                          color: appPrimaryColor,
                        ),
                        SizedBox(width: 12),
                        Text('Убрать аватар'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _SettingsMenuAction.logout,
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: appPrimaryColor),
                        SizedBox(width: 12),
                        Text('Выйти'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _SettingsMenuAction.deleteAccount,
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: appPrimaryColor),
                        SizedBox(width: 12),
                        Text('Удалить аккаунт'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: buildGradientAppBarBackground(
              buildSettingsGradient(),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(gradient: buildSettingsGradient()),
            child: SafeArea(
              child: AppScreenSurface(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    AppSectionCard(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ProfileAvatar(
                                    name: previewName,
                                    imageUrl: user?.avatarUrl,
                                    radius: 42,
                                  ),
                                  if (isPickingAvatar)
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.22,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: nameController,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _saveName(),
                            decoration: const InputDecoration(
                              labelText: 'Имя',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: isSavingName ? null : _saveName,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: isSavingName
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Text('Сохранить профиль'),
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
      },
    );
  }
}
