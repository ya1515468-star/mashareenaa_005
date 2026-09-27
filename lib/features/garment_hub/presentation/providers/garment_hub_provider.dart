import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../../domain/repositories/garment_hub_repository.dart';
import '../../domain/usecases/upsert_business_profile_usecase.dart';

final garmentDirectoryProvider = StreamProvider.family<
    List<GarmentBusinessProfileEntity>, GarmentBusinessType?>((ref, type) {
  return sl<GarmentHubRepository>().watchDirectory(businessType: type);
});

final myBusinessProfileProvider =
    FutureProvider.family<GarmentBusinessProfileEntity?, String>(
        (ref, uid) async {
  final result = await sl<GarmentHubRepository>().getBusinessProfile(uid);
  return result.fold((failure) => null, (profile) => profile);
});

class GarmentHubController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> upsertBusinessProfile(
      GarmentBusinessProfileEntity profile) async {
    state = const AsyncLoading();
    final result = await sl<UpsertBusinessProfileUseCase>()(profile);
    return result.fold((failure) {
      state = AsyncError(failure.message, StackTrace.current);
      return false;
    }, (_) {
      state = const AsyncData(null);
      return true;
    });
  }
}

final garmentHubControllerProvider =
    AsyncNotifierProvider<GarmentHubController, void>(GarmentHubController.new);
