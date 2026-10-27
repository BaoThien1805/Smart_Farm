import 'package:flutter/material.dart';

import '../../core/farm_illustrations.dart';
import '../../core/farm_feature_icon.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../auth/user_avatar.dart';
import 'workspace_destination.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.auth,
    required this.onOpen,
    this.onScanQr,
  });
  final AuthController auth;
  final ValueChanged<WorkspaceDestination> onOpen;
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    return SingleChildScrollView(
      key: const PageStorageKey('more-scroll'),
      padding: const EdgeInsets.all(FarmSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  key: const ValueKey('more-user-profile'),
                  leading: UserAvatar(user: user, radius: 24),
                  title: Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(user.roleLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(WorkspaceDestination.profile),
                ),
              ),
              const SizedBox(height: FarmSpacing.md),
              const FarmWelcomeBanner(),
              const SizedBox(height: FarmSpacing.md),
              if (onScanQr != null) ...[
                Card(
                  color: FarmColors.mint,
                  child: ListTile(
                    key: const ValueKey('more-scan-qr'),
                    leading: const Icon(Icons.qr_code_scanner, color: forest),
                    title: const Text('Quét QR vật nuôi'),
                    subtitle: const Text(
                      'Mở hồ sơ nhanh, không cần tìm chuồng',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onScanQr,
                  ),
                ),
                const SizedBox(height: FarmSpacing.md),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 3 : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final destination in WorkspaceDestination.secondary)
                        if (destination.allowedFor(user))
                          SizedBox(
                            width: width,
                            child: Card(
                              color: destination.tint,
                              child: InkWell(
                                key: ValueKey('more-${destination.name}'),
                                borderRadius: BorderRadius.circular(
                                  FarmRadii.card,
                                ),
                                onTap: () => onOpen(destination),
                                child: Padding(
                                  padding: const EdgeInsets.all(FarmSpacing.lg),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 148,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            FarmFeatureIcon(
                                              icon: destination.icon,
                                              color: destination.accent,
                                              background: destination.tint,
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: muted,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          destination.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(destination.descriptionFor(user)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: FarmSpacing.xl),
              OutlinedButton.icon(
                onPressed: auth.busy ? null : auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
