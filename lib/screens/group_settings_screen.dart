part of '../main.dart';

enum _GroupSettingsMenuAction { pickAvatar, removeAvatar, addMembers }

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.controller,
    required this.initialGroup,
  });

  final MessengerController controller;
  final ContactItem initialGroup;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late final TextEditingController nameController;
  GroupDetails? details;
  final Set<int> selectedRemovalIds = <int>{};
  bool isLoading = true;
  bool isSavingName = false;
  bool isPickingAvatar = false;
  bool isRemovingAvatar = false;
  bool isAddingMember = false;
  bool isRemovingMembers = false;

  ContactItem get group =>
      widget.controller.contactById(widget.initialGroup.userId) ??
      widget.initialGroup;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: sanitizeDisplayText(
        widget.initialGroup.name,
        preserveLineBreaks: false,
      ),
    );
    unawaited(_loadDetails());
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      isLoading = true;
    });
    try {
      final loadedDetails = await widget.controller.loadGroupDetails(
        group.userId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        details = loadedDetails;
        nameController.text = sanitizeDisplayText(
          loadedDetails.group.name,
          preserveLineBreaks: false,
        );
        selectedRemovalIds.removeWhere(
          (userId) =>
              !loadedDetails.members.any((member) => member.id == userId),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (isSavingName) {
      return;
    }
    setState(() {
      isSavingName = true;
    });
    try {
      await widget.controller.updateGroupName(
        group.userId,
        nameController.text,
      );
      await _loadDetails();
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
          isSavingName = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (isPickingAvatar || isRemovingAvatar || isSavingName || isLoading) {
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
      await widget.controller.setGroupAvatar(group.userId, path);
      await _loadDetails();
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
    if (isPickingAvatar || isRemovingAvatar || isLoading) {
      return;
    }
    setState(() {
      isRemovingAvatar = true;
    });
    try {
      await widget.controller.clearGroupAvatar(group.userId);
      await _loadDetails();
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

  Future<void> _openAddMember() async {
    if (isAddingMember || isLoading) {
      return;
    }
    final selectedContacts = await showGroupContactPickerSheet(
      context: context,
      contacts: widget.controller.contacts,
      title: 'Добавить участников',
      confirmLabel: 'Добавить выбранных',
      excludedUserIds:
          details?.members.map((member) => member.id).toSet() ?? <int>{},
    );
    if (!mounted || selectedContacts == null || selectedContacts.isEmpty) {
      return;
    }
    setState(() {
      isAddingMember = true;
    });
    try {
      await widget.controller.addGroupMembersByEmail(
        group.userId,
        selectedContacts
            .map((contact) => contact.email)
            .toList(growable: false),
      );
      await _loadDetails();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isAddingMember = false;
        });
      }
    }
  }

  Future<void> _removeSelectedMembers() async {
    if (isRemovingMembers || selectedRemovalIds.isEmpty) {
      return;
    }
    setState(() {
      isRemovingMembers = true;
    });
    try {
      await widget.controller.removeGroupMembers(
        group.userId,
        selectedRemovalIds.toList(growable: false),
      );
      selectedRemovalIds.clear();
      await _loadDetails();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          isRemovingMembers = false;
        });
      }
    }
  }

  void _toggleMemberRemovalSelection(int memberId) {
    setState(() {
      if (!selectedRemovalIds.add(memberId)) {
        selectedRemovalIds.remove(memberId);
      }
    });
  }

  Future<void> _handleMenuAction(_GroupSettingsMenuAction action) async {
    switch (action) {
      case _GroupSettingsMenuAction.pickAvatar:
        await _pickAvatar();
      case _GroupSettingsMenuAction.removeAvatar:
        await _removeAvatar();
      case _GroupSettingsMenuAction.addMembers:
        await _openAddMember();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDetails = details;
    final displayedGroup = currentDetails?.group ?? group;
    final displayedGroupName = sanitizeDisplayText(
      displayedGroup.name,
      preserveLineBreaks: false,
    );
    final members = currentDetails?.members ?? const <GroupMember>[];
    final isOwner = widget.controller.user?.id == displayedGroup.ownerId;
    final menuEnabled =
        isOwner &&
        !isLoading &&
        !isPickingAvatar &&
        !isRemovingAvatar &&
        !isAddingMember &&
        !isSavingName;
    return Scaffold(
      appBar: AppBar(
        leading: buildPlainBackButton(context),
        title: const Text('Настройки группы'),
        actions: [
          if (isOwner)
            PopupMenuButton<_GroupSettingsMenuAction>(
              tooltip: 'Меню',
              enabled: menuEnabled,
              onSelected: (action) => unawaited(_handleMenuAction(action)),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _GroupSettingsMenuAction.pickAvatar,
                  child: Row(
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: appPrimaryColor),
                      SizedBox(width: 12),
                      Text('Сменить аватар'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _GroupSettingsMenuAction.removeAvatar,
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
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _GroupSettingsMenuAction.addMembers,
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
            child: isLoading && currentDetails == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
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
                                            ? displayedGroupName
                                            : nameController.text.trim(),
                                        imageUrl: displayedGroup.avatarUrl,
                                        radius: 42,
                                        backgroundColor: const Color(
                                          0xFF67B8D8,
                                        ),
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
                                readOnly: !isOwner,
                                textInputAction: TextInputAction.done,
                                onSubmitted: isOwner
                                    ? (_) => _saveName()
                                    : null,
                                onChanged: isOwner
                                    ? (_) => setState(() {})
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Название группы',
                                  prefixIcon: Icon(Icons.group_rounded),
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(height: 12),
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
                                      : const Text('Сохранить имя'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      GroupMembersSection(
                        members: members,
                        selectedRemovalIds: selectedRemovalIds,
                        showRemoveAction: isOwner,
                        removeActionLabel: isRemovingMembers
                            ? 'Удаление...'
                            : 'Удалить выбранных',
                        onRemoveSelected:
                            selectedRemovalIds.isEmpty || isRemovingMembers
                            ? null
                            : _removeSelectedMembers,
                        canRemoveMember: (member) => isOwner && !member.isOwner,
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
