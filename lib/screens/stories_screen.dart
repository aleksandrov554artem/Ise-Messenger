part of '../main.dart';

enum _StoriesMenuAction { addStory, myStories }

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  late final _StoryTimeTicker _storyTimeTicker;
  late final Listenable _screenListenable;
  late final VoidCallback _storiesSeenListener;

  @override
  void initState() {
    super.initState();
    _storyTimeTicker = _StoryTimeTicker()..start();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.storiesListenable,
      widget.controller.sessionListenable,
      _storyTimeTicker,
    ]);
    _storiesSeenListener = () {
      unawaited(widget.controller.markStoriesSeen());
    };
    widget.controller.storiesListenable.addListener(_storiesSeenListener);
    unawaited(_refreshStoriesAndMarkSeen());
  }

  @override
  void dispose() {
    widget.controller.storiesListenable.removeListener(_storiesSeenListener);
    _storyTimeTicker.dispose();
    super.dispose();
  }

  Future<void> _refreshStoriesAndMarkSeen() async {
    try {
      await widget.controller.loadStories();
    } finally {
      await widget.controller.markStoriesSeen();
    }
  }

  Future<void> _openCreateStory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryCreateScreen(controller: widget.controller),
      ),
    );
    await widget.controller.loadStories();
  }

  Future<void> _openStory(StoryItem story) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoryViewerScreen(controller: widget.controller, story: story),
      ),
    );
  }

  Future<void> _openMyStories() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyStoriesScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _handleStoriesMenuAction(_StoriesMenuAction action) async {
    switch (action) {
      case _StoriesMenuAction.addStory:
        await _openCreateStory();
      case _StoriesMenuAction.myStories:
        await _openMyStories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final stories = widget.controller.activeStories;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appLightSurfaceOverlayStyle,
          child: Scaffold(
            appBar: AppBar(
              leading: buildPlainBackButton(context),
              titleSpacing: 20,
              title: const Text('Истории'),
              actions: [
                PopupMenuButton<_StoriesMenuAction>(
                  tooltip: 'Меню',
                  icon: const Icon(Icons.more_vert_rounded),
                  color: Colors.white,
                  onSelected: (action) =>
                      unawaited(_handleStoriesMenuAction(action)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _StoriesMenuAction.addStory,
                      child: Row(
                        children: [
                          Icon(Icons.add_rounded, color: appPrimaryColor),
                          SizedBox(width: 12),
                          Text('Записать историю'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _StoriesMenuAction.myStories,
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: appPrimaryColor),
                          SizedBox(width: 12),
                          Text('Мои истории'),
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
            body: _StoriesBody(
              stories: stories,
              emptyTitle: 'Историй пока нет',
              onOpenStory: _openStory,
              onLongPressStory: (story) => unawaited(
                _showDeleteStorySheet(context, widget.controller, story),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoriesBody extends StatelessWidget {
  const _StoriesBody({
    required this.stories,
    required this.emptyTitle,
    required this.onOpenStory,
    this.onLongPressStory,
  });

  final List<StoryItem> stories;
  final String emptyTitle;
  final ValueChanged<StoryItem> onOpenStory;
  final ValueChanged<StoryItem>? onLongPressStory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildSettingsGradient()),
      child: SafeArea(
        child: Container(
          color: appSurfaceColor,
          child: stories.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    appEmptyStateTopSpacing,
                    20,
                    24,
                  ),
                  children: [
                    AppSectionCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 58,
                            color: appMutedTextColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            emptyTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720
                        ? 4
                        : constraints.maxWidth >= 520
                        ? 3
                        : 2;
                    return Scrollbar(
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: stories.length,
                        itemBuilder: (context, index) {
                          final story = stories[index];
                          return StoryCard(
                            story: story,
                            onTap: () => onOpenStory(story),
                            onLongPress: onLongPressStory == null
                                ? null
                                : () => onLongPressStory!(story),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class StoryCard extends StatefulWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.onTap,
    this.onLongPress,
  });

  final StoryItem story;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  bool _previewReady = false;

  @override
  void didUpdateWidget(covariant StoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.id != widget.story.id ||
        oldWidget.story.mediaUrl != widget.story.mediaUrl) {
      _previewReady = false;
    }
  }

  void _markPreviewReady() {
    if (_previewReady || !mounted) {
      return;
    }
    setState(() {
      _previewReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        enableFeedback: false,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _StoryVideoPreview(
                url: widget.story.mediaUrl,
                recordedWithFrontCamera:
                    widget.story.wasRecordedWithFrontCamera,
                onReady: _markPreviewReady,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.76),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                ),
              ),
              if (!_previewReady)
                const Center(child: _PureWhiteProgressIndicator()),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    ProfileAvatar(
                      name: widget.story.authorName,
                      imageUrl: widget.story.authorAvatarUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.story.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            formatStoryTime(widget.story.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showDeleteStorySheet(
  BuildContext context,
  MessengerController controller,
  StoryItem story,
) async {
  if (!story.isMine(controller.user?.id)) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      return SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_rounded, color: appPrimaryColor),
          title: const Text('Удалить историю'),
          onTap: () {
            Navigator.of(sheetContext).pop();
            unawaited(_deleteStoryFromSheet(context, controller, story));
          },
        ),
      );
    },
  );
}

Future<void> _deleteStoryFromSheet(
  BuildContext context,
  MessengerController controller,
  StoryItem story,
) async {
  try {
    await controller.deleteStory(story.id);
    if (!context.mounted) {
      return;
    }
    showSuccessToast(context, 'История удалена');
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showError(context, error, fallbackMessage: 'Не удалось удалить историю');
  }
}
