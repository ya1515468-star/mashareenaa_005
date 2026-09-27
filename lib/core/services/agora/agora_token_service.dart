import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-issued Agora token facade. Secrets stay in the Supabase Edge Function.
class AgoraTokenFacade {
  Future<Map<String, dynamic>> issue({
    required String channelName,
    required int uid,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'agora-token',
      body: {'channel': channelName, 'uid': uid},
    );
    final raw = response.data;
    if (raw is! Map) throw StateError('Invalid Agora token response');
    return Map<String, dynamic>.from(raw);
  }
}
