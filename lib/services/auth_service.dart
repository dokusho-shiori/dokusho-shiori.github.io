import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ウェブ版：ローカルに永続化してからサインイン
        await _auth.setPersistence(Persistence.LOCAL);
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.addScope('email');
        final UserCredential userCredential =
            await _auth.signInWithPopup(provider);
        return userCredential.user;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) return null;
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      print('Googleログインエラー: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  /// アカウントを削除（Firestoreデータ含む）
  /// 成功: true / 失敗: false
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 再認証（Firebaseの削除には直近のログインが必要）
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) return false;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Firestoreデータ削除
      final uid = user.uid;
      final db = FirebaseFirestore.instance;
      final booksSnap = await db
          .collection('users').doc(uid).collection('books').get();
      for (final bookDoc in booksSnap.docs) {
        final memosSnap = await bookDoc.reference.collection('memos').get();
        for (final memo in memosSnap.docs) {
          await memo.reference.delete();
        }
        await bookDoc.reference.delete();
      }
      await db.collection('users').doc(uid)
          .collection('settings').doc('preferences').delete();
      await db.collection('users').doc(uid).delete();

      // Firebase Authアカウント削除
      await user.delete();
      if (!kIsWeb) await _googleSignIn?.signOut();
      return true;
    } catch (e) {
      print('アカウント削除エラー: $e');
      return false;
    }
  }
}
