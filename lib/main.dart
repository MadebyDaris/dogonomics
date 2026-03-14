import 'package:Dogonomics/backend/authentication.dart';
import 'package:Dogonomics/pages/landingpage.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: BACKG_COLOR,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: AuthenticationWrapper(),
    );
  } 
}

// Wrapper to check authentication state on app start
class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF050E14),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF19B305),
              ),
            ),
          );
        }
        
        // If user is logged in, go to landing page
        if (snapshot.hasData && snapshot.data != null) {
          return DogonomicsLandingPage(
            userId: snapshot.data!.uid,
            onContinueToPortfolio: null,
          );
        }
        
        // Otherwise, show login screen
        return LoginScreen();
      },
    );
  }
}
