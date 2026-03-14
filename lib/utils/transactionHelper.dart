import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Records a buy or sell transaction in the user's Firestore transactions subcollection.
Future<void> recordTransaction({
  required String symbol,
  required String name,
  required String transactionType, // 'Buy' or 'Sell'
  required String assetType, // 'stock', 'bond', 'commodity'
  required double quantity,
  required double pricePerUnit,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final total = quantity * pricePerUnit;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .add({
    'symbol': symbol,
    'name': name,
    'type': transactionType,
    'assetType': assetType,
    'quantity': quantity,
    'pricePerUnit': pricePerUnit,
    'total': total,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
