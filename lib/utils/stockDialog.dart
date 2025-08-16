import 'package:flutter/material.dart';

class AddStockPage extends StatefulWidget {
  final Function(String, int) onStockSelected;

  const AddStockPage({super.key, required this.onStockSelected});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  List<String> _searchResults = [];
  String? _selectedStock;

  final List<String> _popularStocks = [
    'AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'NFLX', 'META', 'NVDA', 
    'AMD', 'INTC', 'JPM', 'BAC', 'WMT', 'JNJ', 'PG', 'KO', 'PFE', 
    'XOM', 'CVX', 'T', 'VZ', 'DIS', 'IBM', 'CSCO', 'ORCL'
  ];

  @override
  void initState() {
    super.initState();
    _searchResults = _popularStocks;
  }

  void _performSearch(String query) {
    setState(() {
      // show the popular ones and stuff
      if (query.isEmpty) {
        _searchResults = _popularStocks;
        return;
      } else {
      _searchResults = _popularStocks
          .where((symbol) => symbol.toLowerCase().contains(query.toLowerCase()))
          .toList();
      }
      if (!_searchResults.contains(query.toUpperCase()) && query.isNotEmpty) {
        _searchResults.insert(0, query.toUpperCase());
      }
    });
  }

  void _showQuantityDialog(String symbol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $symbol to Portfolio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How many shares of $symbol do you have in your portfolio?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                suffixText: 'shares',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedStock = null;
              });
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(_quantityController.text);
              if (quantity != null && quantity > 0) {
                widget.onStockSelected(symbol, quantity);
                Navigator.pop(context);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Add to Portfolio'),
          ),
        ],
      ),
    );
  }

  void _selectStock(String symbol) {
    setState(() {
      _selectedStock = symbol;
    });
    
    _showQuantityDialog(symbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Stock'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
            ),
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: const InputDecoration(
                hintText: 'Search stock symbol...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final symbol = _searchResults[index];
                  return ListTile(
                    title: Text(symbol),
                    trailing: const Icon(Icons.add),
                    onTap: () => _selectStock(symbol),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Text('Tap a stock symbol to add it to your portfolio. You can specify the quantity in the next step.',)
                ]
              )
            ),
          ],
        ),
      ),
    );
  }
}