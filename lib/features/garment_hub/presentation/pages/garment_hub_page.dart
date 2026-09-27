import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/widgets/mini_chat_overlay.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../providers/garment_hub_provider.dart';
import 'edit_business_profile_page.dart';

class GarmentHubPage extends ConsumerStatefulWidget {
  const GarmentHubPage({super.key});

  @override
  ConsumerState<GarmentHubPage> createState() => _GarmentHubPageState();
}

class _GarmentHubPageState extends ConsumerState<GarmentHubPage> {
  GarmentBusinessType? _filter;

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(garmentDirectoryProvider(_filter));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garment Hub'),
        actions: [
          if (myUid != null)
            IconButton(
              icon: const Icon(Icons.storefront_outlined),
              tooltip: 'ملفي التجاري',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EditBusinessProfilePage(uid: myUid)));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _FilterChip(
                    label: 'الكل',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null)),
                ...GarmentBusinessType.values.map(
                  (t) => _FilterChip(
                    label: t.label,
                    selected: _filter == t,
                    onTap: () => setState(() => _filter = t),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: directoryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
              data: (businesses) {
                if (businesses.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد أعمال مسجَّلة بعد في الدليل',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: businesses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final biz = businesses[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(biz.businessName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Chip(label: Text(biz.businessType.label)),
                            if (biz.specialties.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: biz.specialties
                                    .map((s) => Text('#$s',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.goldMuted)))
                                    .toList(),
                              ),
                            ],
                            if (biz.city != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                  '${biz.city}${biz.country != null ? '، ${biz.country}' : ''}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ],
                            if (biz.monthlyCapacity > 0)
                              Text(
                                  'الطاقة الإنتاجية الشهرية: ${biz.monthlyCapacity}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: myUid == null || myUid == biz.uid
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.chat_bubble_outline,
                                    color: AppColors.gold),
                                onPressed: () {
                                  openPrivateChat(
                                    context,
                                    ref,
                                    threadId: _threadId(myUid, biz.uid),
                                    peerUid: biz.uid,
                                    peerName: biz.businessName,
                                  );
                                },
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _threadId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
        labelStyle: TextStyle(
            color: selected ? AppColors.background : AppColors.textPrimary),
      ),
    );
  }
}
