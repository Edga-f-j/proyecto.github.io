import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tsuchi/service/notification_service.dart';

import '../pages/home_page.dart';
import 'login_page.dart';

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) { 
            // Ejecutar después del primer renderizado
            LocalNotificationService().uploadFcmToken();
          });
          return HomePage(user: snapshot.data!);
        } else {
            return const LoginPage();
          }
        }
      },
    );
  }
}
