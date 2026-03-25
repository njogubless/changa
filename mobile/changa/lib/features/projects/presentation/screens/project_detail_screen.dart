import 'package:flutter/material.dart';
class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Project')),
    body: Center(child: Text(projectId)));
}
