import 'package:dogonomics_frontend/backend/dogonomicsApi.dart';
import 'package:flutter/material.dart';
import 'package:dogonomics_frontend/utils/constant.dart';
import 'package:dogonomics_frontend/utils/logoManager.dart';
import 'dart:io';

import '../pages/stockDetails.dart';
import '../utils/tickerData.dart';

class StockCard extends StatefulWidget {
  final Stock stock;
  final VoidCallback? onRemove;
  final Function(int)? onQuantityChanged;

  const StockCard({
    Key? key,
    required this.stock,
    this.onRemove,
    this.onQuantityChanged,
  }) : super(key: key);

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  String? logoUrl;
  bool isLoadingLogo = true;
  
  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final profile = await DogonomicsAPI.getCompanyProfile(widget.stock.symbol);
      if (mounted && profile != null && profile.logo.isNotEmpty) {
        setState(() {
          logoUrl = profile.logo;
          isLoadingLogo = false;
        });
      } else {
        setState(() {
          isLoadingLogo = false;
        });
      }
    } catch (e) {
      print('Failed to load logo for ${widget.stock.symbol}: $e');
      if (mounted) {
        setState(() {
          isLoadingLogo = false;
        });
      }
    }
  }


  void _showQuantityDialog() {
    final TextEditingController controller = TextEditingController(
      text: widget.stock.quantity.toString()
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Quantity for ${widget.stock.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current quantity: ${widget.stock.quantity}'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity >= 0) {
                widget.onQuantityChanged?.call(newQuantity);
                Navigator.pop(context);
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  return InkWell(
    onTap: () {
      print('Tapped on ${widget.stock.symbol}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailsPage(symbol: widget.stock.symbol),
          ),
        );
    },
    borderRadius: BorderRadius.circular(12),   
    child:
    Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MAINGREY,
        borderRadius: BorderRadius.circular(12),
        
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: MAINGREY,
              shape: BoxShape.circle,        
              ),
            padding: EdgeInsets.all(15),           
            child: Center(
              child: _buildLogo(),
            ),
          ),
          
          SizedBox(width: 12),
          Expanded(
          child:
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Expanded(
                child: Text(
                  widget.stock.name,               
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              SizedBox(width: 8),
              
              // SYMBOL
              Container(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: ACCENT_COLOR,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: 
                Column(
                  children: [
                    Text(
                      widget.stock.symbol,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                )
              ),
            ]),
          ),
  
          SizedBox(width: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                widget.stock.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: widget.stock.isPositive ? Colors.green : Colors.red,
              ),
              Text(
                '${widget.stock.isPositive ? '+' : '-'}${widget.stock.changePercentage.toStringAsFixed(2)}%',
                style: TextStyle(color: widget.stock.isPositive ? Colors.green : Colors.red),
              ),
              SizedBox(height: 8),
              Text(
                '\$${widget.stock.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15),
              ),
              Text(
                'Total: ${(widget.stock.price * widget.stock.quantity).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(
            children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  onPressed: _showQuantityDialog,
                  tooltip: 'Edit Quantity',
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.redAccent, size: 20),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove Stock',
                ),
          ],)
        ],
      ),
    )
    );
  }
    Widget _buildLogo() {
    if (isLoadingLogo) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(ACCENT_COLOR),
        ),
      );
    }

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          logoUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(ACCENT_COLOR),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    }

    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ACCENT_COLOR.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.trending_up,
        size: 20,
        color: ACCENT_COLOR,
      ),
    );
  }
}