import 'package:flutter/material.dart' hide CarouselController;
import 'package:google_fonts/google_fonts.dart';
import '../AuthFlow/AuthFlow.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './AccountEdit.dart';

class SettingsPage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSettingItem(
            icon: Icons.person,
            title: 'Account',
            onTap: () {
              print("Called");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountEditPage()),
              );
            },
          ),
          // _buildSettingItem(
          //   icon: Icons.notifications,
          //   title: 'Notifications',
          //   onTap: () {
          //     // Navigate to notification settings
          //   },
          // ),
          // _buildSettingItem(
          //   icon: Icons.privacy_tip,
          //   title: 'Privacy',
          //   onTap: () {
          //     // Navigate to privacy settings
          //   },
          // ),
          // _buildSettingItem(
          //   icon: Icons.help,
          //   title: 'Help & Support',
          //   onTap: () {
          //     // Navigate to help and support
          //   },
          // ),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              _signOut(context);
            },
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => AgoraAuthFlow()),
      (Route<dynamic> route) => false,
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white70),
      onTap: onTap,
    );
  }
}
