import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/providers/app_state_provider.dart';
import 'features/navigation/presentation/screens/main_layout.dart';
import 'features/users/domain/repositories/user_repository.dart';
import 'features/users/data/repositories/user_repository_impl.dart';
import 'features/drivers/domain/repositories/driver_repository.dart';
import 'features/drivers/data/repositories/driver_repository_impl.dart';
import 'features/requests/domain/repositories/request_repository.dart';
import 'features/requests/data/repositories/request_repository_impl.dart';
import 'features/live_tracking/domain/repositories/driver_location_repository.dart';
import 'features/live_tracking/data/repositories/driver_location_repository_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BiongoAdminApp());
}

class BiongoAdminApp extends StatelessWidget {
  const BiongoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository Implementations
        Provider<UserRepository>(create: (_) => UserRepositoryImpl()),
        Provider<DriverRepository>(create: (_) => DriverRepositoryImpl()),
        Provider<RequestRepository>(create: (_) => RequestRepositoryImpl()),
        Provider<DriverLocationRepository>(
          create: (_) => DriverLocationRepositoryImpl(),
        ),
        
        // State Providers
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: MaterialApp(
        title: 'Biongo Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainLayout(),
      ),
    );
  }
}
