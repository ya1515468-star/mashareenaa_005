// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class TikTokWebPlayer extends StatefulWidget {
  final String url;
  const TikTokWebPlayer({super.key, required this.url});

  @override
  State<TikTokWebPlayer> createState() => _TikTokWebPlayerState();
}

class _TikTokWebPlayerState extends State<TikTokWebPlayer> {
  late final String _viewType;
  bool _registered = false;

  String? _videoId() {
    final match = RegExp(r'/video/(\d+)').firstMatch(widget.url);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    _viewType =
        'tiktok-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    final id = _videoId();
    if (id == null) return;
    final frame = html.IFrameElement()
      ..src =
          'https://www.tiktok.com/player/v1/$id?music_info=1&description=1&controls=1&autoplay=0'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allow', 'autoplay; fullscreen')
      ..setAttribute('allowfullscreen', 'true');
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => frame);
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return const Center(
          child: Text('رابط TikTok غير صالح',
              style: TextStyle(color: Colors.white70)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
