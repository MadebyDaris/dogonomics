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
  String? logoPath;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final logoManager = LogoManager();
    final path = await logoManager.fetchLogoPath(widget.stock.symbol.toLowerCase());
    print('Logo path: $path');
    if (path.isNotEmpty) {
      setState(() {
        logoPath = path;
      });
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
    child:Container(
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
              color: BACKG_COLOR,
              shape: BoxShape.circle,        
              ),
            padding: EdgeInsets.all(15),           
            child: Center(
              child: logoPath != null
                  ? Image.file(File(logoPath!), width: 30, height: 30)
                  : Icon(Icons.image, size: 24, color: Colors.black),
            ),
          ),
          SizedBox(width: 8),

          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.stock.symbol,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),

          SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.stock.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(widget.stock.code, style: TextStyle(color: MAINGREY_LIGHT)),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                widget.stock.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: widget.stock.isPositive ? Colors.green : Colors.red,
              ),
              Text(
                '${widget.stock.isPositive ? '+' : '-'}${widget.stock.change.toStringAsFixed(2)}%',
                style: TextStyle(color: widget.stock.isPositive ? Colors.green : Colors.red),
              ),
              SizedBox(height: 4),
              Text(
                '\$${widget.stock.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15),
              ),
              Text(
                'Total: \${(widget.stock.price * widget.stock.quantity).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(children: [

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
}