import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dogonomics_frontend/backend/user.dart';
import 'package:dogonomics_frontend/pages/frontpage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoginMode = true;

  Future<void> _login() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
          final user = credential.user;

      if (user != null) {
        // Get username from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final username = userDoc.data()?['username'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.uid);
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('username', username);
        final myuser = AppUser.fromMap({
          'id': user.uid,
          'name': username,
          'email': user.email,
          'portfolio': userDoc.data()?['portfolio'] ?? [],
        });
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MyHomePage(title: "Dogonomics", user: myuser,)));
      }
    } catch (e) {
      print('Login failed: $e');
    }
  }

  Future<void> _signup() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final username = _usernameController.text.trim();

        // Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'username': username,
        });

        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.uid);
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('username', username);

        final myuser = AppUser.fromMap({
          'id': user.uid,
          'name': username,
          'email': user.email,
          'portfolio': [],
        });
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MyHomePage(title: "Dogonomics", user: myuser,)));
    }
    } catch (e) {
      print('Signup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsetsGeometry.all(16.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isLoginMode ? "Login" : "Sign Up", style: TextStyle(fontSize: 24, fontStyle: FontStyle.italic)),
              Text(_isLoginMode ? "Time to study some \nDogonomics!" : "Dog catch bones, you catch bonds, \nsame thing no?!", style: TextStyle(fontSize: 12)),
              SizedBox(height: 20),
              if (!_isLoginMode)

              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: _emailController, 
                decoration: InputDecoration(labelText: "Email")),
              TextField(
                controller: _passwordController, 
                decoration: InputDecoration(labelText: "Password"), obscureText: true),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoginMode ? _login : _signup,
                child: Text(_isLoginMode ? 'Login' : 'Sign Up'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });},
                child: Text(_isLoginMode
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login"),
            ),
          ],
        ),
      )
    );
  }
}
