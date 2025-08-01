import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  List<dynamic> portfolio; 

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.portfolio
  });

  // Factory method to create a User from a map
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      portfolio: data['portfolio'] ?? [],
    );
  }

  // Method to convert User to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
  String getUserId() {
    return FirebaseAuth.instance.currentUser!.uid;
  }
  Future<void> addToPortfolio(String symb) async {
      String? userId = getUserId();
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.update({
        'portfolio': FieldValue.arrayUnion([symb])
      });
  }
}