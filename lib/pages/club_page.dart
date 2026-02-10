import 'package:flutter/material.dart';

class ClubPage extends StatelessWidget {
  const ClubPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club')),
      body: const Center(child: Text('Informations club à venir')),
    );
  }
}
