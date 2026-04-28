import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:changa/features/chama/presentation/screens/invite_code_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChamaSettingsScreen extends ConsumerStatefulWidget {
  final String chamaId;
  const ChamaSettingsScreen({super.key, required this.chamaId});

  @override
  ConsumerState<ChamaSettingsScreen> createState() =>
      _ChamaSettingsScreenState();
}

class _ChamaSettingsScreenState extends ConsumerState<ChamaSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _isEditing = false;
  bool _isSaving = false;
  ChamaModel? _chama;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _loadChama();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChama() async {
    final chama = await ref
        .read(chamaRepositoryProvider)
        .getChama(widget.chamaId);
    if (mounted) {
      setState(() {
        _chama = chama;
        _nameCtrl.text = chama.name;
        _descCtrl.text = chama.description ?? '';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameCtrl.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 3 characters')),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      await ref.read(chamaRepositoryProvider).updateChama(
            widget.chamaId,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isNotEmpty
                ? _descCtrl.text.trim()
                : null,
          );
      ref.read(chamaListProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chama updated'),
          backgroundColor: AppColors.forest,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Regenerate invite code?',
            style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
        content: Text(
          'The old code will stop working. Anyone who hasn\'t joined yet will need the new code.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.green)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated = await ref
          .read(chamaRepositoryProvider)
          .regenerateInviteCode(widget.chamaId);
      setState(() => _chama = updated);
      ref.read(chamaListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New invite code generated'),
          backgroundColor: AppColors.forest,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteChama() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Chama?',
            style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
        content: Text(
          'This will permanently delete "${_chama?.name}". All projects and data will be lost. This cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.green)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
       context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_chama == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(backgroundColor: AppColors.forest),
        body: const Center(
          child: CircularProgressIndicator(
              color: AppColors.forest, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        title: const Text('Chama Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _isSaving
                      ? AppColors.cream.withValues(alpha: 0.4)
                      : AppColors.mint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            _SectionHeader('General'),
            const SizedBox(height: 8),
            _SettingsCard(items: [
              _SettingsTile(
                icon: Icons.edit_outlined,
                label: 'Edit name & description',
                onTap: () => setState(() => _isEditing = !_isEditing),
              ),
            ]),

            if (_isEditing) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Chama name',
                  prefixIcon:
                      Icon(Icons.people_outline, color: AppColors.green),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: 20),

            _SectionHeader('Invite'),
            const SizedBox(height: 8),

            // Invite code preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.forest.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite code',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.green, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(
                    _chama!.inviteCode,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.forest,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showInviteCodeSheet(context, _chama!),
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.forest,
                            side:
                                const BorderSide(color: AppColors.forest),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _regenerateCode,
                          icon:
                              const Icon(Icons.refresh_outlined, size: 16),
                          label: const Text('Regenerate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.green,
                            side: const BorderSide(color: AppColors.sand),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            
            _SectionHeader('Members'),
            const SizedBox(height: 8),
            _SettingsCard(items: [
              _SettingsTile(
                icon: Icons.people_outline,
                label: 'View all members',
                value: '${_chama!.memberCount} members',
                onTap: () =>
                    context.push('/chamas/${widget.chamaId}/members'),
              ),
            ]),
            const SizedBox(height: 20),

            
            _SectionHeader('Danger zone'),
            const SizedBox(height: 8),
            _DangerTile(
              icon: Icons.delete_outline,
              label: 'Delete Chama',
              subtitle: 'Permanently delete this Chama and all its data',
              onTap: _deleteChama,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsTile> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _SettingsTileWidget(tile: item),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.sand.withValues(alpha: 0.5),
                  ),
              ],
            );
          }).toList(),
        ),
      );
}

class _SettingsTile {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });
}

class _SettingsTileWidget extends StatelessWidget {
  final _SettingsTile tile;
  const _SettingsTileWidget({required this.tile});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(tile.icon, color: AppColors.forest, size: 18),
        ),
        title: Text(tile.label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest)),
        subtitle: tile.value != null
            ? Text(tile.value!,
                style: AppTextStyles.caption.copyWith(color: AppColors.green))
            : null,
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.sand, size: 18),
        onTap: tile.onTap,
      );
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DangerTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.error.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.error.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),
      );
}