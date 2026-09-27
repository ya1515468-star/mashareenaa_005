import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscriptions/presentation/widgets/appear_offline_toggle.dart';

class SponsoredAdsPage extends ConsumerWidget {
  const SponsoredAdsPage({super.key});
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (uid == null) return;
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعلان ممول جديد'),
        content: TextField(controller: c, maxLines: 3, maxLength: 200),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('نشر')),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.isEmpty) return;
    // كان إدراجًا مباشرًا في sponsored_ads، والجدول محميّ بلا سياسة إدراج
    // ولا حتى صلاحية INSERT — أي أن الزر كان يفشل دائمًا لكل مستخدم منذ
    // إنشاء الميزة. كما كانت صلاحية canCreateAds تُفحص في الواجهة فقط.
    // create_sponsored_ad تفرضها على الخادم فعليًا وتُنشئ الإعلان.
    try {
      await Supabase.instance.client
          .rpc('create_sponsored_ad', params: {'p_text': text});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر الإعلان ✓')));
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().contains('FEATURE_REQUIRED_CREATE_ADS')
          ? 'عضويتك الحالية لا تتيح نشر إعلانات ممولة'
          : 'تعذّر نشر الإعلان: $e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final can = uid == null ? null : ref.watch(effectiveFeaturesProvider(uid));
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات الممولة')),
      floatingActionButton: (can?.valueOrNull?.canCreateAds ?? false)
          ? FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.campaign_outlined))
          : null,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('sponsored_ads')
            .stream(primaryKey: ['id'])
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(50),
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text('تعذر تحميل الإعلانات: ${s.error}'));
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = s.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات ممولة حاليًا'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: .3))),
                child: Text(rows[i]['text']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white))),
          );
        },
      ),
    );
  }
}
