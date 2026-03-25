import 'package:flutter/material.dart';
class PaymentScreen extends StatelessWidget {
  final String projectId;
  const PaymentScreen({super.key, required this.projectId});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Pay')),
    body: Center(child: Text(projectId)));
}
