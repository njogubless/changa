import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/presentation/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



void showInviteMembersSheet(
  BuildContext context,
  WidgetRef ref, {
  required String chamaId,
  required String chamaName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InviteMembersSheet(
      chamaId: chamaId,
      chamaName: chamaName,
    ),
  );
}

class _InviteMembersSheet extends ConsumerStatefulWidget {
  final String chamaId;
  final String chamaName;
  const _InviteMembersSheet({
    required this.chamaId,
    required this.chamaName,
  });

  @override
  ConsumerState<_InviteMembersSheet> createState() =>
      _InviteMembersSheetState();
}

class _InviteMembersSheetState extends ConsumerState<_InviteMembersSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0, 0, 0,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Add member',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest),
                ),
                const Spacer(),
                Text(
                  widget.chamaName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.sand.withValues(alpha: 0.3),
              borderRadius: AppRadius.pillAll,
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.forest,
                borderRadius: AppRadius.pillAll,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.cream,
              unselectedLabelColor: AppColors.green,
              labelStyle: AppTextStyles.button.copyWith(fontSize: 13),
              unselectedLabelStyle: AppTextStyles.button.copyWith(fontSize: 13),
              tabs: const [
                Tab(text: 'By phone number'),
                Tab(text: 'Share a code'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab views
          SizedBox(
            height: 260,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PhoneInviteTab(chamaId: widget.chamaId),
                _CodeInviteTab(chamaId: widget.chamaId),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Tab 1: Invite by phone number ─────────────────────────────────────────────

class _PhoneInviteTab extends ConsumerStatefulWidget {
  final String chamaId;
  const _PhoneInviteTab({required this.chamaId});

  @override
  ConsumerState<_PhoneInviteTab> createState() => _PhoneInviteTabState();
}

class _PhoneInviteTabState extends ConsumerState<_PhoneInviteTab> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^254[17]\d{8}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid number: 254XXXXXXXXX');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final result = await ref
          .read(inviteRepositoryProvider)
          .inviteByPhone(chamaId: widget.chamaId, phone: phone);

      _phoneCtrl.clear();
      setState(() {
        _isLoading = false;
        _successMessage = result['user_found'] == true
            ? 'Invite sent! They\'ll see it in their app.'
            : 'Saved. They\'ll receive the invite when they join Changa.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = _friendlyError(e.toString());
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already a member')) return 'This person is already in the chama.';
    if (raw.contains('already sent')) return 'An invite was already sent to this number.';
    if (raw.contains('yourself')) return 'You can\'t invite yourself.';
    if (raw.contains('Network')) return 'No internet connection.';
    return 'Could not send invite. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter their M-Pesa number',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.green,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '254712345678',
                    prefixIcon: const Icon(
                      Icons.phone_android,
                      color: AppColors.mpesaGreen,
                      size: 20,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  onChanged: (_) => setState(() {
                    _error = null;
                    _successMessage = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              GestureDetector(
                onTap: _isLoading ? null : _sendInvite,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cream,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: AppColors.cream,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Error
          if (_error != null)
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),

          // Success
          if (_successMessage != null)
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.08),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.sage, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'They\'ll get an in-app notification to accept or decline. '
                    'Invite expires in 7 days.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.green,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Generate & share invite code ───────────────────────────────────────

class _CodeInviteTab extends ConsumerWidget {
  final String chamaId;
  const _CodeInviteTab({required this.chamaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeAsync = ref.watch(generateCodeProvider(chamaId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: codeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Could not generate code',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(generateCodeProvider(chamaId)),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (codeModel) {
          final daysLeft = codeModel.expiresAt
              .difference(DateTime.now())
              .inDays;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this code with anyone you want to invite',
                style: AppTextStyles.caption.copyWith(color: AppColors.green),
              ),
              const SizedBox(height: 16),

              // Code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Column(
                  children: [
                    Text(
                      codeModel.inviteCode,
                      style: AppTextStyles.display1.copyWith(
                        color: AppColors.cream,
                        fontSize: 32,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expires in $daysLeft days',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: codeModel.inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copied to clipboard'),
                            backgroundColor: AppColors.forest,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Share via system share sheet
                        // Share.share(
                        //   'Join my chama on Changa!\n'
                        //   'Use this code: ${codeModel.inviteCode}\n'
                        //   'Valid for $daysLeft days.',
                        // );
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Refresh code
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(generateCodeProvider(chamaId)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    'Generate new code',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.sage),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
