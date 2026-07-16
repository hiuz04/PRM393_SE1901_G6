import 'package:cine_x/core/network/backend_connection_provider.dart';
import 'package:cine_x/features/auth/presentation/providers/auth_provider.dart';
import 'package:cine_x/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Login validates password strength', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider.empty()..initializing = false,
          ),
          ChangeNotifierProvider(
            create: (_) => BackendConnectionProvider.empty(),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(1), 'weak');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });
}
