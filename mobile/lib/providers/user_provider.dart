import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/models/user_model.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  StreamSubscription<UserModel?>? _userStreamSubscription;
  String? _initedForUid;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  void init(AuthProvider authProvider) {
    final uid = authProvider.user?.uid;
    if (uid == null) {
      _userStreamSubscription?.cancel();
      _userStreamSubscription = null;
      _initedForUid = null;
      _user = null;
      notifyListeners();
      return;
    }
    if (_initedForUid == uid) return;
    _userStreamSubscription?.cancel();
    _initedForUid = uid;
    _loadUser(uid);
    _userStreamSubscription = _firestoreService.getUserStream(uid).listen(
      (user) {
        _user = user;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('UserProvider: getUserStream error: $e');
      },
    );
  }

  Future<void> _loadUser(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _firestoreService.getUser(userId);
    } catch (e) {
      debugPrint('UserProvider: _loadUser error: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    if (_user == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    await _firestoreService.updateUser(_user!.id, updates);
    // Stream will update _user automatically
  }
}

