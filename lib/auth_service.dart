import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: 'AIzaSyBmVnl8e5CWdvFssG6XQdMDSjHXLoG_0B0',
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': googleUser.displayName,
        'email': googleUser.email,
        'lastSignIn': DateTime.now(),
      }, SetOptions(merge: true));

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }


  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }


  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
