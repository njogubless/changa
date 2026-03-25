import 'package:flutter/material.dart';
class PaymentStatusScreen extends StatelessWidget {
  final String reference;
  final double amount;
  const PaymentStatusScreen({super.key, required this.reference, required this.amount});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Status')),
    body: Center(child: Text(reference)));
}
