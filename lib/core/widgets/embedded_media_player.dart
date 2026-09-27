import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme/app_theme.dart';
import 'tiktok_web_player_stub.dart'
    if (dart.library.html) 'tiktok_web_player_web.dart';

/// يكتشف نوع الرابط الموسيقي/المرئي المُشارَك ويعرضه المناسب:
/// - رابط يوتيوب (watch أو youtu.be): يُضمَّن مباشرة داخل التطبيق
///   عبر WebView مضبوط على وضع التضمين الرسمي (youtube.com/embed).
/// - أي رابط آخر (SoundCloud، Spotify، إلخ): بطاقة تشغيل بسيطة تفتح
///   الرابط في التطبيق الخارجي المناسب عبر url_launcher، لأن تضمين
///   كل منصة موسيقى بمشغلها الخاص يحتاج SDK منفصلًا لكل منصة.
class EmbeddedMediaPlayer extends StatelessWidget {
  final String url;
  const EmbeddedMediaPlayer({super.key, required this.url});

  bool get _youtubeSearch {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return (host == 'youtube.com' || host.endsWith('.youtube.com')) &&
        uri.path == '/results' &&
        (uri.queryParameters['search_query']?.trim().isNotEmpty ?? false);
  }

  String? get _youtubeVideoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return _validId(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }
    if (host == 'youtube.com' || host.endsWith('.youtube.com') || host == 'music.youtube.com') {
      final v = _validId(uri.queryParameters['v']);
      if (v != null) return v;
      final parts = uri.pathSegments;
      if (parts.length >= 2 && (parts[0] == 'shorts' || parts[0] == 'embed' || parts[0] == 'live')) {
        return _validId(parts[1]);
      }
    }
    return null;
  }

  String? _validId(String? id) {
    if (id == null) return null;
    final v = id.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _youtubeVideoId;
    if (videoId != null) {
      return _YoutubeEmbed(videoId: videoId);
    }
    if (_youtubeSearch) return _YoutubeSearchEmbed(url: url);
    final uri = Uri.tryParse(url);
    final isTikTok =
        uri != null && (uri.host.toLowerCase() == 'tiktok.com' || uri.host.toLowerCase().endsWith('.tiktok.com'));
    if (isTikTok) {
      if (uri.path.startsWith('/search')) return _TikTokSearchEmbed(url: url);
      if (kIsWeb) return TikTokWebPlayer(url: url);
      return _TikTokEmbed(url: url);
    }
    return _ExternalMusicCard(url: url);
  }
}

class _YoutubeSearchEmbed extends StatefulWidget {
  final String url;
  const _YoutubeSearchEmbed({required this.url});
  @override
  State<_YoutubeSearchEmbed> createState() => _YoutubeSearchEmbedState();
}

class _YoutubeSearchEmbedState extends State<_YoutubeSearchEmbed> {
  WebViewController? _controller;
  String? _selectedVideoId;

  @override
  void initState() {
    super.initState();
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final id = _extractYoutubeVideoId(request.url);
          if (id != null) {
            if (mounted) setState(() => _selectedVideoId = id);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    _controller = c;
  }

  String? _extractYoutubeVideoId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return _validYoutubeId(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }
    if (host.contains('youtube.com')) {
      final watch = uri.queryParameters['v'];
      if (watch != null && watch.isNotEmpty) return _validYoutubeId(watch);
      if (uri.pathSegments.length >= 2 && (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed' || uri.pathSegments.first == 'live')) return _validYoutubeId(uri.pathSegments[1]);
    }
    return null;
  }

  String? _validYoutubeId(String? id) {
    if (id == null) return null;
    final v = id.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _selectedVideoId;
    if (id != null) return _InlineYoutubePlayer(videoId: id);
    final controller = _controller;
    if (controller == null) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 300,
        color: context.palette.surfaceHighlight,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}

class _YoutubeEmbed extends StatelessWidget {
  final String videoId;
  const _YoutubeEmbed({required this.videoId});
  @override
  Widget build(BuildContext context) => _InlineYoutubePlayer(videoId: videoId);
}

class _InlineYoutubePlayer extends StatefulWidget {
  final String videoId;
  const _InlineYoutubePlayer({required this.videoId});
  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer> {
  late final YoutubePlayerController _controller = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: true,
      // Browsers commonly block autoplay with sound; start muted so the link starts immediately,
      // while YouTube's own controls allow the user to unmute.
      mute: true,
      strictRelatedVideos: false,
    ),
  );

  // يوتيوب يستخدم WebView داخليًا، والـWebView يبقى حيًّا لحظيًا بعد
  // dispose() ريثما يُنظَّف الـplatform view. أي frame callback مجدوَل
  // منه (كتحديث لون الخلفية) قد يُستدعى بعد أن صار الـState
  // "defunct" فيحاول الوصول إلى context ويرمي "This widget has been
  // unmounted". العلم يمنع أي عمل إضافي بعد التفكيك بلا الحاجة لتغيير
  // الحزمة نفسها.
  bool _disposed = false;

  @override
  void didUpdateWidget(covariant _InlineYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_disposed) return;
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadVideoById(videoId: widget.videoId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
    );
  }
}

class _TikTokSearchEmbed extends StatefulWidget {
  final String url;
  const _TikTokSearchEmbed({required this.url});
  @override
  State<_TikTokSearchEmbed> createState() => _TikTokSearchEmbedState();
}

class _TikTokSearchEmbedState extends State<_TikTokSearchEmbed> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
          height: 300,
          color: context.palette.surfaceHighlight,
          child: WebViewWidget(controller: _controller)));
}

class _TikTokEmbed extends StatefulWidget {
  final String url;
  const _TikTokEmbed({required this.url});

  @override
  State<_TikTokEmbed> createState() => _TikTokEmbedState();
}

class _TikTokEmbedState extends State<_TikTokEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF120B1B));
    }
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: p.surfaceHighlight,
        height: 360,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _ExternalMusicCard extends StatelessWidget {
  final String url;
  const _ExternalMusicCard({required this.url});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surfaceHighlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: p.accent,
                child: Icon(Icons.music_note, color: p.background)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.textSecondary, fontSize: 12.5),
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
