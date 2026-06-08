part of '../main.dart';

Future<List<ContactItem>?> showGroupContactPickerSheet({
  required BuildContext context,
  required List<ContactItem> contacts,
  required String title,
  required String confirmLabel,
  Set<int> excludedUserIds = const <int>{},
}) {
  return showModalBottomSheet<List<ContactItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: GroupContactPickerScreen(
          contacts: contacts,
          title: title,
          confirmLabel: confirmLabel,
          excludedUserIds: excludedUserIds,
        ),
      ),
    ),
  );
}

class GroupContactPickerScreen extends StatefulWidget {
  const GroupContactPickerScreen({
    super.key,
    required this.contacts,
    required this.title,
    required this.confirmLabel,
    this.excludedUserIds = const <int>{},
  });

  final List<ContactItem> contacts;
  final String title;
  final String confirmLabel;
  final Set<int> excludedUserIds;

  @override
  State<GroupContactPickerScreen> createState() =>
      _GroupContactPickerScreenState();
}

class _GroupContactPickerScreenState extends State<GroupContactPickerScreen> {
  late final List<ContactItem> availableContacts;
  final Set<int> selectedUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    availableContacts = widget.contacts
        .where(
          (contact) =>
              contact.isDirect &&
              !widget.excludedUserIds.contains(contact.userId),
        )
        .toList(growable: false);
  }

  void _toggleContact(ContactItem contact) {
    setState(() {
      if (!selectedUserIds.add(contact.userId)) {
        selectedUserIds.remove(contact.userId);
      }
    });
  }

  void _submit() {
    final selectedContacts = availableContacts
        .where((contact) => selectedUserIds.contains(contact.userId))
        .toList(growable: false);
    if (selectedContacts.isEmpty) {
      showError(context, Exception('Выберите хотя бы один чат'));
      return;
    }
    Navigator.of(context).pop(selectedContacts);
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
                                'Сначала добавьте чаты.',
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
                                      final isSelected = selectedUserIds
                                          .contains(contact.userId);
                                      return _GroupContactPickerTile(
                                        contact: contact,
                                        isSelected: isSelected,
                                        onTap: () => _toggleContact(contact),
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
                      child: Text(widget.confirmLabel),
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

class _GroupContactPickerTile extends StatelessWidget {
  const _GroupContactPickerTile({
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
    return ContactStyleRow(
      name: contactName,
      subtitle: contact.email,
      imageUrl: contact.avatarUrl,
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
