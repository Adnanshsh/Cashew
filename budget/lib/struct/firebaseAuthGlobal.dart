import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/accountAndBackup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

Future<FirebaseFirestore?> firebaseGetDBInstanceAnonymous() async {
  try {
    await FirebaseAuth.instance.signInAnonymously();
    return FirebaseFirestore.instance;
  } catch (e) {
    print("There was an error with firebase login");
    print(e.toString());
    return null;
  }
}

// returns null if authentication unsuccessful
Future<FirebaseFirestore?> firebaseGetDBInstance() async {
  try {
    if (googleUser == null) {
      await signInGoogle(silentSignIn: true);
    }
    final GoogleSignInAccount? account = googleUser;
    if (account == null) return null;

    // Use the currently selected Google account, including after an account switch.
    final GoogleSignInAuthentication googleAuth = await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
    await updateSettings(
        "currentUserEmail", FirebaseAuth.instance.currentUser!.email,
        updateGlobalState: true);
    return FirebaseFirestore.instance;
  } catch (e) {
    print("There was an error with firebase login and possibly google");
    print(e.toString());
    return null;
  }
}

