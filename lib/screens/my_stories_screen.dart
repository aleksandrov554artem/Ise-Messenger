part of '../main.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  late final _StoryTimeTicker _storyTimeTicker;
  late final Listenable _screenListenable;

  @override
  void initState() {
    super.initState();
    _storyTimeTicker = _StoryTimeTicker()..start();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.storiesListenable,
      widget.controller.sessionListenable,
      _storyTimeTicker,
    ]);
    unawaited(widget.controller.loadStories());
  }

  @override
  void dispose() {
    _storyTimeTicker.dispose();
    super.dispose();
  }

  Future<void> _openStory(StoryItem story) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoryViewerScreen(controller: widget.controller, story: story),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final currentUserId = widget.controller.user?.id;
        final stories = widget.controller.activeStories
            .where((story) => story.isMine(currentUserId))
            .toList();
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appLightSurfaceOverlayStyle,
          child: Scaffold(
            appBar: AppBar(
              leading: buildPlainBackButton(context),
              titleSpacing: 20,
              title: const Text('Мои истории'),
              flexibleSpace: buildGradientAppBarBackground(
                buildSettingsGradient(),
              ),
            ),
            body: _StoriesBody(
              stories: stories,
              emptyTitle: 'Ваших историй пока нет',
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
