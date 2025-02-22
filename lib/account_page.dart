import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'auth_page.dart';


class AccountPage extends StatelessWidget {
  final AuthService _authService = AuthService();

  AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    if (user == null) {
      return const AuthPage();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            user.email ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              // Implement edit profile functionality
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
    );
  }
}