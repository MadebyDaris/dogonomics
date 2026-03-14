import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/utils/transactionHelper.dart';
import 'package:Dogonomics/utils/constant.dart';

class AddAssetDialog extends StatefulWidget {
  final AssetType assetType;
  final String symbol;
  final String name;
  final double currentPrice;
  final String? category;
  final String? unit;

  const AddAssetDialog({
    Key? key,
    required this.assetType,
    required this.symbol,
    required this.name,
    required this.currentPrice,
    this.category,
    this.unit,
  }) : super(key: key);

  @override
  State<AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _couponRateController = TextEditingController();
  final _maturityDateController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _couponRateController.dispose();
    _maturityDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CARD_BACKGROUND,
      title: Text(
        'Add ${_getAssetTypeName()} to Wallet',
        style: HEADING_MEDIUM,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: HEADING_SMALL.copyWith(color: TEXT_PRIMARY),
              ),
              const SizedBox(height: 8),
              Text(
                'Symbol: ${widget.symbol}',
                style: BODY_SECONDARY,
              ),
              Text(
                'Current Price: \$${widget.currentPrice.toStringAsFixed(2)}',
                style: BODY_SECONDARY,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                style: BODY_PRIMARY,
                decoration: InputDecoration(
                  labelText: _getQuantityLabel(),
                  labelStyle: BODY_SECONDARY,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: BORDER_COLOR),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: ACCENT_GREEN),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  return null;
                },
              ),
              if (widget.assetType == AssetType.bond) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _couponRateController,
                  keyboardType: TextInputType.number,
                  style: BODY_PRIMARY,
                  decoration: InputDecoration(
                    labelText: 'Coupon Rate (%)',
                    labelStyle: BODY_SECONDARY,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: BORDER_COLOR),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ACCENT_GREEN),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter coupon rate';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maturityDateController,
                  style: BODY_PRIMARY,
                  decoration: InputDecoration(
                    labelText: 'Maturity Date (e.g., 2025-12-31)',
                    labelStyle: BODY_SECONDARY,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: BORDER_COLOR),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ACCENT_GREEN),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter maturity date';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CARD_BACKGROUND_ELEVATED,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Investment', style: CAPTION_TEXT),
                    const SizedBox(height: 4),
                    Text(
                      _calculateTotal(),
                      style: HEADING_MEDIUM.copyWith(color: ACCENT_GREEN),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: BODY_PRIMARY.copyWith(color: TEXT_SECONDARY),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addAssetToWallet,
          style: ElevatedButton.styleFrom(
            backgroundColor: BUTTON_PRIMARY,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add to Wallet'),
        ),
      ],
    );
  }

  String _getAssetTypeName() {
    switch (widget.assetType) {
      case AssetType.bond:
        return 'Bond';
      case AssetType.commodity:
        return 'Commodity';
      case AssetType.crypto:
        return 'Cryptocurrency';
      case AssetType.stock:
        return 'Stock';
    }
  }

  String _getQuantityLabel() {
    switch (widget.assetType) {
      case AssetType.bond:
        return 'Number of Bonds';
      case AssetType.commodity:
        return 'Quantity (${widget.unit ?? 'units'})';
      case AssetType.crypto:
        return 'Amount (coins/tokens)';
      case AssetType.stock:
        return 'Number of Shares';
    }
  }

  String _calculateTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final total = quantity * widget.currentPrice;
    return '\$${total.toStringAsFixed(2)}';
  }

  Future<void> _addAssetToWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final quantity = double.parse(_quantityController.text);
      Map<String, dynamic> assetData;

      switch (widget.assetType) {
        case AssetType.bond:
          assetData = BondAsset(
            symbol: widget.symbol,
            name: widget.name,
            currentValue: widget.currentPrice,
            quantity: quantity,
            issuer: 'US Treasury',
            couponRate: double.parse(_couponRateController.text),
            maturityDate: _maturityDateController.text,
            faceValue: 100.0, // Standard face value for treasury bonds
          ).toMap();
          break;
        case AssetType.commodity:
          assetData = CommodityAsset(
            symbol: widget.symbol,
            name: widget.name,
            currentValue: widget.currentPrice,
            quantity: quantity,
            category: widget.category ?? '',
            unit: widget.unit ?? 'units',
          ).toMap();
          break;
        case AssetType.crypto:
          assetData = CryptoAsset(
            symbol: widget.symbol,
            name: widget.name,
            currentValue: widget.currentPrice,
            quantity: quantity,
          ).toMap();
          break;
        case AssetType.stock:
          // This shouldn't happen in this dialog, but handle it anyway
          assetData = {
            'symbol': widget.symbol,
            'name': widget.name,
            'currentValue': widget.currentPrice,
            'quantity': quantity,
            'type': 'stock',
          };
          break;
      }

      // Add to user's wallet in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'wallet.assets': FieldValue.arrayUnion([assetData])
      });

      // Record transaction for history tracking
      await recordTransaction(
        symbol: widget.symbol,
        name: widget.name,
        transactionType: 'Buy',
        assetType: widget.assetType.name,
        quantity: quantity,
        pricePerUnit: widget.currentPrice,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.name} added to wallet successfully!'),
            backgroundColor: COLOR_POSITIVE,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to wallet: ${e.toString()}'),
            backgroundColor: COLOR_NEGATIVE,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Helper function to show the dialog
Future<bool?> showAddAssetDialog({
  required BuildContext context,
  required AssetType assetType,
  required String symbol,
  required String name,
  required double currentPrice,
  String? category,
  String? unit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AddAssetDialog(
      assetType: assetType,
      symbol: symbol,
      name: name,
      currentPrice: currentPrice,
      category: category,
      unit: unit,
    ),
  );
}
