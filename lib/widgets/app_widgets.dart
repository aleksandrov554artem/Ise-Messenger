part of '../main.dart';

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: appPrimaryColor,
    brightness: Brightness.light,
  );
  final baseTextTheme = ThemeData(brightness: Brightness.light).textTheme;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: baseTextTheme.apply(
      bodyColor: appTextColor,
      displayColor: appTextColor,
    ),
    scaffoldBackgroundColor: appSurfaceColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: appTextColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      systemOverlayStyle: appLightSurfaceOverlayStyle,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: appSurfaceColor,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(appControlRadius),
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(appControlRadius)),
        borderSide: BorderSide(color: appOutlineColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(appControlRadius)),
        borderSide: BorderSide(color: appOutlineColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(appControlRadius)),
        borderSide: BorderSide(color: appPrimaryColor, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(appControlRadius)),
        borderSide: BorderSide(color: appOutlineColor, width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: appPrimaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: appPrimaryColor.withValues(alpha: 0.36),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appControlRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appPrimaryColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appCompactRadius),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: appTextColor,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: appPrimaryColor,
      textColor: appTextColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      shape: RoundedRectangleBorder(),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
      textStyle: const TextStyle(
        color: appTextColor,
        fontWeight: FontWeight.w600,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: appPrimaryColor,
        disabledForegroundColor: appPrimaryColor.withValues(alpha: 0.42),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: appOutlineColor,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: appPrimaryColor,
      linearTrackColor: Color(0xFFE3EDF6),
      circularTrackColor: Colors.transparent,
    ),
  );
}

LinearGradient buildAuthGradient() {
  return const LinearGradient(
    colors: [Colors.white, Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

LinearGradient buildContactsGradient() {
  return const LinearGradient(
    colors: [Colors.white, Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

LinearGradient buildChatGradient() {
  return buildSettingsGradient();
}

LinearGradient buildSettingsGradient() {
  return const LinearGradient(
    colors: [Colors.white, Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

Widget buildGradientAppBarBackground(LinearGradient gradient) {
  return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
}

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appDarkSurfaceOverlayStyle,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: buildAuthGradient()),
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}

class AppScreenSurface extends StatelessWidget {
  const AppScreenSurface({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: const BoxDecoration(color: appSurfaceColor),
      child: child,
    );
  }
}

int _targetImageCacheDimension(BuildContext context, double logicalSize) {
  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
  return (logicalSize * pixelRatio).round().clamp(1, 4096);
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: appMutedTextColor,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 28,
    this.backgroundColor = appPrimaryColor,
    this.foregroundColor = Colors.white,
    this.fallbackIcon = Icons.person_rounded,
    this.useNameGradient = true,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData fallbackIcon;
  final bool useNameGradient;

  static const List<Color> _fallbackGradient = <Color>[
    Color(0xFF8FD0F1),
    Color(0xFF4A9FD8),
  ];

  List<Color> _resolvedGradientColors() {
    final trimmed = name.trim();
    if (!useNameGradient || trimmed.isEmpty) {
      return _fallbackGradient;
    }
    return _fallbackGradient;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl?.trim() ?? '';
    final hasImage = resolvedImageUrl.isNotEmpty;
    final imageCacheSize = _targetImageCacheDimension(context, radius * 2);
    final imageFile = resolvedImageUrl.startsWith('file://')
        ? File(Uri.parse(resolvedImageUrl).toFilePath())
        : (resolvedImageUrl.contains('://') ? null : File(resolvedImageUrl));
    final initials = initialsFor(name);
    final gradientColors = _resolvedGradientColors();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: initials.isEmpty
                ? Icon(
                    fallbackIcon,
                    color: foregroundColor,
                    size: radius * 0.86,
                  )
                : Text(
                    initials,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: radius * 0.72,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          if (hasImage)
            imageFile != null
                ? Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheSize,
                    cacheHeight: imageCacheSize,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : Image.network(
                    resolvedImageUrl,
                    headers: serverMediaHttpHeadersFor(resolvedImageUrl),
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheSize,
                    cacheHeight: imageCacheSize,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          if (hasImage && initials.isEmpty)
            Center(
              child: Icon(
                fallbackIcon,
                color: foregroundColor.withValues(alpha: 0.82),
                size: radius * 0.62,
              ),
            ),
        ],
      ),
    );
  }
}

class ContactStyleRow extends StatelessWidget {
  const ContactStyleRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    this.subtitleWidget,
    this.nameTrailing,
    this.avatarBackgroundColor = appPrimaryColor,
    this.useAvatarNameGradient = true,
    this.fallbackIcon = Icons.person_rounded,
    this.avatarBadges = const <Widget>[],
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final String subtitle;
  final Widget? subtitleWidget;
  final Widget? nameTrailing;
  final String? imageUrl;
  final Color avatarBackgroundColor;
  final bool useAvatarNameGradient;
  final IconData fallbackIcon;
  final List<Widget> avatarBadges;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        enableFeedback: false,
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
                    useNameGradient: useAvatarNameGradient,
                  ),
                  ...avatarBadges,
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          reverseDuration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutQuart,
                          switchOutCurve: Curves.easeInQuart,
                          transitionBuilder: (child, animation) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutQuart,
                              reverseCurve: Curves.easeInQuart,
                            );
                            return ClipRect(
                              child: SizeTransition(
                                sizeFactor: curved,
                                axis: Axis.horizontal,
                                alignment: Alignment.centerLeft,
                                child: FadeTransition(
                                  opacity: curved,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: nameTrailing == null
                              ? const SizedBox(
                                  key: ValueKey<String>('no_name_trailing'),
                                )
                              : Padding(
                                  key: const ValueKey<String>('name_trailing'),
                                  padding: const EdgeInsets.only(left: 7),
                                  child: nameTrailing!,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    subtitleWidget ??
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: appMutedTextColor,
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

class ContactCard extends StatelessWidget {
  const ContactCard({
    super.key,
    required this.contact,
    required this.currentUserId,
    required this.onTap,
    required this.onLongPress,
    this.draftText = '',
  });

  final ContactItem contact;
  final int? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String draftText;

  @override
  Widget build(BuildContext context) {
    final contactName = sanitizeDisplayText(
      contact.name,
      preserveLineBreaks: false,
    );
    final normalizedDraft = sanitizeDisplayText(
      draftText,
      preserveLineBreaks: false,
    ).trim();
    final hasDraft = normalizedDraft.isNotEmpty;
    final subtitle = hasDraft
        ? ''
        : buildConversationPreview(contact, currentUserId);
    final subtitleWidget = hasDraft
        ? Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Черновик: ',
                  style: TextStyle(color: appDangerColor),
                ),
                TextSpan(
                  text: normalizedDraft,
                  style: const TextStyle(color: appMutedTextColor),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          )
        : null;
    return ContactStyleRow(
      name: contactName,
      subtitle: subtitle,
      subtitleWidget: subtitleWidget,
      nameTrailing: contact.hasUnreadMessageIndicator
          ? const _UnreadMessageDot()
          : null,
      imageUrl: contact.avatarUrl,
      avatarBackgroundColor: contact.isGroup
          ? const Color(0xFF67B8D8)
          : appPrimaryColor,
      useAvatarNameGradient: !contact.isGroup,
      fallbackIcon: contact.isGroup
          ? Icons.groups_rounded
          : Icons.person_rounded,
      avatarBadges: [
        if (contact.isDirect)
          Positioned(
            right: -1,
            bottom: -1,
            child: _OnlinePresenceDot(visible: contact.isOnline),
          ),
      ],
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _OnlinePresenceDot extends StatelessWidget {
  const _OnlinePresenceDot({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuart,
      child: AnimatedScale(
        scale: visible ? 1 : 0.72,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutQuart,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF6BCB98),
            shape: BoxShape.circle,
            border: Border.all(color: appSurfaceColor, width: 2),
          ),
        ),
      ),
    );
  }
}

class _UnreadMessageDot extends StatelessWidget {
  const _UnreadMessageDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: appDangerColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      child: child,
    );
  }
}

class PreviewableAttachmentItem {
  const PreviewableAttachmentItem({
    required this.messageId,
    required this.attachment,
  });

  final int messageId;
  final MessageAttachment attachment;
}

class GroupMembersSection extends StatelessWidget {
  const GroupMembersSection({
    super.key,
    required this.members,
    required this.selectedRemovalIds,
    required this.showRemoveAction,
    required this.removeActionLabel,
    required this.onRemoveSelected,
    required this.canRemoveMember,
    required this.onToggleMember,
  });

  final List<GroupMember> members;
  final Set<int> selectedRemovalIds;
  final bool showRemoveAction;
  final String removeActionLabel;
  final VoidCallback? onRemoveSelected;
  final bool Function(GroupMember member) canRemoveMember;
  final ValueChanged<GroupMember> onToggleMember;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Участники (${members.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showRemoveAction)
                  TextButton(
                    onPressed: onRemoveSelected,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB84040),
                    ),
                    child: Text(removeActionLabel),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...members.map((member) {
            final canRemove = canRemoveMember(member);
            return _GroupMembersTile(
              member: member,
              canRemove: canRemove,
              isSelected: selectedRemovalIds.contains(member.id),
              onTap: canRemove ? () => onToggleMember(member) : null,
            );
          }),
        ],
      ),
    );
  }
}

class _GroupMembersTile extends StatelessWidget {
  const _GroupMembersTile({
    required this.member,
    required this.canRemove,
    required this.isSelected,
    required this.onTap,
  });

  final GroupMember member;
  final bool canRemove;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final memberName = sanitizeDisplayText(
      member.name,
      preserveLineBreaks: false,
    );
    final trailing = member.isOwner
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: appSoftSurfaceColor,
              borderRadius: BorderRadius.circular(appCompactRadius),
            ),
            child: Text(
              sanitizeDisplayText('Владелец', preserveLineBreaks: false),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A9FD8),
              ),
            ),
          )
        : canRemove
        ? AnimatedContainer(
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
          )
        : null;

    return ContactStyleRow(
      name: memberName,
      subtitle: member.email,
      imageUrl: member.avatarUrl,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
