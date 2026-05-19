/// The minimal user identity the app needs — decoupled from any auth backend.
class AppUser {
  final String uid;
  final String? email;
  const AppUser({required this.uid, this.email});

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.email == email;
  @override
  int get hashCode => Object.hash(uid, email);
}
