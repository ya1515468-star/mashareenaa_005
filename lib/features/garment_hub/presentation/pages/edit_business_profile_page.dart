import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../providers/garment_hub_provider.dart';

class EditBusinessProfilePage extends ConsumerStatefulWidget {
  final String uid;
  const EditBusinessProfilePage({super.key, required this.uid});

  @override
  ConsumerState<EditBusinessProfilePage> createState() =>
      _EditBusinessProfilePageState();
}

class _EditBusinessProfilePageState
    extends ConsumerState<EditBusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _minOrderController = TextEditingController(text: '0');
  final _capacityController = TextEditingController(text: '0');
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  GarmentBusinessType _type = GarmentBusinessType.workshop;
  bool _initialized = false;

  void _fillFrom(GarmentBusinessProfileEntity? profile) {
    if (profile == null || _initialized) return;
    _initialized = true;
    _nameController.text = profile.businessName;
    _descriptionController.text = profile.description;
    _specialtiesController.text = profile.specialties.join(', ');
    _minOrderController.text = profile.minOrderQuantity.toString();
    _capacityController.text = profile.monthlyCapacity.toString();
    _cityController.text = profile.city ?? '';
    _countryController.text = profile.country ?? '';
    _phoneController.text = profile.contactPhone ?? '';
    _type = profile.businessType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _specialtiesController.dispose();
    _minOrderController.dispose();
    _capacityController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final specialties = _specialtiesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final profile = GarmentBusinessProfileEntity(
      uid: widget.uid,
      businessType: _type,
      businessName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      specialties: specialties,
      minOrderQuantity: int.tryParse(_minOrderController.text.trim()) ?? 0,
      monthlyCapacity: int.tryParse(_capacityController.text.trim()) ?? 0,
      contactPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(garmentHubControllerProvider.notifier)
        .upsertBusinessProfile(profile);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ الملف التجاري')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحفظ الآن. تحقق من البيانات والاتصال ثم أعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myBusinessProfileProvider(widget.uid));
    _fillFrom(profileAsync.valueOrNull);
    final controllerState = ref.watch(garmentHubControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي التجاري')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<GarmentBusinessType>(
                  segments: GarmentBusinessType.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                      .toList(),
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _nameController,
                  label: 'اسم النشاط التجاري',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                    controller: _descriptionController,
                    label: 'نبذة عن النشاط'),
                const SizedBox(height: 16),
                AuthTextField(
                    controller: _specialtiesController,
                    label: 'التخصصات (مفصولة بفاصلة)'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AuthTextField(
                        controller: _minOrderController,
                        label: 'الحد الأدنى للطلب',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthTextField(
                        controller: _capacityController,
                        label: 'الطاقة الشهرية',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: AuthTextField(
                            controller: _cityController, label: 'المدينة')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: AuthTextField(
                            controller: _countryController, label: 'الدولة')),
                  ],
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _phoneController,
                  label: 'رقم التواصل',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                AuthButton(
                    label: 'حفظ',
                    isLoading: controllerState.isLoading,
                    onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
