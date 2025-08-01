import 'package:dogonomics_frontend/backend/user.dart';
import 'package:dogonomics_frontend/pages/stockview.dart';
import 'package:dogonomics_frontend/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import "package:dogonomics_frontend/pages/stockview.dart";

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.user});

  final String title;
  final AppUser? user;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final tabs = ['Stocks', 'Commodities', 'CFDs', 'Bonds'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
      preferredSize: Size.fromHeight(160.0), // here the desired height
      child: AppBar(
        backgroundColor: MAINGREY,
        title: Container(
            padding: EdgeInsets.only(top:30, bottom: 0),
            margin: EdgeInsets.only(left: 20, right: 20),
            child: 
              Text('Dogonomics Assistant', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.josefinSans().fontFamily))
          ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          )
        ],
      bottom: TabBar(
        dividerHeight: 0,
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
          children: tabs.map((tab) {
          if (tab == 'Stocks') {
            return StockViewTab();
          } else {
            return Center(child: Text('Coming Soon...', style: TextStyle(color: Colors.grey)));
          }
        }).toList(),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this, initialIndex: 1);
  }
  _topAppBar() {
    return Row(
      children: [
        Column(
          children: [
            Text("Welcome to Dogonomics"),
            Text("sup")
          ],
        ),
        FloatingActionButton(
          onPressed: null,
          child: Icon(Icons.beach_access),),
        FloatingActionButton(
          onPressed: null,
          child: Icon(Icons.twenty_three_mp),)
      ],
    );
  }
}

class CommoditiesTab extends StatelessWidget {
  @override
    Widget build(BuildContext context) {
      return Scaffold();
    }
}