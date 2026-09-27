import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/garment_sector_provider.dart';

/// قطاع الألبسة الموحّد — ثلاثة تبويبات:
///   القطاعات · المنشآت · إعلانات الخدمات
///
/// كل البيانات من نظام `garment_*` الخادمي (24 قطاعًا، كتالوج خدمات،
/// رسوم نشر يحدّدها المالك). حلّ محلّ نظام `factory_*` الموازي الذي
/// حُذف لأنه كان يكرّر هذا ويشتّت البيانات.
///
/// اللغة البصرية مطابقة لسوق المنتجين: خلفية سوداء، ذهبي #FFD700،
/// جسيمات متحركة، وشرائح متوهّجة عند الاختيار.
class GarmentSectorPage extends ConsumerStatefulWidget {
  const GarmentSectorPage({super.key});

  @override
  ConsumerState<GarmentSectorPage> createState() => _GarmentSectorPageState();
}

class _GarmentSectorPageState extends ConsumerState<GarmentSectorPage>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);
  static const _amber = Color(0xFFFFA500);

  late final TabController _tabs;
  late final AnimationController _particleController;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  String? _sector;
  String _search = '';
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _particleController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      final r = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) setState(() => _isOwner = r == true);
    } catch (_) {
      // ليست حالة خطأ — غير المالك يرى الصفحة كاملة عدا أدوات الإدارة
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _GarmentParticlePainter(_particleController.value),
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  _tabBar(),
                  _sectorBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _SectorsTab(sector: _sector, glow: _glowAnim),
                        _BusinessesTab(
                            sector: _sector,
                            search: _search,
                            isOwner: _isOwner),
                        _ServiceAdsTab(sector: _sector, isOwner: _isOwner),
                        const _MyBusinessesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'garment_sector_fab',
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('أضف منشأتك',
              style: TextStyle(fontWeight: FontWeight.w900)),
          onPressed: _openPublishSheet,
        ),
      ),
    );
  }

  // لا يوجد AppBar في هذه الصفحة (كلها Scaffold مخصَّص بخلفية سوداء
  // وجسيمات متحركة)، فلم يكن فيها أي زر رجوع — لا شريط نظام يوفّره
  // تلقائيًا. هذا الزر يستعمل Navigator مباشرة، بلا انتظار AppBar.
  Widget _backButton(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white70, size: 18),
        ),
      );

  // زر "نشر إعلان" كان مخفيًا كزر عائم داخل تبويب واحد فقط، فلا يراه من
  // يفتح القطاع على التبويب الأول. صار في الترويسة، ظاهرًا دائمًا.
  Widget _publishAdButton(BuildContext context) => GestureDetector(
        onTap: () async {
          _tabs.animateTo(2);
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _PublishServiceAdSheet(defaultSector: _sector),
          );
          if (ok == true) ref.invalidate(garmentServiceAdsProvider(_sector));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.campaign_rounded, size: 16, color: Colors.black),
            SizedBox(width: 4),
            Text('نشر إعلان',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Builder(builder: _backButton),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) => Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [_gold, _amber]),
                  boxShadow: [
                    BoxShadow(
                        color: _gold.withValues(alpha: _glowAnim.value * .55),
                        blurRadius: 14),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.checkroom_rounded,
                  color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قطاع الألبسة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  Text('المصانع · الورشات · الخدمات · التوريد',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Builder(builder: _publishAdButton),
            IconButton(
              tooltip: 'بحث',
              icon: const Icon(Icons.search_rounded, color: _gold),
              onPressed: _openSearch,
            ),
          ],
        ),
      );

  Widget _tabBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [_gold, _amber]),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontSize: 12.5),
          tabs: const [
            Tab(text: 'القطاعات', height: 40),
            Tab(text: 'المنشآت', height: 40),
            Tab(text: 'إعلانات الخدمات', height: 40),
            Tab(text: 'منشآتي', height: 40),
          ],
        ),
      );

  Widget _sectorBar() {
    final sectors = ref.watch(garmentSectorsProvider);
    return sectors.when(
      loading: () => const SizedBox(height: 46),
      error: (_, __) => const SizedBox(height: 46),
      data: (list) => SizedBox(
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final s = isAll ? null : list[i - 1];
            final key = isAll ? null : s!['sector_key']?.toString();
            final selected = _sector == key;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => GestureDetector(
                  onTap: () => setState(() => _sector = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: selected
                          ? const LinearGradient(colors: [_gold, _amber])
                          : null,
                      color: selected ? null : Colors.white10,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: _gold.withValues(
                                      alpha: _glowAnim.value * .5),
                                  blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isAll ? '🧵' : (s!['icon_emoji']?.toString() ?? '🏭'),
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          isAll ? 'الكل' : (s!['name_ar']?.toString() ?? ''),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: selected ? Colors.black : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final ctrl = TextEditingController(text: _search);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D0D1A),
          title: const Text('بحث في قطاع الألبسة'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'اسم المنشأة أو الخدمة أو المدينة…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (s) => Navigator.pop(ctx, s),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('مسح')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('بحث',
                    style: TextStyle(color: Colors.black))),
          ],
        ),
      ),
    );
    if (v != null && mounted) {
      setState(() => _search = v.trim());
      _tabs.animateTo(1);
    }
  }

  void _openPublishSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PublishBusinessSheet(),
    );
  }
}

// ═══ تبويب القطاعات ══════════════════════════════════════════════════
class _SectorsTab extends ConsumerWidget {
  final String? sector;
  final Animation<double> glow;
  const _SectorsTab({required this.sector, required this.glow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectors = ref.watch(garmentSectorsProvider);
    final catalog = ref.watch(garmentServiceCatalogProvider);

    return sectors.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(garmentSectorsProvider)),
      data: (list) {
        final shown =
            sector == null ? list : list.where((s) => s['sector_key'] == sector).toList();
        final services = catalog.valueOrNull ?? const [];

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final s = shown[i];
            final key = s['sector_key']?.toString();
            final count =
                services.where((c) => c['sector_key'] == key).length;
            return AnimatedBuilder(
              animation: glow,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
                  ),
                  border: Border.all(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: .15 + glow.value * .2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s['icon_emoji']?.toString() ?? '🏭',
                        style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(s['name_ar']?.toString() ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$count خدمة',
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══ تبويب المنشآت ═══════════════════════════════════════════════════
class _BusinessesTab extends ConsumerWidget {
  final String? sector;
  final String search;
  final bool isOwner;
  const _BusinessesTab(
      {required this.sector, required this.search, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = GarmentDirectoryArgs(sectorKey: sector, search: search);
    final dir = ref.watch(garmentDirectoryProvider(args));

    return dir.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(garmentDirectoryProvider(args))),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.storefront_rounded,
            title: 'لا منشآت منشورة بعد',
            hint: 'كن أول من يعرض منشأته في هذا القطاع',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _BusinessCard(business: list[i]),
        );
      },
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> business;
  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    final cover = business['cover_url']?.toString() ?? '';
    final logo = business['logo_url']?.toString() ?? '';
    final city = business['city']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
        ),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(cover,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      logo.isNotEmpty ? NetworkImage(logo) : null,
                  child: logo.isEmpty
                      ? const Icon(Icons.factory_rounded,
                          color: Color(0xFFFFD700), size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                                business['business_name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900)),
                          ),
                          if (business['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: Color(0xFF38BDF8)),
                          ],
                        ],
                      ),
                      if (city.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.place_rounded,
                              size: 12, color: Color(0xFF34D399)),
                          const SizedBox(width: 3),
                          Text(city,
                              style: const TextStyle(
                                  color: Color(0xFF34D399), fontSize: 11.5)),
                        ]),
                      if (business['description']
                              ?.toString()
                              .isNotEmpty ==
                          true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(business['description'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (business['min_order_qty'] != null)
                  _Tag('أقل طلب: ${business['min_order_qty']}'),
                if (business['capacity_per_month'] != null)
                  _Tag('الطاقة: ${business['capacity_per_month']}/شهر'),
                if (business['established_year'] != null)
                  _Tag('تأسّست ${business['established_year']}'),
                if (business['phone']?.toString().isNotEmpty == true)
                  _Tag('📞 ${business['phone']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ تبويب إعلانات الخدمات ═══════════════════════════════════════════
class _ServiceAdsTab extends ConsumerWidget {
  final String? sector;
  final bool isOwner;
  const _ServiceAdsTab({required this.sector, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(garmentServiceAdsProvider(sector));

    return Stack(
      children: [
        ads.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          error: (e, _) => _ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(garmentServiceAdsProvider(sector))),
          data: (list) {
            if (list.isEmpty) {
              return const _EmptyState(
                icon: Icons.campaign_rounded,
                title: 'لا إعلانات خدمات',
                hint: 'انشر خدمتك ليصلك طلبات من كل القطاع',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ServiceAdCard(
                ad: list[i],
                isOwner: isOwner,
                onModerate: (status) async {
                  await GarmentActions.setAdStatus(
                      list[i]['id'].toString(), status);
                  ref.invalidate(garmentServiceAdsProvider(sector));
                },
              ),
            );
          },
        ),
        // publishServiceAd كانت موجودة في المزوّد وموصولة بالخادم منذ
        // إصلاح p_request_id، لكن بلا أي زر أو نموذج يستدعيها — فتعذّر
        // النشر كليًا. هذا الزر يفتح النموذج الناقص.
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton.extended(
            heroTag: 'publish_service_ad',
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('نشر خدمة',
                style: TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () => _openPublishSheet(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _openPublishSheet(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublishServiceAdSheet(defaultSector: sector),
    );
    if (ok == true) ref.invalidate(garmentServiceAdsProvider(sector));
  }
}

// القطاعات والخدمات تُقرأ من الخادم (garment_sectors /
// get_garment_service_catalog) لا من قوائم مثبّتة: القائمة المثبّتة
// السابقة كانت تضع قطاعًا افتراضيًا 'garment' غير موجود على الخادم،
// فيُرفض كل نشر لم يغيّر فيه المستخدم القطاع يدويًا.
class _PublishServiceAdSheet extends ConsumerStatefulWidget {
  final String? defaultSector;
  const _PublishServiceAdSheet({this.defaultSector});
  @override
  ConsumerState<_PublishServiceAdSheet> createState() =>
      _PublishServiceAdSheetState();
}

class _PublishServiceAdSheetState
    extends ConsumerState<_PublishServiceAdSheet> {

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  String? _service;
  late String? _sector = widget.defaultSector;
  String _currency = 'points';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _service == null || _sector == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('اختر الخدمة والقطاع واكتب عنوانًا')));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await GarmentActions.publishServiceAd(
        serviceKey: _service!,
        sectorKey: _sector!,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        city: _city.text.trim(),
        phone: _phone.text.trim(),
        publicationCurrency: _currency,
      );
      if (mounted) Navigator.pop(context, true);
      messenger?.showSnackBar(const SnackBar(
          content: Text('نُشر الإعلان'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      final s = e.toString();
      messenger?.showSnackBar(SnackBar(
        content: Text(s.contains('INSUFFICIENT')
            ? 'رصيدك لا يكفي لرسوم النشر.'
            : s.contains('QUOTA')
                ? 'استنفدت حصة النشر لعضويتك.'
                : s.contains('ACCESS_REVOKED')
                    ? 'أوقف المالك صلاحية نشر الخدمات لحسابك.'
                    : s.contains('INVALID_SERVICE')
                        ? 'هذه الخدمة لا تتبع القطاع المختار.'
                        : 'تعذّر النشر: $s'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF120A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Text('نشر إعلان خدمة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Builder(builder: (context) {
                  // الخادم يشترط أن تنتمي الخدمة للقطاع المختار
                  // (garment_service_catalog.sector_key) وإلا INVALID_SERVICE،
                  // فتُعرض فقط خدمات القطاع المختار.
                  final services = (ref.watch(garmentServiceCatalogProvider)
                              .valueOrNull ??
                          const <Map<String, dynamic>>[])
                      .where((e) =>
                          _sector == null ||
                          e['sector_key']?.toString() == _sector)
                      .toList();
                  final keys = services
                      .map((e) => e['service_key']?.toString() ?? '')
                      .where((k) => k.isNotEmpty)
                      .toSet();
                  return DropdownButtonFormField<String>(
                    // initialValue خارج القائمة يرمي assertion — نتحقق أولًا
                    initialValue: keys.contains(_service) ? _service : null,
                    dropdownColor: const Color(0xFF1A0F33),
                    decoration:
                        const InputDecoration(labelText: 'نوع الخدمة'),
                    items: [
                      for (final e in services)
                        if ((e['service_key']?.toString() ?? '').isNotEmpty)
                          DropdownMenuItem(
                            value: e['service_key'].toString(),
                            child: Text(e['name_ar']?.toString() ??
                                e['service_key'].toString()),
                          ),
                    ],
                    onChanged: (v) => setState(() => _service = v),
                  );
                }),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final sectors =
                      ref.watch(garmentSectorsProvider).valueOrNull ??
                          const <Map<String, dynamic>>[];
                  final keys = sectors
                      .map((e) => e['sector_key']?.toString() ?? '')
                      .toSet();
                  return DropdownButtonFormField<String>(
                    initialValue: keys.contains(_sector) ? _sector : null,
                    dropdownColor: const Color(0xFF1A0F33),
                    decoration: const InputDecoration(labelText: 'القطاع'),
                    items: [
                      for (final e in sectors)
                        DropdownMenuItem(
                          value: e['sector_key'].toString(),
                          child: Text(e['name_ar']?.toString() ??
                              e['sector_key'].toString()),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _sector = v;
                      _service = null;
                    }),
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
                const SizedBox(height: 10),
                TextField(
                    controller: _desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'التفاصيل')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'المدينة')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'الهاتف')),
                  ),
                ]),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'points', label: Text('نقاط ⭐')),
                    ButtonSegment(value: 'gems', label: Text('جواهر 💎')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (s) =>
                      setState(() => _currency = s.first),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('نشر',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900)),
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

class _ServiceAdCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final bool isOwner;
  final Future<void> Function(String status) onModerate;
  const _ServiceAdCard(
      {required this.ad, required this.isOwner, required this.onModerate});

  @override
  Widget build(BuildContext context) {
    final price = (ad['price_minor_units'] as num?)?.toInt() ?? 0;
    final status = ad['status']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
        ),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ad['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
              ),
              if (price > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                      '${(price / 100).toStringAsFixed(2)} ${ad['currency'] ?? 'USD'}',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (ad['description']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(ad['description'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ad['city']?.toString().isNotEmpty == true)
                _Tag('📍 ${ad['city']}'),
              if (ad['unit']?.toString().isNotEmpty == true)
                _Tag('الوحدة: ${ad['unit']}'),
              if (ad['min_qty'] != null) _Tag('أقل كمية: ${ad['min_qty']}'),
              if (ad['phone']?.toString().isNotEmpty == true)
                _Tag('📞 ${ad['phone']}'),
            ],
          ),
          if (isOwner) ...[
            const Divider(height: 18, color: Colors.white12),
            Row(
              children: [
                Text('الحالة: $status',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const Spacer(),
                TextButton(
                  onPressed: () => onModerate('approved'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF34D399),
                      visualDensity: VisualDensity.compact),
                  child: const Text('قبول', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => onModerate('rejected'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      visualDensity: VisualDensity.compact),
                  child: const Text('رفض', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══ ورقة نشر منشأة ══════════════════════════════════════════════════
class _PublishBusinessSheet extends ConsumerStatefulWidget {
  const _PublishBusinessSheet();

  @override
  ConsumerState<_PublishBusinessSheet> createState() =>
      _PublishBusinessSheetState();
}

class _PublishBusinessSheetState
    extends ConsumerState<_PublishBusinessSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  String? _sector;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectors = ref.watch(garmentSectorsProvider).valueOrNull ?? const [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أضف منشأتك',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _field(_name, 'اسم المنشأة *'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _sector,
                dropdownColor: const Color(0xFF0D0D1A),
                decoration: const InputDecoration(
                    labelText: 'القطاع *',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: sectors
                    .map((s) => DropdownMenuItem(
                          value: s['sector_key']?.toString(),
                          child: Text(
                              '${s['icon_emoji'] ?? ''} ${s['name_ar'] ?? ''}',
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _sector = v),
              ),
              const SizedBox(height: 10),
              _field(_desc, 'الوصف', lines: 3),
              const SizedBox(height: 10),
              _field(_city, 'المدينة'),
              const SizedBox(height: 10),
              _field(_phone, 'الهاتف'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700)),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('حفظ',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                  'الحفظ لا يَنشر. النشر يتم لاحقًا ويخصم رسوم النشر التي يحدّدها المالك.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) =>
      TextField(
        controller: c,
        maxLines: lines,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true),
      );

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _sector == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الاسم والقطاع مطلوبان'),
          backgroundColor: Color(0xFFDC2626)));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await GarmentActions.upsertBusiness(
        businessName: _name.text.trim(),
        sectorKey: _sector!,
        description: _desc.text.trim(),
        city: _city.text.trim(),
        phone: _phone.text.trim(),
      );
      ref.invalidate(myGarmentBusinessesProvider);
      nav.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('حُفظت المنشأة'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
          content: Text('تعذّر الحفظ: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }
}


// ═══ تبويب منشآتي — الإنشاء لا يَنشر، فهنا يتم النشر ═══════════════
//
// المنشأة المحفوظة تبقى is_published=false ولا يعرضها دليل المنشآت،
// فبدت وكأنها ضاعت بعد الحفظ. هذا التبويب يعرض منشآت العضو مهما كانت
// حالتها، ويتيح نشرها — والنشر يخصم رسوم النشر التي يحدّدها المالك.
class _MyBusinessesTab extends ConsumerWidget {
  const _MyBusinessesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myGarmentBusinessesProvider);
    final fees = ref.watch(garmentPublicationFeesProvider).valueOrNull ?? const [];

    return mine.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myGarmentBusinessesProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.add_business_rounded,
            title: 'لم تنشئ منشأة بعد',
            hint: 'اضغط «أضف منشأتك» في الأسفل',
          );
        }
        // المفتاح على الخادم 'garment_business' لا 'business' —
        // البحث بالاسم الخطأ كان يُرجع خريطة فارغة فتظهر الرسوم صفرًا
        // ولا يُعرض زر النشر بالجواهر إطلاقًا.
        final fee = fees.firstWhere(
            (f) => f['content_type'] == 'garment_business',
            orElse: () => const <String, dynamic>{});
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _MyBusinessCard(
            business: list[i],
            pointsCost: (fee['points_cost'] as num?)?.toInt() ?? 0,
            gemsCost: (fee['gems_cost'] as num?)?.toInt() ?? 0,
            onPublished: () => ref.invalidate(myGarmentBusinessesProvider),
          ),
        );
      },
    );
  }
}

class _MyBusinessCard extends StatefulWidget {
  final Map<String, dynamic> business;
  final int pointsCost;
  final int gemsCost;
  final VoidCallback onPublished;
  const _MyBusinessCard({
    required this.business,
    required this.pointsCost,
    required this.gemsCost,
    required this.onPublished,
  });

  @override
  State<_MyBusinessCard> createState() => _MyBusinessCardState();
}

class _MyBusinessCardState extends State<_MyBusinessCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final published = widget.business['is_published'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
        ),
        border: Border.all(
            color: published
                ? const Color(0xFF34D399).withValues(alpha: .45)
                : const Color(0xFFFFD700).withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.business['business_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (published
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(published ? 'منشورة' : 'مسودّة',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: published
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF59E0B))),
              ),
            ],
          ),
          if (widget.business['city']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('📍 ${widget.business['city']}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11.5)),
            ),
          if (!published) ...[
            const SizedBox(height: 10),
            Text(
                widget.pointsCost > 0 || widget.gemsCost > 0
                    ? 'رسوم النشر: ⭐ ${widget.pointsCost} أو 💎 ${widget.gemsCost}'
                    : 'النشر مجاني',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(
                child: _publishBtn('نشر بالنقاط ⭐', 'points'),
              ),
              if (widget.gemsCost > 0) ...[
                const SizedBox(width: 8),
                Expanded(child: _publishBtn('نشر بالجواهر 💎', 'gems')),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _publishBtn(String label, String currency) => SizedBox(
        height: 34,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              padding: EdgeInsets.zero),
          onPressed: _busy ? null : () => _publish(currency),
          child: _busy
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
        ),
      );

  Future<void> _publish(String currency) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GarmentActions.publishBusiness(
        businessId: widget.business['id'].toString(),
        currency: currency,
      );
      widget.onPublished();
      messenger.showSnackBar(const SnackBar(
          content: Text('نُشرت المنشأة — صارت تظهر في الدليل'),
          backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      final s = e.toString();
      messenger.showSnackBar(SnackBar(
        content: Text(s.contains('INSUFFICIENT')
            ? 'رصيدك لا يكفي لرسوم النشر.'
            : s.contains('QUOTA')
                ? 'استنفدت حصة النشر لعضويتك.'
                : 'تعذّر النشر: $s'),
        backgroundColor: const Color(0xFFDC2626),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ═══ ودجات مشتركة ════════════════════════════════════════════════════
class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  const _EmptyState(
      {required this.icon, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFFFD700).withValues(alpha: .4)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(hint,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12.5)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700)),
              ),
            ],
          ),
        ),
      );
}

// ═══ جسيمات الخلفية (مطابقة لسوق المنتجين) ═══════════════════════════
class _GarmentParticlePainter extends CustomPainter {
  final double progress;
  static final List<_P> _particles = List.generate(
      40,
      (i) => _P(
            x: (i * 0.0713) % 1.0,
            y: (i * 0.0971) % 1.0,
            size: 1.0 + (i % 5) * 0.5,
            speed: 0.008 + (i % 7) * 0.002,
            phase: i * 0.251,
          ));

  _GarmentParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.phase) % 1.0;
      final y = (p.y - t * p.speed * 10) % 1.0;
      final x = p.x + math.sin(t * math.pi * 2 + p.phase) * 0.03;
      final opacity = (math.sin(t * math.pi * 2) + 1) / 2 * 0.4;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GarmentParticlePainter old) =>
      old.progress != progress;
}

class _P {
  final double x, y, size, speed, phase;
  const _P(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.phase});
}
