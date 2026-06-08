part of '../main.dart';

Future<ContactItem?> showForwardMessageTargetSheet({
  required BuildContext context,
  required List<ContactItem> contacts,
  Set<int> excludedConversationIds = const <int>{},
}) {
  return showModalBottomSheet<ContactItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ForwardMessageTargetScreen(
          contacts: contacts,
          excludedConversationIds: excludedConversationIds,
        ),
      ),
    ),
  );
}

class ForwardMessageTargetScreen extends StatefulWidget {
  const ForwardMessageTargetScreen({
    super.key,
    required this.contacts,
    this.excludedConversationIds = const <int>{},
  });

  final List<ContactItem> contacts;
  final Set<int> excludedConversationIds;

  @override
  State<ForwardMessageTargetScreen> createState() =>
      _ForwardMessageTargetScreenState();
}

class _ForwardMessageTargetScreenState
    extends State<ForwardMessageTargetScreen> {
  late final List<ContactItem> availableContacts;
  int? selectedConversationId;

  @override
  void initState() {
    super.initState();
    availableContacts = widget.contacts
        .where(
          (contact) => !widget.excludedConversationIds.contains(contact.userId),
        )
        .toList(growable: false);
  }

  void _selectContact(ContactItem contact) {
    setState(() {
      if (selectedConversationId == contact.userId) {
        selectedConversationId = null;
      } else {
        selectedConversationId = contact.userId;
      }
    });
  }

  void _submit() {
    final selectedId = selectedConversationId;
    if (selectedId == null) {
      showError(context, Exception('Выберите чат для пересылки'));
      return;
    }
    final selectedContact = availableContacts.firstWhere(
      (contact) => contact.userId == selectedId,
    );
    Navigator.of(context).pop(selectedContact);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: buildSettingsGradient()),
        child: SafeArea(
          child: AppScreenSurface(
            child: Column(
              children: [
                Expanded(
                  child: availableContacts.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          children: const [
                            AppSectionCard(
                              child: Text(
                                'Нет доступных чатов для пересылки.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF5B6472),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
                          children: [
                            AppSectionCard(
                              margin: EdgeInsets.zero,
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: availableContacts
                                    .map((contact) {
                                      final isSelected =
                                          selectedConversationId ==
                                          contact.userId;
                                      return _ForwardMessageTargetTile(
                                        contact: contact,
                                        isSelected: isSelected,
                                        onTap: () => _selectContact(contact),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: AppSectionCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(14),
                    child: FilledButton(
                      onPressed: availableContacts.isEmpty ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Text('Переслать'),
                    ),
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

class _ContactStyleRow extends StatelessWidget {
  const _ContactStyleRow({
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    this.avatarBackgroundColor = appPrimaryColor,
    this.fallbackIcon = Icons.person_rounded,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final Color avatarBackgroundColor;
  final IconData fallbackIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(
                    name: name,
                    imageUrl: imageUrl,
                    radius: 28,
                    backgroundColor: avatarBackgroundColor,
                    fallbackIcon: fallbackIcon,
                    useNameGradient: fallbackIcon != Icons.groups_rounded,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ForwardMessageTargetTile extends StatelessWidget {
  const _ForwardMessageTargetTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  final ContactItem contact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contactName = sanitizeDisplayText(
      contact.name,
      preserveLineBreaks: false,
    );
    final subtitle = contact.isGroup
        ? formatGroupOnlineCountLabel(
            contact.onlineMemberCount,
            contact.memberCount,
          )
        : (contact.email.trim().isEmpty ? 'Личный чат' : contact.email.trim());
    return _ContactStyleRow(
      name: contactName,
      subtitle: subtitle,
      imageUrl: contact.avatarUrl,
      avatarBackgroundColor: contact.isGroup
          ? const Color(0xFF67B8D8)
          : appPrimaryColor,
      fallbackIcon: contact.isGroup
          ? Icons.groups_rounded
          : Icons.person_rounded,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected ? appPrimaryColor : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? appPrimaryColor : const Color(0xFFC6D4E3),
            width: 1.4,
          ),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: isSelected ? Colors.white : Colors.transparent,
        ),
      ),
      onTap: onTap,
    );
  }
}
