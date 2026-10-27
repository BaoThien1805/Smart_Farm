import 'package:flutter/material.dart';

import 'theme.dart';

class FarmInfoCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const FarmInfoCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(FarmSpacing.lg),
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: color,
      elevation: 1,
      shadowColor: ink.withValues(alpha: .08),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FarmRadii.card),
        side: const BorderSide(color: line),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

enum FarmBadgeTone { neutral, success, warning, danger, info, lavender, peach }

/// Presentation only: callers supply the real status and its translated label.
class FarmStatusBadge extends StatelessWidget {
  final String label;
  final FarmBadgeTone tone;
  final IconData? icon;
  const FarmStatusBadge({
    super.key,
    required this.label,
    this.tone = FarmBadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      FarmBadgeTone.success => (FarmColors.mint, forest),
      FarmBadgeTone.warning => (FarmColors.amber, FarmColors.warning),
      FarmBadgeTone.danger => (FarmColors.dangerSurface, FarmColors.danger),
      FarmBadgeTone.info => (FarmColors.sky, FarmColors.info),
      FarmBadgeTone.lavender => (FarmColors.lavender, FarmColors.purple),
      FarmBadgeTone.peach => (FarmColors.peach, ink),
      FarmBadgeTone.neutral => (canvas, muted),
    };
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(FarmRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: icon == Icons.circle ? 8 : 16,
                  color: foreground,
                ),
              ),
              const SizedBox(width: FarmSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page owns its mobile heading and optional workspace Back action.
class FarmPageNavigation extends InheritedWidget {
  final VoidCallback? onBack;
  const FarmPageNavigation({super.key, required super.child, this.onBack});

  static bool isWorkspace(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FarmPageNavigation>() != null;

  static VoidCallback? backOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FarmPageNavigation>()?.onBack;

  @override
  bool updateShouldNotify(FarmPageNavigation oldWidget) =>
      oldWidget.onBack != onBack;
}

class FarmSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool pageTitle;
  const FarmSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.pageTitle = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (pageTitle && FarmPageNavigation.backOf(context) != null)
            IconButton(
              key: const ValueKey('workspace-back'),
              tooltip: 'Quay lại Thêm',
              onPressed: FarmPageNavigation.backOf(context),
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: FarmSpacing.sm),
            action!,
          ],
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: FarmSpacing.sm),
        Text(subtitle!, style: const TextStyle(color: muted)),
      ],
    ],
  );
}

InputDecoration farmInputDecoration({
  required String label,
  Widget? suffixIcon,
  String? helperText,
}) => InputDecoration(
  labelText: label,
  suffixIcon: suffixIcon,
  helperText: helperText,
  helperMaxLines: 6,
  errorMaxLines: 4,
  alignLabelWithHint: true,
);

/// Callers decide whether a successful response is empty; errors and pending
/// requests must never be presented as an empty result.
class FarmEmptyState extends StatelessWidget {
  final String message;
  final String? description;
  final IconData icon;
  final Widget? illustration;
  const FarmEmptyState({
    super.key,
    required this.message,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) => FarmInfoCard(
    child: Column(
      children: [
        ExcludeSemantics(
          child:
              illustration ??
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: FarmColors.sky,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: forest),
              ),
        ),
        const SizedBox(height: FarmSpacing.lg),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (description != null) ...[
          const SizedBox(height: FarmSpacing.sm),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
        ],
      ],
    ),
  );
}

class FarmLoadingState extends StatelessWidget {
  final String message;
  const FarmLoadingState({super.key, this.message = 'Đang tải dữ liệu…'});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FarmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: FarmSpacing.sm),
          Text(message, style: const TextStyle(color: muted)),
        ],
      ),
    ),
  );
}

/// Keeps the actual API message: a permission/configuration error is not
/// automatically described as a network failure or offline mode.
class FarmLoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const FarmLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => FarmInfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: FarmColors.danger,
          ),
        ),
        const SizedBox(height: FarmSpacing.md),
        Text(
          'Không thể tải dữ liệu',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: FarmSpacing.md),
        FeedbackBox(message),
        const SizedBox(height: FarmSpacing.md),
        Align(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ),
      ],
    ),
  );
}

/// Use inside the existing disabled submit button; this changes presentation
/// only, leaving each form's request guard and validation intact.
class FarmSubmitLabel extends StatelessWidget {
  final bool busy;
  final String label;
  final String busyLabel;
  const FarmSubmitLabel({
    super.key,
    required this.busy,
    required this.label,
    this.busyLabel = 'Đang lưu…',
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy) ...[
        const ExcludeSemantics(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        const SizedBox(width: FarmSpacing.sm),
      ],
      Flexible(
        child: Text(busy ? busyLabel : label, textAlign: TextAlign.center),
      ),
    ],
  );
}

/// The same form state is kept when the viewport changes between phone/dialog.
class FarmFormLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const FarmFormLayout({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600) {
      return AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(FarmSpacing.xl),
        title: Text(title),
        content: SizedBox(width: 480, child: child),
        actionsPadding: const EdgeInsets.fromLTRB(
          FarmSpacing.xl,
          0,
          FarmSpacing.xl,
          FarmSpacing.xl,
        ),
        actions: actions,
      );
    }
    return Dialog.fullscreen(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(FarmSpacing.lg),
                child: FarmSectionHeader(title: title),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    FarmSpacing.lg,
                    0,
                    FarmSpacing.lg,
                    FarmSpacing.lg,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: FarmInfoCard(child: child),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(FarmSpacing.lg),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: FarmSpacing.md),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
