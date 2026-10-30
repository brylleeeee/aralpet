import 'package:flutter/material.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Pet')),
      body: const Center(child: Text('Your pet will go here')),
    );
  }
}