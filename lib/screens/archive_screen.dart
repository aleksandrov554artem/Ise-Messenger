part of '../main.dart';

class ArchivedContactsScreen extends StatefulWidget {
  const ArchivedContactsScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<ArchivedContactsScreen> createState() => _ArchivedContactsScreenState();
}

class _ArchivedContactsScreenState extends State<ArchivedContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final Listenable _screenListenable;
  bool get _showArchiveSearch => false;

  @override
  void initState() {
    super.initState();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.contactsListenable,
      widget.controller.sessionListenable,
    ]);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (_searchQuery == nextQuery) {
      return;
    }
    setState(() {
      _searchQuery = nextQuery;
    });
  }

  List<ContactItem> _filterContacts(List<ContactItem> contacts) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return contacts;
    }
    return contacts
        .where((contact) => contact.matchesSearch(normalizedQuery))
        .toList(growable: false);
  }

  Future<void> _openChat(ContactItem contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(controller: widget.controller, initialContact: contact),
      ),
    );
  }

  Future<void> _unarchiveContact(ContactItem contact) async {
    try {
      await widget.controller.unarchiveContact(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат возвращен из архива');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _deleteContact(ContactItem contact) async {
    try {
      await widget.controller.deleteContact(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат удален');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _leaveGroup(ContactItem contact) async {
    try {
      await widget.controller.leaveGroup(contact.userId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _deleteGroup(ContactItem contact) async {
    try {
      await widget.controller.deleteGroup(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Группа удалена');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _showContactActions(ContactItem contact) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        final currentUserId = widget.controller.user?.id;
        final isGroupOwner =
            contact.isGroup &&
            currentUserId != null &&
            currentUserId == contact.ownerId;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.unarchive_rounded),
                title: const Text('Вернуть из архива'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_unarchiveContact(contact));
                },
              ),
              if (contact.isGroup)
                ListTile(
                  leading: Icon(
                    isGroupOwner ? Icons.delete_rounded : Icons.delete_rounded,
                    color: appPrimaryColor,
                  ),
                  title: Text(
                    isGroupOwner
                        ? 'Удалить группу для всех'
                        : 'Покинуть группу',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (isGroupOwner) {
                      unawaited(_deleteGroup(contact));
                    } else {
                      unawaited(_leaveGroup(contact));
                    }
                  },
                ),
              if (contact.isDirect)
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: appPrimaryColor,
                  ),
                  title: const Text('Удалить чат'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_deleteContact(contact));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleUnarchiveSwipe(ContactItem contact) async {
    try {
      await widget.controller.unarchiveContact(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат возвращен из архива');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
      color: appPrimaryColor.withValues(alpha: 0.12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Вернуть',
            style: TextStyle(
              color: appPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.unarchive_rounded, color: appPrimaryColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final archivedContacts = _showArchiveSearch
            ? _filterContacts(widget.controller.archivedContacts)
            : widget.controller.archivedContacts;
        final hasSearchQuery =
            _showArchiveSearch && _searchQuery.trim().isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            leading: buildPlainBackButton(context),
            title: const Text('Архив'),
          ),
          body: Container(
            decoration: BoxDecoration(gradient: buildSettingsGradient()),
            child: SafeArea(
              child: AppScreenSurface(
                child: Column(
                  children: [
                    if (_showArchiveSearch)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: hasSearchQuery
                                ? IconButton(
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF4F7FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFD5DEEA),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFD5DEEA),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: appPrimaryColor,
                                width: 1.4,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: archivedContacts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                0,
                                appEmptyStateTopSpacing,
                                0,
                                24,
                              ),
                              children: [
                                AppSectionCard(
                                  margin: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    0,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        hasSearchQuery
                                            ? Icons.search_off_rounded
                                            : Icons.archive_rounded,
                                        size: 56,
                                        color: const Color(0xFF7E8AA0),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        hasSearchQuery
                                            ? 'Ничего не найдено'
                                            : 'Архив пуст',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF293241),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                              itemCount: archivedContacts.length,
                              itemBuilder: (context, index) {
                                final contact = archivedContacts[index];
                                return _ArchiveSwipeWrapper(
                                  key: ValueKey(
                                    'contacts_archived_${contact.userId}',
                                  ),
                                  gestureId:
                                      'contacts_archived_${contact.userId}',
                                  background: _buildDismissBackground(),
                                  onAction: () =>
                                      _handleUnarchiveSwipe(contact),
                                  child: ContactCard(
                                    contact: contact,
                                    currentUserId: widget.controller.user?.id,
                                    draftText: widget.controller.draftFor(
                                      contact.userId,
                                    ),
                                    onTap: () => _openChat(contact),
                                    onLongPress: () =>
                                        _showContactActions(contact),
                                  ),
                                );
                              },
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
