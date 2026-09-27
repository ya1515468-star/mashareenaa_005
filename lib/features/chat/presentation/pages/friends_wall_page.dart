import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/embedded_media_player.dart';

final platformWallProductsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  var disposed = false;

  Future<void> load() async {
    try {
      final rows = await client
          .from('platform_wall_products')
          .select('*')
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      if (!disposed) {
        controller.add(List<Map<String, dynamic>>.from(rows));
      }
    } catch (e, st) {
      if (!disposed) controller.addError(e, st);
    }
  }

  unawaited(load());
  final channel = client.channel('platform-wall-products-live')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'platform_wall_products',
      callback: (_) => unawaited(load()),
    )
    ..subscribe();

  ref.onDispose(() {
    disposed = true;
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });
  return controller.stream;
});

class FriendsWallPage extends ConsumerStatefulWidget {
  const FriendsWallPage({super.key});

  @override
  ConsumerState<FriendsWallPage> createState() => _FriendsWallPageState();
}

class _FriendsWallPageState extends ConsumerState<FriendsWallPage> {
  bool _isPlatformOwner = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOwnerState());
  }

  Future<void> _loadOwnerState() async {
    try {
      final result = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) {
        setState(() {
          _isPlatformOwner = result == true;
        });
      }
    } catch (_) {
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? product]) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final sku = TextEditingController(text: product?['sku']?.toString() ?? '');
    final details = TextEditingController(text: product?['details']?.toString() ?? '');
    final description = TextEditingController(text: product?['description']?.toString() ?? '');
    final quantity = TextEditingController(text: '${product?['quantity'] ?? 0}');
    final points = TextEditingController(text: '${product?['price_points'] ?? 0}');
    final gems = TextEditingController(text: '${product?['price_gems'] ?? 0}');
    final images = TextEditingController(text: ((product?['image_urls'] is List) ? (product!['image_urls'] as List).whereType<String>().join('\n') : ''));
    final video = TextEditingController(text: product?['video_url']?.toString() ?? '');
    final sort = TextEditingController(text: '${product?['sort_order'] ?? 0}');
    final starts = TextEditingController(text: product?['starts_at']?.toString() ?? '');
    final ends = TextEditingController(text: product?['ends_at']?.toString() ?? '');
    bool active = product?['is_active'] != false;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'إضافة منتج إلى حائط المنتجات' : 'تعديل المنتج'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج')),
                  TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU')),
                  TextField(controller: details, decoration: const InputDecoration(labelText: 'التفاصيل')),
                  TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
                  TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المخزون')),
                  Row(children: [
                    Expanded(child: TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالنقاط'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالجواهر'))),
                  ]),
                  TextField(controller: images, maxLines: 4, decoration: const InputDecoration(labelText: 'روابط الصور — رابط في كل سطر')),
                  TextField(controller: video, decoration: const InputDecoration(labelText: 'رابط الفيديو (اختياري)')),
                  Row(children: [
                    Expanded(child: TextField(controller: starts, decoration: const InputDecoration(labelText: 'يبدأ في ISO (اختياري)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: ends, decoration: const InputDecoration(labelText: 'ينتهي في ISO (اختياري)'))),
                  ]),
                  TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتيب العرض')),
                  SwitchListTile(value: active, onChanged: (v) => setDialogState(() => active = v), title: const Text('منشور ونشط')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton.icon(
              onPressed: saving ? null : () async {
                final n = int.tryParse(quantity.text.trim());
                final pp = int.tryParse(points.text.trim());
                final pg = int.tryParse(gems.text.trim());
                final so = int.tryParse(sort.text.trim());
                if (name.text.trim().isEmpty || sku.text.trim().isEmpty || n == null || pp == null || pg == null || so == null || (pp == 0 && pg == 0) || n < 0 || pp < 0 || pg < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الاسم وSKU والمخزون والأسعار.')));
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final urls = images.text.split(RegExp(r'[\n,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final params = {
                    if (product != null) 'p_id': product['id'],
                    'p_name': name.text.trim(),
                    'p_sku': sku.text.trim(),
                    'p_details': details.text.trim(),
                    'p_description': description.text.trim(),
                    'p_quantity': n,
                    'p_price_points': pp,
                    'p_price_gems': pg,
                    'p_image_urls': urls,
                    'p_video_url': video.text.trim(),
                    'p_starts_at': starts.text.trim().isEmpty ? null : starts.text.trim(),
                    'p_ends_at': ends.text.trim().isEmpty ? null : ends.text.trim(),
                    'p_is_active': active,
                    'p_sort_order': so,
                  };
                  if (product == null) {
                    await Supabase.instance.client.rpc('platform_wall_create_product', params: params);
                  } else {
                    await Supabase.instance.client.rpc('platform_wall_update_product', params: params);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ الخادمي: $e')));
                }
              },
              icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: Text(saving ? 'جارٍ الحفظ' : 'حفظ خادمي'),
            ),
          ],
        ),
      ),
    );
    name.dispose(); sku.dispose(); details.dispose(); description.dispose(); quantity.dispose(); points.dispose(); gems.dispose(); images.dispose(); video.dispose(); sort.dispose(); starts.dispose(); ends.dispose();
    if (saved == true && mounted) ref.invalidate(platformWallProductsProvider);
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('سيتم حذف «${product['name'] ?? 'منتج'}» نهائيًا من الحائط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc('platform_wall_delete_product', params: {'p_id': product['id']});
      if (mounted) ref.invalidate(platformWallProductsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف الخادمي: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حائط المنتجات'),
        centerTitle: true,
        actions: [
          if (_isPlatformOwner) IconButton(tooltip: 'إضافة منتج', onPressed: () => _openEditor(), icon: const Icon(Icons.add_business_rounded)),
          IconButton(tooltip: 'تحديث', onPressed: () => ref.invalidate(platformWallProductsProvider), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ref.watch(platformWallProductsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _StateMessage(
              title: 'تعذر تحميل حائط المنتجات',
              details: e.toString(),
              icon: Icons.cloud_off_rounded,
            ),
            data: (products) {
              if (products.isEmpty) {
                return const _StateMessage(
                  title: 'لا توجد منتجات منشورة حاليًا',
                  details:
                      'المنتجات المنشورة من مالك المنصة ستظهر هنا تلقائيًا.',
                  icon: Icons.storefront_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(platformWallProductsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _ProductCard(product: products[i], isOwner: _isPlatformOwner, onEdit: () => _openEditor(products[i]), onDelete: () => _deleteProduct(products[i])),
                ),
              );
            },
          ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ProductCard({required this.product, this.isOwner = false, this.onEdit, this.onDelete});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  final _client = Supabase.instance.client;
  bool _liked = false;
  int _likes = 0;
  int _comments = 0;
  bool _loading = true;
  bool _buying = false;

  String get _id => widget.product['id']?.toString() ?? '';
  String get _name => widget.product['name']?.toString() ?? 'منتج';
  String get _details => widget.product['details']?.toString() ?? '';
  String get _description => widget.product['description']?.toString() ?? '';
  String get _currencyLabel {
    final points = int.tryParse('${widget.product['price_points'] ?? 0}') ?? 0;
    final gems = int.tryParse('${widget.product['price_gems'] ?? 0}') ?? 0;
    if (points > 0 && gems > 0) return '$points نقطة • $gems جوهرة';
    if (gems > 0) return '$gems جوهرة';
    return '$points نقطة';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadEngagement());
  }

  Future<void> _loadEngagement() async {
    final uid = _client.auth.currentUser?.id;
    try {
      final likes = await _client
          .from('platform_wall_product_likes')
          .select('user_id')
          .eq('product_id', _id);
      final comments = await _client
          .from('platform_wall_product_comments')
          .select('id')
          .eq('product_id', _id);
      if (!mounted) return;
      setState(() {
        _likes = likes.length;
        _comments = comments.length;
        _liked = uid != null &&
            likes.any((row) => row['user_id']?.toString() == uid);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || _id.isEmpty) return;
    try {
      final result = await _client.rpc('platform_wall_toggle_like', params: {
        'p_product_id': _id,
      });
      if (!mounted) return;
      final oldLiked = _liked;
      final next = result == true;
      setState(() {
        _liked = next;
        _likes += next == oldLiked ? 0 : (next ? 1 : -1);
      });
      await _loadEngagement();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الإعجاب: $e')),
      );
    }
  }

  Future<void> _comment() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || _id.isEmpty) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعليق على المنتج'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'اكتب تعليقك...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('نشر')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _client.from('platform_wall_product_comments').insert({
        'product_id': _id,
        'user_id': uid,
        'body': value,
      });
      if (mounted) setState(() => _comments += 1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نشر التعليق: $e')),
      );
    }
  }

  Future<void> _buy() async {
    if (_buying || _id.isEmpty) return;
    setState(() => _buying = true);
    final points = int.tryParse('${widget.product['price_points'] ?? 0}') ?? 0;
    final currency = points > 0 ? 'points' : 'gems';
    try {
      await _client.rpc('platform_wall_purchase_product', params: {
        'p_product_id': _id,
        'p_quantity': 1,
        'p_currency': currency,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنفيذ شراء المنتج خادميًا')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر شراء المنتج: $e')),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  List<String> _images() {
    final raw = widget.product['image_urls'];
    if (raw is List) {
      return raw.whereType<String>().where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final images = _images();
    final quantity = int.tryParse('${widget.product['quantity'] ?? 0}') ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (images.isNotEmpty)
            _AnimatedProductHero(images: images, title: _name)
          else
            Container(
                height: 190,
                color: p.surfaceHighlight,
                child: const Icon(Icons.inventory_2_outlined, size: 50)),
          if ((widget.product['video_url']?.toString().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: EmbeddedMediaPlayer(
                  url: widget.product['video_url'].toString()),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  if (widget.isOwner) ...[
                    IconButton(tooltip: 'تعديل', onPressed: widget.onEdit, icon: const Icon(Icons.edit_rounded, size: 20)),
                    IconButton(tooltip: 'حذف', onPressed: widget.onDelete, icon: const Icon(Icons.delete_forever_rounded, size: 20)),
                  ],
                ],
              ),
              if (_details.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(_details, style: TextStyle(color: p.textSecondary))
              ],
              if (_description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(_description, maxLines: 4, overflow: TextOverflow.ellipsis)
              ],
              const SizedBox(height: 10),
              Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(_currencyLabel)),
                    if (quantity > 0) Chip(label: Text('المتوفر: $quantity')),
                    if (widget.product['starts_at'] != null ||
                        widget.product['ends_at'] != null)
                      _ExpiryChip(
                        startsAt: DateTime.tryParse('${widget.product['starts_at'] ?? ''}'),
                        endsAt: DateTime.tryParse('${widget.product['ends_at'] ?? ''}'),
                      ),
                  ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('$_likes إعجاب • $_comments تعليق',
                    style: TextStyle(color: p.textMuted, fontSize: 12)),
                const Spacer(),
                IconButton(
                    onPressed: _loading ? null : _toggleLike,
                    icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? p.accent : p.textSecondary)),
                IconButton(
                    onPressed: _comment,
                    icon: const Icon(Icons.mode_comment_outlined)),
                FilledButton.icon(
                    onPressed: _buying ? null : _buy,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(_buying ? 'جارٍ...' : 'شراء')),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}


class _AnimatedProductHero extends StatefulWidget {
  final List<String> images;
  final String title;
  const _AnimatedProductHero({required this.images, required this.title});
  @override
  State<_AnimatedProductHero> createState() => _AnimatedProductHeroState();
}

class _AnimatedProductHeroState extends State<_AnimatedProductHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: PageView.builder(
        itemCount: widget.images.length,
        itemBuilder: (_, i) => AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.0 + _controller.value * .018,
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 42),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha:.70), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                left: 14,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                    const Icon(Icons.swipe_rounded, color: Colors.white70, size: 18),
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

class _ExpiryChip extends StatelessWidget {
  final DateTime? startsAt;
  final DateTime? endsAt;
  const _ExpiryChip({this.startsAt, this.endsAt});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (startsAt != null && startsAt!.isAfter(now)) {
      return Chip(avatar: const Icon(Icons.schedule, size: 16), label: Text('يبدأ خلال ${_label(startsAt!.difference(now))}'));
    }
    if (endsAt == null) return const SizedBox.shrink();
    final diff = endsAt!.difference(now);
    if (diff.isNegative) return const Chip(label: Text('منتهٍ'));
    return Chip(avatar: const Icon(Icons.timer_outlined, size: 16), label: Text('ينتهي خلال ${_label(diff)}'));
  }
  String _label(Duration d) {
    if (d.inDays > 0) return '${d.inDays} يوم';
    if (d.inHours > 0) return '${d.inHours} ساعة';
    return '${math.max(1, d.inMinutes)} دقيقة';
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String details;
  final IconData icon;
  const _StateMessage(
      {required this.title, required this.details, required this.icon});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(details,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
