part of '../main.dart';

enum _CreateGroupMenuAction { pickAvatar, removeAvatar, addMembers }

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController nameController = TextEditingController();
  final List<ContactItem> selectedMembers = [];
  final Set<int> selectedRemovalIds = <int>{};
  bool isSubmitting = false;
  bool isPickingAvatar = false;
  String? avatarPath;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  GroupMember? get _ownerPreviewMember {
    final user = widget.controller.user;
    if (user == null) {
      return null;
    }
    return GroupMember(
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatarUrl,
      isOwner: true,
    );
  }

  Future<void> _openAddMember() async {
    if (isSubmitting) {
      return;
    }
    final selectedContacts = await showGroupContactPickerSheet(
      context: context,
      contacts: widget.controller.contacts,
      title: 'Добавить участников',
      confirmLabel: 'Добавить выбранных',
      excludedUserIds: selectedMembers.map((member) => member.userId).toSet(),
    );
    if (!mounted || selectedContacts == null || selectedContacts.isEmpty) {
      return;
    }
    setState(() {
      final existingIds = selectedMembers
          .map((member) => member.userId)
          .toSet();
      for (final contact in selectedContacts) {
        if (existingIds.add(contact.userId)) {
          selectedMembers.add(contact);
        }
      }
    });
  }

  void _toggleMemberRemovalSelection(int userId) {
    if (isSubmitting) {
      return;
    }
    setState(() {
      if (!selectedRemovalIds.add(userId)) {
        selectedRemovalIds.remove(userId);
      }
    });
  }

  void _removeSelectedMembers() {
    if (isSubmitting || selectedRemovalIds.isEmpty) {
      return;
    }
    setState(() {
      selectedMembers.removeWhere(
        (member) => selectedRemovalIds.contains(member.userId),
      );
      selectedRemovalIds.clear();
    });
  }

  Future<void> _pickAvatar() async {
    if (isPickingAvatar || isSubmitting) {
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
      setState(() {
        avatarPath = path;
      });
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

  void _removeAvatar() {
    if (isSubmitting || isPickingAvatar || avatarPath == null) {
      return;
    }
    setState(() {
      avatarPath = null;
    });
  }

  Future<void> _handleMenuAction(_CreateGroupMenuAction action) async {
    switch (action) {
      case _CreateGroupMenuAction.pickAvatar:
        await _pickAvatar();
      case _CreateGroupMenuAction.removeAvatar:
        _removeAvatar();
      case _CreateGroupMenuAction.addMembers:
        await _openAddMember();
    }
  }

  Future<void> _submit() async {
    if (isSubmitting) {
      return;
    }
    if (nameController.text.trim().isEmpty) {
      showError(
        context,
        Exception('Введите название группы'),
        fallbackMessage: 'Введите название группы',
      );
      return;
    }
    setState(() {
      isSubmitting = true;
    });
    try {
      final group = await widget.controller.createGroup(
        name: nameController.text,
        memberEmails: selectedMembers
            .map((member) => member.email)
            .toList(growable: false),
        avatarPath: avatarPath,
      );
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Группа создана');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatScreen(controller: widget.controller, initialContact: group),
        ),
      );
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
    final ownerMember = _ownerPreviewMember;
    final previewMembers = <GroupMember>[
      ...selectedMembers.map(
        (member) => GroupMember(
          id: member.userId,
          email: member.email,
          name: member.name,
          avatarUrl: member.avatarUrl,
          isOwner: false,
        ),
      ),
    ];
    if (ownerMember != null) {
      previewMembers.insert(0, ownerMember);
    }
    return Scaffold(
      appBar: AppBar(
        leading: buildPlainBackButton(context),
        title: const Text('Создать группу'),
        actions: [
          PopupMenuButton<_CreateGroupMenuAction>(
            tooltip: 'Меню',
            enabled: !isSubmitting && !isPickingAvatar,
            onSelected: (action) => unawaited(_handleMenuAction(action)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CreateGroupMenuAction.pickAvatar,
                child: Row(
                  children: [
                    Icon(Icons.add_a_photo_rounded, color: appPrimaryColor),
                    SizedBox(width: 12),
                    Text('Сменить аватар'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _CreateGroupMenuAction.removeAvatar,
                child: Row(
                  children: [
                    Icon(Icons.no_photography_rounded, color: appPrimaryColor),
                    SizedBox(width: 12),
                    Text('Убрать аватар'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _CreateGroupMenuAction.addMembers,
                child: Row(
                  children: [
                    Icon(Icons.group_add_rounded, color: appPrimaryColor),
                    SizedBox(width: 12),
                    Text('Добавить участников'),
                  ],
                ),
              ),
            ],
          ),
        ],
        flexibleSpace: buildGradientAppBarBackground(buildSettingsGradient()),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: buildSettingsGradient()),
        child: SafeArea(
          child: AppScreenSurface(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppSectionCard(
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
                                  name: nameController.text.trim().isEmpty
                                      ? 'Группа'
                                      : nameController.text.trim(),
                                  imageUrl: avatarPath == null
                                      ? null
                                      : Uri.file(avatarPath!).toString(),
                                  radius: 42,
                                  backgroundColor: const Color(0xFF67B8D8),
                                  fallbackIcon: Icons.groups_rounded,
                                  useNameGradient: false,
                                ),
                                if (isPickingAvatar)
                                  const SizedBox(
                                    width: 84,
                                    height: 84,
                                    child: Center(
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
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Название группы',
                            prefixIcon: Icon(Icons.group_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Text('Создать группу'),
                        ),
                      ],
                    ),
                  ),
                ),
                GroupMembersSection(
                  members: previewMembers,
                  selectedRemovalIds: selectedRemovalIds,
                  showRemoveAction: ownerMember != null,
                  removeActionLabel: 'Удалить выбранных',
                  onRemoveSelected: selectedRemovalIds.isEmpty || isSubmitting
                      ? null
                      : _removeSelectedMembers,
                  canRemoveMember: (member) => !member.isOwner && !isSubmitting,
                  onToggleMember: (member) =>
                      _toggleMemberRemovalSelection(member.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
