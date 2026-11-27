import 'package:material_ui/material_ui.dart';

import '../state/library_controller.dart';

/// Switches between the permission, failure, and ready states of the library.
class AccessGate extends StatelessWidget {
  const AccessGate({
    required this.controller,
    required this.ready,
    super.key,
  });

  final LibraryController controller;
  final WidgetBuilder ready;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        switch (controller.status) {
          case LibraryStatus.checking:
            return const Center(child: CircularProgressIndicator());
          case LibraryStatus.needsPermission:
            return _StatusMessage(
              icon: Icons.photo_library_outlined,
              title: 'Photos stay on this phone',
              body: _withError(
                'Albumseek reads pictures from the library on this device and shows them in a grid.',
                controller.errorMessage,
              ),
              actions: [
                _PrimaryButton(
                  label: 'Allow photo access',
                  onPressed: controller.requestAccess,
                ),
                _SecondaryButton(
                  label: 'Choose photos',
                  onPressed: controller.pickWithSystemPicker,
                ),
              ],
            );
          case LibraryStatus.denied:
            return _StatusMessage(
              icon: Icons.lock_outline,
              title: 'Photo access is off',
              body: _withError(
                'Allow photo access in Settings to browse the library on this phone. '
                'You can also choose pictures with the system picker.',
                controller.errorMessage,
              ),
              actions: [
                _PrimaryButton(
                  label: 'Allow photo access',
                  onPressed: controller.requestAccess,
                ),
                _SecondaryButton(
                  label: 'Open settings',
                  onPressed: controller.openSettings,
                ),
                _SecondaryButton(
                  label: 'Choose photos',
                  onPressed: controller.pickWithSystemPicker,
                ),
              ],
            );
          case LibraryStatus.failed:
            return _StatusMessage(
              icon: Icons.error_outline,
              title: 'The photo library could not be read',
              body:
                  controller.errorMessage ??
                  'The photo library could not be read.',
              actions: [
                _PrimaryButton(
                  label: 'Try again',
                  onPressed: controller.refresh,
                ),
                _SecondaryButton(
                  label: 'Choose photos',
                  onPressed: controller.pickWithSystemPicker,
                ),
              ],
            );
          case LibraryStatus.ready:
            return ready(context);
        }
      },
    );
  }
}

String _withError(String body, String? error) {
  if (error == null || error.isEmpty) {
    return body;
  }
  return '$body\n\n$error';
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
