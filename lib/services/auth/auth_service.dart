import 'package:mynotes/services/auth/auth_provider.dart';
import 'package:mynotes/services/auth/auth_user.dart';

class AuthService implements AuthProvider{
  final AuthProvider provider;

  AuthService(this.provider);

  @override
  Future<AuthUser> createUser({required String email, required String password}) {
   return provider.createUser(email: email, password: password);
  }

  @override
  // TODO: implement currentUser
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> logIn({required String email, required String password}) {
    // TODO: implement logIn
    return provider.logIn(email: email, password: password);
  }

  @override
  Future<void> sendEmailVerification() {
    // TODO: implement sendEmailVerification
    return provider.sendEmailVerification();
  }

  @override
  Future<void> signOut() {
    // TODO: implement signOut
    return provider.signOut();

  }
}