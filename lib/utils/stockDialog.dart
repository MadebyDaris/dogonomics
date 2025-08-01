import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class AddStockPage extends StatefulWidget {
  final Function(String) onStockSelected;

  const AddStockPage({super.key, required this.onStockSelected});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = [];

  final List<String> _dummyStockSymbols = [
    'AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'NFLX', 'META', 'NVDA', 'BABA', 'AMD'
  ];

  void _performSearch(String query) {
    setState(() {
      _searchResults = _dummyStockSymbols
          .where((symbol) => symbol.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _selectStock(String symbol) {
    widget.onStockSelected(symbol);
    Navigator.pop(context); // Return to previous screen
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
          ],
        ),
      ),
    );
  }
}