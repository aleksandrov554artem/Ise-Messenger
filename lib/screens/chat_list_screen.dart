part of '../main.dart';

enum _ContactsMenuAction { stories, archive, settings, addContact, createGroup }

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with WidgetsBindingObserver {
  _AvailableAppUpdate? _availableAppUpdate;
  bool _isCheckingForAppUpdate = false;
  bool _isDownloadingAppUpdate = false;
  bool _isCancellingAppUpdateDownload = false;
  double? _appUpdateDownloadProgress;
  DateTime? _lastAppUpdateCheckAt;
  http.Client? _appUpdateDownloadClient;
  String? _appUpdateDownloadFilePath;
  late final Listenable _screenListenable;
  bool _isOpeningArchive = false;

  @override
  void initState() {
    super.initState();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.contactsListenable,
      widget.controller.storiesListenable,
      widget.controller.sessionListenable,
    ]);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkForAppUpdate(force: true));
  }

  @override
  void dispose() {
    _appUpdateDownloadClient?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkForAppUpdate());
    }
  }

  Future<void> _checkForAppUpdate({bool force = false}) async {
    if (!Platform.isAndroid ||
        _isCheckingForAppUpdate ||
        _isDownloadingAppUpdate) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastAppUpdateCheckAt != null &&
        now.difference(_lastAppUpdateCheckAt!) < appUpdateCheckCooldown) {
      return;
    }
    setState(() {
      _isCheckingForAppUpdate = true;
    });
    var nextAvailableUpdate = _availableAppUpdate;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = _installedAppVersionLabel(packageInfo);
      final latestUpdate = await _fetchLatestGitHubAppUpdate();
      if (latestUpdate == null ||
          _compareVersionLabels(latestUpdate.versionLabel, installedVersion) <=
              0) {
        nextAvailableUpdate = null;
      } else {
        nextAvailableUpdate = latestUpdate;
      }
    } catch (_) {
      nextAvailableUpdate = _availableAppUpdate;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForAppUpdate = false;
          _lastAppUpdateCheckAt = now;
          _availableAppUpdate = nextAvailableUpdate;
        });
      }
    }
    if (nextAvailableUpdate == null) {
      await PushNotificationsService.instance.cancelAppUpdateNotification();
      await _clearNotifiedAppUpdateVersion();
      return;
    }
    await _notifyAboutAvailableAppUpdate();
  }

  Future<void> _notifyAboutAvailableAppUpdate() async {
    final update = _availableAppUpdate;
    if (update == null) {
      await PushNotificationsService.instance.cancelAppUpdateNotification();
      await _clearNotifiedAppUpdateVersion();
      return;
    }
    final normalizedVersion = update.versionLabel.trim();
    if (normalizedVersion.isEmpty) {
      return;
    }
    final lastNotifiedVersion = await _loadNotifiedAppUpdateVersion();
    if (lastNotifiedVersion == normalizedVersion) {
      return;
    }
    await PushNotificationsService.instance.showAppUpdateNotification(
      versionLabel: normalizedVersion,
    );
    await _rememberNotifiedAppUpdateVersion(normalizedVersion);
  }

  void _cancelAppUpdateDownload() {
    if (!_isDownloadingAppUpdate) {
      return;
    }
    setState(() {
      _isCancellingAppUpdateDownload = true;
    });
    _appUpdateDownloadClient?.close();
  }

  Future<void> _downloadAndInstallAppUpdate() async {
    final update = _availableAppUpdate;
    if (!Platform.isAndroid || update == null || _isDownloadingAppUpdate) {
      return;
    }
    final client = http.Client();
    IOSink? fileSink;
    try {
      setState(() {
        _isDownloadingAppUpdate = true;
        _isCancellingAppUpdateDownload = false;
        _appUpdateDownloadProgress = 0;
      });
      await PushNotificationsService.instance.cancelAppUpdateNotification();
      _appUpdateDownloadClient = client;
      final cacheDirectory = await getTemporaryDirectory();
      final updatesDirectory = Directory(
        '${cacheDirectory.path}${Platform.pathSeparator}app_updates',
      );
      if (!await updatesDirectory.exists()) {
        await updatesDirectory.create(recursive: true);
      }
      final apkFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}${_sanitizeUpdateFileName(update.assetName)}',
      );
      _appUpdateDownloadFilePath = apkFile.path;
      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      final request = http.Request('GET', Uri.parse(update.downloadUrl))
        ..headers['User-Agent'] = 'Ise Messenger Updater';
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Не удалось скачать обновление');
      }
      fileSink = apkFile.openWrite();
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      var lastReportedProgress = -1.0;
      await for (final chunk in response.stream.timeout(
        const Duration(minutes: 10),
      )) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        if (mounted && totalBytes > 0) {
          final nextProgress = (receivedBytes / totalBytes)
              .clamp(0.0, 1.0)
              .toDouble();
          if (lastReportedProgress < 0 ||
              nextProgress >= 1 ||
              (nextProgress - lastReportedProgress).abs() >= 0.01) {
            lastReportedProgress = nextProgress;
            setState(() {
              _appUpdateDownloadProgress = nextProgress;
            });
          }
        }
      }
      await fileSink.flush();
      await fileSink.close();
      fileSink = null;
      if (_isCancellingAppUpdateDownload) {
        return;
      }
      if (mounted) {
        setState(() {
          _appUpdateDownloadProgress = 1;
        });
      }
      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw Exception(
          result.message.trim().isEmpty
              ? 'Не удалось открыть установщик обновления'
              : result.message,
        );
      }
      if (!mounted) {
        return;
      }
    } catch (error) {
      if (_isCancellingAppUpdateDownload) {
        return;
      }
      if (!mounted) {
        return;
      }
      showError(
        context,
        error,
        fallbackMessage: 'Не удалось скачать обновление',
      );
    } finally {
      final shouldDeleteDownloadedFile = _isCancellingAppUpdateDownload;
      final appUpdateDownloadFilePath = _appUpdateDownloadFilePath;
      client.close();
      _appUpdateDownloadClient = null;
      _appUpdateDownloadFilePath = null;
      if (fileSink != null) {
        try {
          await fileSink.flush();
        } catch (_) {}
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (shouldDeleteDownloadedFile &&
          appUpdateDownloadFilePath != null &&
          appUpdateDownloadFilePath.isNotEmpty) {
        try {
          final partialFile = File(appUpdateDownloadFilePath);
          if (await partialFile.exists()) {
            await partialFile.delete();
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isDownloadingAppUpdate = false;
          _isCancellingAppUpdateDownload = false;
          _appUpdateDownloadProgress = null;
        });
      }
    }
  }

  Widget? _buildAppUpdateButton() {
    if (!Platform.isAndroid) {
      return null;
    }
    final update = _availableAppUpdate;
    if (update == null && !_isDownloadingAppUpdate) {
      return null;
    }
    final progress = _appUpdateDownloadProgress;
    final progressLabel = _isCancellingAppUpdateDownload
        ? 'Отмена...'
        : progress == null
        ? 'Загрузка...'
        : 'Загрузка ${(progress * 100).clamp(0, 100).round()}%';
    return FloatingActionButton.extended(
      heroTag: 'contacts_update_button',
      onPressed: _isDownloadingAppUpdate
          ? _cancelAppUpdateDownload
          : _downloadAndInstallAppUpdate,
      backgroundColor: appPrimaryColor,
      foregroundColor: Colors.white,
      icon: Icon(
        _isDownloadingAppUpdate
            ? Icons.close_rounded
            : Icons.system_update_alt_rounded,
      ),
      label: Text(
        _isDownloadingAppUpdate ? progressLabel : 'Обновить приложение',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _openAddContact() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddContactScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateGroupScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openStories() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoriesScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openArchive() async {
    if (_isOpeningArchive) {
      return;
    }
    _isOpeningArchive = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArchivedContactsScreen(controller: widget.controller),
        ),
      );
    } finally {
      _isOpeningArchive = false;
    }
  }

  Future<void> _openChat(ContactItem contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(controller: widget.controller, initialContact: contact),
      ),
    );
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

  Future<void> _setContactArchivedState(
    ContactItem contact,
    bool isArchived,
  ) async {
    try {
      if (isArchived) {
        await widget.controller.archiveContact(contact.userId);
      } else {
        await widget.controller.unarchiveContact(contact.userId);
      }
      if (!mounted) {
        return;
      }
      showSuccessToast(
        context,
        isArchived ? 'Чат добавлен в архив' : 'Чат возвращен из архива',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _handleArchiveSwipe(ContactItem contact) async {
    try {
      await widget.controller.archiveContact(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат добавлен в архив');
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
        final isArchived = widget.controller.isContactArchived(contact.userId);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                ),
                title: Text(
                  isArchived ? 'Убрать из архива' : 'Добавить в архив',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_setContactArchivedState(contact, !isArchived));
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

  void _handleMenuAction(_ContactsMenuAction action) {
    switch (action) {
      case _ContactsMenuAction.stories:
        unawaited(_openStories());
        return;
      case _ContactsMenuAction.settings:
        unawaited(_openSettings());
        return;
      case _ContactsMenuAction.archive:
        unawaited(_openArchive());
        return;
      case _ContactsMenuAction.addContact:
        unawaited(_openAddContact());
        return;
      case _ContactsMenuAction.createGroup:
        unawaited(_openCreateGroup());
        return;
    }
  }

  Widget _buildArchiveDismissBackground({
    required bool archive,
    required bool alignRight,
  }) {
    final icon = archive ? Icons.archive_rounded : Icons.unarchive_rounded;
    final label = archive ? 'Архив' : 'Вернуть';
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14).add(
        EdgeInsets.only(left: alignRight ? 0 : 16, right: alignRight ? 16 : 0),
      ),
      color: appPrimaryColor.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!alignRight) ...[
            Icon(icon, color: appPrimaryColor),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: const TextStyle(
              color: appPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (alignRight) ...[
            const SizedBox(width: 10),
            Icon(icon, color: appPrimaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildContactsMenu(
    bool hasUnreadArchivedContacts,
    bool hasUnreadStories,
  ) {
    final hasMenuDot = hasUnreadArchivedContacts || hasUnreadStories;
    return PopupMenuButton<_ContactsMenuAction>(
      tooltip: '',
      onSelected: _handleMenuAction,
      icon: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.more_vert_rounded),
            if (hasMenuDot)
              const Positioned(top: 1, right: 2, child: _UnreadMessageDot()),
          ],
        ),
      ),
      offset: const Offset(0, 44),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<_ContactsMenuAction>(
          value: _ContactsMenuAction.stories,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: appPrimaryColor,
                  ),
                  if (hasUnreadStories)
                    const Positioned(
                      top: -5,
                      right: -6,
                      child: _UnreadMessageDot(),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              const Text('Истории'),
            ],
          ),
        ),
        PopupMenuItem<_ContactsMenuAction>(
          value: _ContactsMenuAction.archive,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.archive_rounded, color: appPrimaryColor),
                  if (hasUnreadArchivedContacts)
                    const Positioned(
                      top: -5,
                      right: -6,
                      child: _UnreadMessageDot(),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              const Text('Архив'),
            ],
          ),
        ),
        const PopupMenuItem<_ContactsMenuAction>(
          value: _ContactsMenuAction.settings,
          child: Row(
            children: [
              Icon(Icons.settings_rounded, color: appPrimaryColor),
              SizedBox(width: 12),
              Text('Настройки'),
            ],
          ),
        ),
        const PopupMenuItem<_ContactsMenuAction>(
          value: _ContactsMenuAction.addContact,
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: appPrimaryColor),
              SizedBox(width: 12),
              Text('Добавить чат'),
            ],
          ),
        ),
        const PopupMenuItem<_ContactsMenuAction>(
          value: _ContactsMenuAction.createGroup,
          child: Row(
            children: [
              Icon(Icons.group_add_rounded, color: appPrimaryColor),
              SizedBox(width: 12),
              Text('Создать группу'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final contacts = widget.controller.activeContacts;
        final archivedContacts = widget.controller.archivedContacts;
        final hasArchivedContacts = archivedContacts.isNotEmpty;
        final hasUnreadArchivedContacts = archivedContacts.any(
          (contact) => contact.hasUnreadMessageIndicator,
        );
        final hasUnreadStories = widget.controller.hasUnreadStories;
        final hasAppUpdateButton =
            Platform.isAndroid &&
            (_availableAppUpdate != null || _isDownloadingAppUpdate);
        final listBottomPadding = hasAppUpdateButton ? 108.0 : 24.0;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appLightSurfaceOverlayStyle,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Чаты'),
              actions: [
                _buildContactsMenu(hasUnreadArchivedContacts, hasUnreadStories),
                const SizedBox(width: 8),
              ],
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: _buildAppUpdateButton(),
            body: Container(
              decoration: BoxDecoration(gradient: buildSettingsGradient()),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: appSurfaceColor,
                        child: Column(
                          children: [
                            Expanded(
                              child: contacts.isEmpty
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        bottom: listBottomPadding,
                                      ),
                                      children: [
                                        const SizedBox(
                                          height: appEmptyStateTopSpacing,
                                        ),
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
                                                hasArchivedContacts
                                                    ? Icons.archive_rounded
                                                    : Icons.forum_rounded,
                                                size: 56,
                                                color: const Color(0xFF7E8AA0),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                'Чатов нет',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF293241,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        0,
                                        12,
                                        0,
                                        listBottomPadding,
                                      ),
                                      itemCount: contacts.length,
                                      itemBuilder: (context, index) {
                                        final contact = contacts[index];
                                        return _ArchiveSwipeWrapper(
                                          key: ValueKey(
                                            'contacts_active_${contact.userId}',
                                          ),
                                          gestureId:
                                              'contacts_active_${contact.userId}',
                                          background:
                                              _buildArchiveDismissBackground(
                                                archive: true,
                                                alignRight: true,
                                              ),
                                          onAction: () =>
                                              _handleArchiveSwipe(contact),
                                          child: ContactCard(
                                            contact: contact,
                                            currentUserId:
                                                widget.controller.user?.id,
                                            draftText: widget.controller
                                                .draftFor(contact.userId),
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

class ChatDaySeparator extends StatelessWidget {
  const ChatDaySeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE3EAF3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF516173),
            ),
          ),
        ),
      ),
    );
  }
}

class CallActionButton extends StatelessWidget {
  const CallActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => unawaited(onTap()),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

String formatAttachmentSize(int sizeBytes) {
  if (sizeBytes <= 0) {
    return '';
  }
  const units = ['Б', 'КБ', 'МБ', 'ГБ'];
  var value = sizeBytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

class ChatComposerActionButton extends StatelessWidget {
  const ChatComposerActionButton({
    super.key,
    this.icon = Icons.send_rounded,
    this.onTap,
    this.filled = false,
    this.isLoading = false,
    this.showBackground = true,
    this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool isLoading;
  final bool showBackground;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = filled ? appPrimaryColor : Colors.white;
    final borderColor = filled ? appPrimaryColor : appOutlineColor;
    final iconColor =
        foregroundColor ?? (filled ? Colors.white : appPrimaryColor);
    final enabled = onTap != null || isLoading;
    if (!showBackground) {
      final effectiveIconColor = enabled
          ? (foregroundColor ?? appPrimaryColor)
          : (foregroundColor ?? appPrimaryColor).withValues(alpha: 0.45);
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          effectiveIconColor,
                        ),
                      ),
                    )
                  : Icon(icon, color: effectiveIconColor, size: 22),
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.74),
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? borderColor : borderColor.withValues(alpha: 0.45),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class LinkPreviewData {
  const LinkPreviewData({
    required this.url,
    required this.host,
    this.title,
    this.description,
    this.imageUrl,
  });

  final String url;
  final String host;
  final String? title;
  final String? description;
  final String? imageUrl;
}

class _MessageTextSegment {
  const _MessageTextSegment({required this.text, required this.isLink});

  final String text;
  final bool isLink;
}

final RegExp messageLinkPattern = RegExp(
  r'((?:https?:\/\/)?(?:www\.)?[^\s<]+?\.[^\s<]{2,}[^\s<]*)',
  caseSensitive: false,
);
const int _maxLinkPreviewCacheEntries = 160;
final LinkedHashMap<String, Future<LinkPreviewData?>> linkPreviewCache =
    LinkedHashMap<String, Future<LinkPreviewData?>>();

String encodeStructuredMessage({
  required String text,
  String? forwardedFromName,
  String? replyToName,
  String? replyToText,
  int? replyToMessageId,
  String? serviceKind,
  int? callInitiatorId,
  String? callStatus,
  bool? callIsVideo,
}) {
  final rawText = text;
  final rawForwardedName = forwardedFromName ?? '';
  final rawReplyName = replyToName ?? '';
  final rawReplyText = replyToText ?? '';
  final rawReplyToMessageId = replyToMessageId;
  final rawServiceKind = serviceKind ?? '';
  final rawCallInitiatorId = callInitiatorId;
  final rawCallStatus = callStatus ?? '';
  final rawCallIsVideo = callIsVideo;
  if (rawText.trim().isEmpty &&
      rawForwardedName.trim().isEmpty &&
      rawReplyName.trim().isEmpty &&
      rawReplyText.trim().isEmpty &&
      rawReplyToMessageId == null &&
      rawServiceKind.trim().isEmpty &&
      rawCallInitiatorId == null &&
      rawCallStatus.trim().isEmpty &&
      rawCallIsVideo == null) {
    return '';
  }
  if (rawForwardedName.trim().isEmpty &&
      rawReplyName.trim().isEmpty &&
      rawReplyText.trim().isEmpty &&
      rawReplyToMessageId == null &&
      rawServiceKind.trim().isEmpty &&
      rawCallInitiatorId == null &&
      rawCallStatus.trim().isEmpty &&
      rawCallIsVideo == null) {
    return rawText;
  }
  final payload = <String, Object>{'text': rawText};
  if (rawForwardedName.trim().isNotEmpty) {
    payload['from'] = rawForwardedName;
  }
  if (rawReplyName.trim().isNotEmpty) {
    payload['reply_from'] = rawReplyName;
  }
  if (rawReplyText.trim().isNotEmpty) {
    payload['reply_text'] = rawReplyText;
  }
  if (rawReplyToMessageId != null) {
    payload['reply_to_message_id'] = rawReplyToMessageId;
  }
  if (rawServiceKind.trim().isNotEmpty) {
    payload['service_kind'] = rawServiceKind;
  }
  if (rawCallInitiatorId != null) {
    payload['call_initiator_id'] = rawCallInitiatorId;
  }
  if (rawCallStatus.trim().isNotEmpty) {
    payload['call_status'] = rawCallStatus;
  }
  if (rawCallIsVideo != null) {
    payload['call_is_video'] = rawCallIsVideo;
  }
  return '$forwardedMessagePrefix${base64UrlEncode(utf8.encode(jsonEncode(payload)))}';
}

ParsedStoredMessageText parseStoredMessageText(String rawValue) {
  if (!rawValue.startsWith(forwardedMessagePrefix)) {
    return ParsedStoredMessageText(text: rawValue);
  }
  final encodedPayload = rawValue.substring(forwardedMessagePrefix.length);
  try {
    final decodedPayload = utf8.decode(
      base64Url.decode(base64Url.normalize(encodedPayload)),
    );
    final parsed = jsonDecode(decodedPayload);
    if (parsed is Map) {
      final text = parsed['text']?.toString() ?? '';
      final forwardedFromName = parsed['from']?.toString() ?? '';
      final replyToName = parsed['reply_from']?.toString() ?? '';
      final replyToText = parsed['reply_text']?.toString() ?? '';
      final serviceKind = parsed['service_kind']?.toString() ?? '';
      final replyToMessageId = switch (parsed['reply_to_message_id']) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      };
      final callInitiatorId = switch (parsed['call_initiator_id']) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      };
      final callStatus = parsed['call_status']?.toString() ?? '';
      final callIsVideo = switch (parsed['call_is_video']) {
        final bool value => value,
        final num value => value != 0,
        final String value => switch (value.trim().toLowerCase()) {
          '1' || 'true' || 'yes' => true,
          '0' || 'false' || 'no' => false,
          _ => null,
        },
        _ => null,
      };
      if (text.trim().isNotEmpty ||
          forwardedFromName.trim().isNotEmpty ||
          replyToName.trim().isNotEmpty ||
          replyToText.trim().isNotEmpty ||
          replyToMessageId != null ||
          serviceKind.trim().isNotEmpty ||
          callInitiatorId != null ||
          callStatus.trim().isNotEmpty ||
          callIsVideo != null) {
        return ParsedStoredMessageText(
          text: text,
          forwardedFromName: forwardedFromName.trim().isEmpty
              ? null
              : forwardedFromName,
          replyToName: replyToName.trim().isEmpty ? null : replyToName,
          replyToText: replyToText.trim().isEmpty ? null : replyToText,
          replyToMessageId: replyToMessageId,
          serviceKind: serviceKind.trim().isEmpty ? null : serviceKind,
          callInitiatorId: callInitiatorId,
          callStatus: callStatus.trim().isEmpty ? null : callStatus,
          callIsVideo: callIsVideo,
        );
      }
    }
  } catch (_) {}
  return ParsedStoredMessageText(text: rawValue);
}

Uri? normalizeLinkUri(String rawValue) {
  var normalized = rawValue.trim();
  while (normalized.isNotEmpty &&
      '.,!?;:)]}>'.contains(normalized[normalized.length - 1])) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty) {
    return null;
  }
  if (!normalized.contains('://')) {
    normalized = 'https://$normalized';
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

String? extractFirstLink(String text) {
  final match = messageLinkPattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final normalized = normalizeLinkUri(match.group(0) ?? '');
  return normalized?.toString();
}

List<_MessageTextSegment> _splitMessageText(String text) {
  final segments = <_MessageTextSegment>[];
  var cursor = 0;
  for (final match in messageLinkPattern.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(
        _MessageTextSegment(
          text: text.substring(cursor, match.start),
          isLink: false,
        ),
      );
    }
    final linkText = text.substring(match.start, match.end);
    segments.add(_MessageTextSegment(text: linkText, isLink: true));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(
      _MessageTextSegment(text: text.substring(cursor), isLink: false),
    );
  }
  if (segments.isEmpty) {
    segments.add(_MessageTextSegment(text: text, isLink: false));
  }
  return segments;
}

String? _extractFirstLinkFromSegments(List<_MessageTextSegment> segments) {
  for (final segment in segments) {
    if (!segment.isLink) {
      continue;
    }
    final normalized = normalizeLinkUri(segment.text);
    if (normalized != null) {
      return normalized.toString();
    }
  }
  return null;
}

List<InlineSpan> buildMessageTextSpans(
  String text, {
  required Color linkColor,
}) {
  return _buildMessageTextSpansFromSegments(
    _splitMessageText(text),
    linkColor: linkColor,
  );
}

List<InlineSpan> _buildMessageTextSpansFromSegments(
  List<_MessageTextSegment> segments, {
  required Color linkColor,
}) {
  return segments
      .map((segment) {
        if (!segment.isLink) {
          return TextSpan(text: segment.text);
        }
        final uri = normalizeLinkUri(segment.text);
        if (uri == null) {
          return TextSpan(text: segment.text);
        }
        return TextSpan(
          text: segment.text,
          style: TextStyle(color: linkColor, fontWeight: FontWeight.w600),
        );
      })
      .toList(growable: false);
}

Future<void> openExternalLink(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<LinkPreviewData?> buildLinkPreviewFuture(String rawUrl) {
  final uri = normalizeLinkUri(rawUrl);
  if (uri == null) {
    return Future<LinkPreviewData?>.value(null);
  }
  final cacheKey = uri.toString();
  final existing = linkPreviewCache.remove(cacheKey);
  if (existing != null) {
    linkPreviewCache[cacheKey] = existing;
    return existing;
  }
  final future = fetchLinkPreview(uri);
  linkPreviewCache[cacheKey] = future;
  if (linkPreviewCache.length > _maxLinkPreviewCacheEntries) {
    linkPreviewCache.remove(linkPreviewCache.keys.first);
  }
  return future;
}

Future<LinkPreviewData?> fetchLinkPreview(Uri uri) async {
  try {
    final response = await _sharedUtilityHttpClient
        .get(
          uri,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Ise Messenger Link Preview)',
          },
        )
        .timeout(const Duration(seconds: 8));
    final fallback = LinkPreviewData(url: uri.toString(), host: uri.host);
    if (response.statusCode >= 400) {
      return fallback;
    }
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('text/html')) {
      return fallback;
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final title = firstNonEmptyPreviewValue([
      extractMetaContent(html, attribute: 'property', value: 'og:title'),
      extractMetaContent(html, attribute: 'name', value: 'twitter:title'),
      extractHtmlTitle(html),
    ]);
    final description = firstNonEmptyPreviewValue([
      extractMetaContent(html, attribute: 'property', value: 'og:description'),
      extractMetaContent(html, attribute: 'name', value: 'description'),
      extractMetaContent(html, attribute: 'name', value: 'twitter:description'),
    ]);
    final imageUrl = resolvePreviewUrl(
      uri,
      firstNonEmptyPreviewValue([
        extractMetaContent(html, attribute: 'property', value: 'og:image'),
        extractMetaContent(html, attribute: 'name', value: 'twitter:image'),
      ]),
    );
    return LinkPreviewData(
      url: uri.toString(),
      host: uri.host,
      title: title,
      description: description,
      imageUrl: imageUrl,
    );
  } catch (_) {
    return LinkPreviewData(url: uri.toString(), host: uri.host);
  }
}

String? firstNonEmptyPreviewValue(List<String?> values) {
  for (final value in values) {
    final cleaned = cleanPreviewText(value);
    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return null;
}

String? extractMetaContent(
  String html, {
  required String attribute,
  required String value,
}) {
  final directPattern = RegExp(
    '<meta[^>]*$attribute=["\\\']$value["\\\'][^>]*content=["\\\']([^"\\\']+)["\\\'][^>]*>',
    caseSensitive: false,
  );
  final reversePattern = RegExp(
    '<meta[^>]*content=["\\\']([^"\\\']+)["\\\'][^>]*$attribute=["\\\']$value["\\\'][^>]*>',
    caseSensitive: false,
  );
  final directMatch = directPattern.firstMatch(html);
  if (directMatch != null) {
    return directMatch.group(1);
  }
  final reverseMatch = reversePattern.firstMatch(html);
  return reverseMatch?.group(1);
}

String? extractHtmlTitle(String html) {
  final match = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  return match?.group(1);
}

String? resolvePreviewUrl(Uri baseUri, String? rawUrl) {
  final cleaned = cleanPreviewText(rawUrl);
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  final previewUri = Uri.tryParse(cleaned);
  if (previewUri == null) {
    return null;
  }
  return previewUri.hasScheme
      ? previewUri.toString()
      : baseUri.resolveUri(previewUri).toString();
}

String? cleanPreviewText(String? rawValue) {
  if (rawValue == null) {
    return null;
  }
  var cleaned = rawValue
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return null;
  }
  cleaned = sanitizeDisplayText(cleaned, preserveLineBreaks: false);
  return cleaned.isEmpty ? null : cleaned;
}

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.url,
    required this.isMine,
    this.onTap,
  });

  final String url;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final uri = normalizeLinkUri(url);
    final fallbackHost = uri?.host.isNotEmpty == true ? uri!.host : url;
    const previewWidth = 248.0;
    const previewImageHeight = 116.0;
    const previewBodyHeight = 124.0;
    final previewImageCacheWidth = _targetImageCacheDimension(
      context,
      previewWidth,
    );
    final previewImageCacheHeight = _targetImageCacheDimension(
      context,
      previewImageHeight,
    );
    final bubbleColor = appPrimaryColor;
    final outgoingCardColor = const Color(0xFF5CAFE2);
    final outgoingAccentColor = const Color(0xFF438FC7);
    final backgroundColor = isMine
        ? outgoingCardColor
        : const Color(0xFFF4F7FB);
    final borderColor = isMine ? Colors.transparent : const Color(0xFFDCE5F0);
    final titleColor = isMine ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isMine
        ? Colors.white.withValues(alpha: 0.76)
        : const Color(0xFF526071);
    return FutureBuilder<LinkPreviewData?>(
      future: buildLinkPreviewFuture(url),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            LinkPreviewData(url: uri?.toString() ?? url, host: fallbackHost);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            data.title == null &&
            data.description == null;
        return SizedBox(
          width: previewWidth,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: uri != null ? onTap : null,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  gradient: isMine
                      ? LinearGradient(
                          colors: [outgoingCardColor, outgoingAccentColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: previewImageHeight,
                        width: double.infinity,
                        child: data.imageUrl != null
                            ? Stack(
                                children: [
                                  Image.network(
                                    data.imageUrl!,
                                    headers: serverMediaHttpHeadersFor(
                                      data.imageUrl!,
                                    ),
                                    height: previewImageHeight,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    cacheWidth: previewImageCacheWidth,
                                    cacheHeight: previewImageCacheHeight,
                                    filterQuality: FilterQuality.low,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                  if (isMine)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isMine
                                        ? const [
                                            Color(0xFF154F78),
                                            Color(0xFF1D6B9D),
                                          ]
                                        : const [
                                            Color(0xFFE7EEF6),
                                            Color(0xFFD8E3EF),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: isLoading
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.public_rounded,
                                              size: 30,
                                              color: isMine
                                                  ? Colors.white.withValues(
                                                      alpha: 0.92,
                                                    )
                                                  : const Color(0xFF5F7083),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              width: 96,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: isMine
                                                    ? Colors.white.withValues(
                                                        alpha: 0.16,
                                                      )
                                                    : const Color(0xFFC9D6E4),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.link_rounded,
                                              size: 30,
                                              color: isMine
                                                  ? Colors.white.withValues(
                                                      alpha: 0.94,
                                                    )
                                                  : const Color(0xFF546578),
                                            ),
                                            const SizedBox(height: 10),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                              child: Text(
                                                data.host,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMine
                                                      ? Colors.white
                                                      : const Color(0xFF435467),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                      ),
                      Container(
                        height: previewBodyHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          gradient: isMine
                              ? LinearGradient(
                                  colors: [
                                    outgoingCardColor,
                                    outgoingAccentColor,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                              ),
                            ),
                            if (isLoading) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                minHeight: 2.6,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: isMine
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : const Color(0xFFE1E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isMine ? Colors.white : bubbleColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 14,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : const Color(0xFFD7E1EC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 184,
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.11)
                                      : const Color(0xFFDFE7F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ] else ...[
                              if (data.title != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  data.title!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                              if (data.description != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  data.description!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void showToast(BuildContext context, String message, {bool isError = false}) {
  final sanitizedMessage = sanitizeDisplayText(
    message.trim(),
    preserveLineBreaks: false,
  );
  if (sanitizedMessage.isEmpty) {
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  _activeToastTimer?.cancel();
  _activeToastEntry?.remove();
  final entry = OverlayEntry(
    builder: (overlayContext) => _ToastOverlay(
      key: _activeToastKey,
      message: sanitizedMessage,
      isError: isError,
    ),
  );
  _activeToastEntry = entry;
  overlay.insert(entry);
  _activeToastTimer = Timer(const Duration(seconds: 2), () {
    if (identical(_activeToastEntry, entry)) {
      _activeToastKey.currentState?.hide();
    }
  });
}

void showSuccessToast(BuildContext context, String message) {
  showToast(context, message);
}

void showGlobalToast(String message, {bool isError = false}) {
  final context = appNavigatorKey.currentContext;
  if (context == null) {
    return;
  }
  showToast(context, message, isError: isError);
}

String _resolveErrorToastMessage(Object error, {String? fallbackMessage}) {
  final fallback = sanitizeDisplayText(
    fallbackMessage?.trim() ?? '',
    preserveLineBreaks: false,
  );
  if (fallback.isNotEmpty) {
    return fallback;
  }
  final message = sanitizeDisplayText(
    error.toString().replaceFirst('Exception: ', ''),
    preserveLineBreaks: false,
  ).trim();
  if (message.isEmpty) {
    return 'Неизвестная ошибка';
  }
  final normalizedMessage = message.toLowerCase();
  if (normalizedMessage.contains('otp_expired') ||
      normalizedMessage.contains('invalid token') ||
      normalizedMessage.contains('invalid otp') ||
      normalizedMessage.contains('token has expired') ||
      normalizedMessage.contains('expired or is invalid')) {
    return 'Неправильный код';
  }
  if (normalizedMessage.contains('корректную почту') ||
      normalizedMessage.contains('корректную почт')) {
    return 'Введите корректную почту';
  }
  if (normalizedMessage.contains('неверный или просроченный код') ||
      normalizedMessage.contains('неправильный или просроченный код') ||
      normalizedMessage.contains('введите код из письма') ||
      normalizedMessage.contains('неправильный код')) {
    return 'Неправильный код';
  }
  if (normalizedMessage.contains('имя должно содержать минимум 2 символа') ||
      normalizedMessage.contains('слишком короткое имя')) {
    return 'Слишком короткое имя';
  }
  if (normalizedMessage.contains('пользователь с такой почтой не найден') ||
      normalizedMessage.contains('пользователь не найден')) {
    return 'Пользователь не найден';
  }
  if (normalizedMessage.contains('не удалось отправить письмо') ||
      normalizedMessage.contains('ошибка отправки кода') ||
      normalizedMessage.contains('smtp')) {
    return 'Ошибка отправки кода';
  }
  if (normalizedMessage.contains('сервер') ||
      normalizedMessage.contains('соединения с сервером') ||
      normalizedMessage.contains('сервером')) {
    return 'Ошибка сервера';
  }
  return 'Неизвестная ошибка';
}

void showError(BuildContext context, Object error, {String? fallbackMessage}) {
  showToast(
    context,
    _resolveErrorToastMessage(error, fallbackMessage: fallbackMessage),
    isError: true,
  );
}

final GlobalKey<_ToastOverlayState> _activeToastKey =
    GlobalKey<_ToastOverlayState>();

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
    });
  }

  void hide() {
    if (!_visible) {
      _removeEntry();
      return;
    }
    setState(() {
      _visible = false;
    });
    Timer(const Duration(milliseconds: 240), _removeEntry);
  }

  void _removeEntry() {
    final entry = _activeToastEntry;
    if (entry == null) {
      return;
    }
    entry.remove();
    _activeToastEntry = null;
    _activeToastTimer?.cancel();
    _activeToastTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isError ? appDangerColor : appPrimaryColor;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0, 1.15),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildPlainBackButton(BuildContext context) {
  return IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.arrow_back_ios_new_rounded),
  );
}

String normalizeEmail(String value) {
  return value.trim().toLowerCase();
}

bool isValidEmail(String value) {
  return _emailValidationPattern.hasMatch(value);
}

String? emptyToNull(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String sanitizeDisplayText(String rawValue, {bool preserveLineBreaks = true}) {
  final repaired = repairMojibakeText(rawValue);
  if (preserveLineBreaks) {
    return repaired;
  }
  return repaired.replaceAll('\r', '').replaceAll('\n', ' ');
}

String normalizeKnownCallSystemText(
  String rawValue, {
  bool preserveLineBreaks = true,
}) {
  return sanitizeDisplayText(rawValue, preserveLineBreaks: preserveLineBreaks);
}

String repairMojibakeText(String value) {
  var current = value;
  for (var attempt = 0; attempt < 3; attempt += 1) {
    if (!_looksLikeUtf8Cp1251Mojibake(current)) {
      break;
    }
    final bytes = <int>[];
    var canEncode = true;
    for (final rune in current.runes) {
      final byte = _cp1251ByteForRune(rune);
      if (byte == null) {
        canEncode = false;
        break;
      }
      bytes.add(byte);
    }
    if (!canEncode) {
      break;
    }
    late final String repaired;
    try {
      repaired = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      break;
    }
    if (repaired == current) {
      break;
    }
    current = repaired;
  }
  return current;
}

bool _looksLikeUtf8Cp1251Mojibake(String value) {
  final runes = value.runes.toList(growable: false);
  for (var index = 0; index < runes.length - 1; index += 1) {
    final first = runes[index];
    final second = runes[index + 1];
    if ((first == 0x0420 || first == 0x0421) &&
        _isCp1251MojibakeTrail(second)) {
      return true;
    }
  }
  return false;
}

bool _isCp1251MojibakeTrail(int rune) {
  return (rune >= 0x00A0 && rune <= 0x00BF) ||
      (rune >= 0x0400 && rune <= 0x045F) ||
      rune == 0x201A ||
      rune == 0x201E ||
      rune == 0x2026 ||
      rune == 0x2020 ||
      rune == 0x2021 ||
      rune == 0x20AC ||
      rune == 0x2030 ||
      rune == 0x2039 ||
      rune == 0x2018 ||
      rune == 0x2019 ||
      rune == 0x201C ||
      rune == 0x201D ||
      rune == 0x2022 ||
      rune == 0x2013 ||
      rune == 0x2014 ||
      rune == 0x2122 ||
      rune == 0x203A;
}

int? _cp1251ByteForRune(int rune) {
  if (rune <= 0x7F) {
    return rune;
  }
  if (rune >= 0x0410 && rune <= 0x044F) {
    return rune - 0x0410 + 0xC0;
  }
  const special = <int, int>{
    0x0402: 0x80,
    0x0403: 0x81,
    0x201A: 0x82,
    0x0453: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x20AC: 0x88,
    0x2030: 0x89,
    0x0409: 0x8A,
    0x2039: 0x8B,
    0x040A: 0x8C,
    0x040C: 0x8D,
    0x040B: 0x8E,
    0x040F: 0x8F,
    0x0452: 0x90,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x2122: 0x99,
    0x0459: 0x9A,
    0x203A: 0x9B,
    0x045A: 0x9C,
    0x045C: 0x9D,
    0x045B: 0x9E,
    0x045F: 0x9F,
    0x00A0: 0xA0,
    0x040E: 0xA1,
    0x045E: 0xA2,
    0x0408: 0xA3,
    0x00A4: 0xA4,
    0x0490: 0xA5,
    0x00A6: 0xA6,
    0x00A7: 0xA7,
    0x0401: 0xA8,
    0x00A9: 0xA9,
    0x0404: 0xAA,
    0x00AB: 0xAB,
    0x00AC: 0xAC,
    0x00AD: 0xAD,
    0x00AE: 0xAE,
    0x0407: 0xAF,
    0x00B0: 0xB0,
    0x00B1: 0xB1,
    0x0406: 0xB2,
    0x0456: 0xB3,
    0x0491: 0xB4,
    0x00B5: 0xB5,
    0x00B6: 0xB6,
    0x00B7: 0xB7,
    0x0451: 0xB8,
    0x2116: 0xB9,
    0x0454: 0xBA,
    0x00BB: 0xBB,
    0x0458: 0xBC,
    0x0405: 0xBD,
    0x0455: 0xBE,
    0x0457: 0xBF,
  };
  return special[rune];
}

String formatChatDayTimeLabel(DateTime value) {
  final localValue = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(
    localValue.year,
    localValue.month,
    localValue.day,
  );
  if (messageDay == today) {
    return 'Сегодня в ${formatClock(localValue)}';
  }
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return 'Вчера в ${formatClock(localValue)}';
  }
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  return '$day.$month.${localValue.year} в ${formatClock(localValue)}';
}

String initialsFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

ChatType parseChatType(String? rawValue) {
  return rawValue == 'group' ? ChatType.group : ChatType.direct;
}

int compareContactsByActivity(ContactItem left, ContactItem right) {
  final leftTime = left.lastMessageAt;
  final rightTime = right.lastMessageAt;
  if (leftTime == null && rightTime == null) {
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }
  if (leftTime == null) {
    return 1;
  }
  if (rightTime == null) {
    return -1;
  }
  final byTime = rightTime.compareTo(leftTime);
  if (byTime != 0) {
    return byTime;
  }
  return left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

DateTime? parseServerDateTime(String? raw) {
  if (raw == null) {
    return null;
  }
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final hasTimezone = _serverDateTimezonePattern.hasMatch(normalized);
  final candidate = hasTimezone ? normalized : '${normalized}Z';
  final parsed = DateTime.tryParse(candidate);
  if (parsed == null) {
    return null;
  }
  return parsed.toLocal();
}

String formatMemberCountLabel(int count) {
  final safeCount = count < 0 ? 0 : count;
  final mod10 = safeCount % 10;
  final mod100 = safeCount % 100;
  final suffix = mod10 == 1 && mod100 != 11
      ? 'участник'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'участника'
      : 'участников';
  return '$safeCount $suffix';
}

String formatGroupOnlineCountLabel(int onlineCount, int memberCount) {
  final safeMemberCount = memberCount < 0 ? 0 : memberCount;
  final safeOnlineCount = onlineCount.clamp(0, safeMemberCount);
  return '$safeOnlineCount из $safeMemberCount в сети';
}

String buildConversationPreview(ContactItem contact, int? currentUserId) {
  var message = sanitizeDisplayText(
    contact.lastMessage,
    preserveLineBreaks: false,
  ).trim();
  if (message.isEmpty) {
    if (contact.lastMessageServiceKind == callHistoryServiceKind) {
      return '';
    }
    if (contact.lastMessageAt != null) {
      message = contactLastAttachmentPreviewLabel(contact) ?? 'Файл';
    } else {
      return '\u041d\u0435\u0442 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0439';
    }
  }
  final senderName = sanitizeDisplayText(
    contact.lastMessageSenderName ?? '',
    preserveLineBreaks: false,
  ).trim();
  final isCurrentUserSender =
      currentUserId != null && contact.lastMessageSenderId == currentUserId;
  final prefix = isCurrentUserSender
      ? '\u0412\u044b'
      : contact.isDirect
      ? sanitizeDisplayText(contact.name, preserveLineBreaks: false).trim()
      : (senderName.isEmpty
            ? '\u0423\u0447\u0430\u0441\u0442\u043d\u0438\u043a'
            : senderName);
  return prefix.isEmpty ? message : '$prefix: $message';
}

String? contactLastAttachmentPreviewLabel(ContactItem contact) {
  final kind = contact.lastMessageAttachmentKind?.trim().toLowerCase() ?? '';
  final name = sanitizeDisplayText(
    contact.lastMessageAttachmentName ?? '',
    preserveLineBreaks: false,
  ).trim();
  return switch (kind) {
    'video_note' => 'Видео кружок',
    'image' => 'Фото',
    'video' => 'Видео',
    'audio' => 'Аудио',
    'file' => name.isEmpty ? 'Файл' : name,
    _ => name.isEmpty ? null : name,
  };
}

String formatClock(DateTime value) {
  final local = value.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String formatAudioDuration(Duration value) {
  final totalSeconds = value.inSeconds;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${(totalSeconds ~/ 60)}:$seconds';
}

bool isSameChatDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String formatChatDayLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  if (thatDay == today) {
    return 'Сегодня';
  }
  if (thatDay == today.subtract(const Duration(days: 1))) {
    return 'Вчера';
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  return '$day.$month.$year';
}

String formatConversationStamp(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  if (thatDay == today) {
    return formatClock(local);
  }
  if (thatDay == today.subtract(const Duration(days: 1))) {
    return 'Вчера';
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month';
}

String pluralRu(int value, String one, String few, String many) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) {
    return one;
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return few;
  }
  return many;
}

String formatLastSeenLabel(DateTime? value) {
  if (value == null) {
    return 'был(а) недавно';
  }
  final now = DateTime.now();
  final difference = now.difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'был(а) только что';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return 'был(а) $minutes ${pluralRu(minutes, 'минуту', 'минуты', 'минут')} назад';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return 'был(а) $hours ${pluralRu(hours, 'час', 'часа', 'часов')} назад';
  }
  final days = difference.inDays;
  return 'был(а) $days ${pluralRu(days, 'день', 'дня', 'дней')} назад';
}

String callStageTitle(CallStage stage) {
  switch (stage) {
    case CallStage.incoming:
      return 'Входящий звонок';
    case CallStage.outgoing:
      return 'Исходящий звонок';
    case CallStage.connecting:
      return 'Подключение';
    case CallStage.connected:
      return 'Соединение установлено';
    case CallStage.missed:
      return 'Пропущенный звонок';
    case CallStage.canceled:
      return 'Звонок отменён';
    case CallStage.ended:
      return 'Звонок завершён';
    case CallStage.rejected:
      return 'Звонок отклонён';
    case CallStage.failed:
      return 'Не удалось установить соединение';
  }
}

enum _ComposerMenuAction { videoNote, voiceMessage, attachFile }

class _ComposerAttachmentDraft {
  const _ComposerAttachmentDraft({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.kind,
    this.duration = Duration.zero,
    this.isVoiceMessage = false,
    this.isVideoNote = false,
    this.isTemporaryFile = false,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final _ComposerAttachmentKind kind;
  final Duration duration;
  final bool isVoiceMessage;
  final bool isVideoNote;
  final bool isTemporaryFile;

  String get summaryLabel => switch (kind) {
    _ComposerAttachmentKind.image => 'Фото',
    _ComposerAttachmentKind.video => 'Видео',
    _ComposerAttachmentKind.audio => 'Аудио',
    _ComposerAttachmentKind.file => 'Файл',
  };

  bool get hideOriginalNameInPreview =>
      kind == _ComposerAttachmentKind.image ||
      kind == _ComposerAttachmentKind.video ||
      isVoiceMessage ||
      isVideoNote;

  String get previewTitle {
    if (isVoiceMessage) {
      return 'Голосовое сообщение';
    }
    if (isVideoNote) {
      return 'Видео кружок';
    }
    return hideOriginalNameInPreview || name.trim().isEmpty
        ? summaryLabel
        : name;
  }

  IconData get icon => switch (kind) {
    _ComposerAttachmentKind.image => Icons.image_rounded,
    _ComposerAttachmentKind.video =>
      isVideoNote ? Icons.account_circle_rounded : Icons.videocam_rounded,
    _ComposerAttachmentKind.audio => Icons.audiotrack_rounded,
    _ComposerAttachmentKind.file => Icons.insert_drive_file_rounded,
  };
}

class _SafeCameraPreview extends StatelessWidget {
  const _SafeCameraPreview(
    this.controller, {
    required this.mirror,
    this.fit = BoxFit.cover,
  });

  final CameraController controller;
  final bool mirror;
  final BoxFit fit;

  bool _isLandscapeOrientation(DeviceOrientation orientation) {
    return orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
  }

  DeviceOrientation _currentPreviewOrientation(CameraValue value) {
    if (value.isRecordingVideo && value.recordingOrientation != null) {
      return value.recordingOrientation!;
    }
    return value.previewPauseOrientation ??
        value.lockedCaptureOrientation ??
        value.deviceOrientation;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        try {
          if (!value.isInitialized || value.previewSize == null) {
            return const SizedBox.shrink();
          }
          final cameraAspectRatio = value.aspectRatio;
          if (!cameraAspectRatio.isFinite || cameraAspectRatio <= 0) {
            return const SizedBox.shrink();
          }
          final orientation = _currentPreviewOrientation(value);
          final displayAspectRatio = _isLandscapeOrientation(orientation)
              ? cameraAspectRatio
              : 1 / cameraAspectRatio;
          final previewWidth = displayAspectRatio >= 1
              ? 1000.0
              : 1000.0 * displayAspectRatio;
          final previewHeight = displayAspectRatio >= 1
              ? 1000.0 / displayAspectRatio
              : 1000.0;
          Widget preview = CameraPreview(controller);
          if (mirror) {
            preview = Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
              child: preview,
            );
          }
          return ClipRect(
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: preview,
              ),
            ),
          );
        } on CameraException {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
