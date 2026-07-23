import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/state_views.dart';
import '../../../../providers/auth_provider.dart';
import '../../../projects/presentation/screens/project_launcher_screen.dart';
import 'auth_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AuthProvider>().bootstrap(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.initializing) {
      return const Scaffold(
        body: LoadingView(message: 'Đang chuẩn bị studio của bạn'),
      );
    }
    return auth.authenticated
        ? const ProjectLauncherScreen()
        : const AuthScreen();
  }
}
