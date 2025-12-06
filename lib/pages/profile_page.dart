import 'package:flutter/material.dart';
import 'package:p7/components/bio_box.dart';
import 'package:p7/components/input_box.dart';
import 'package:p7/models/user.dart';
import 'package:p7/service/database_provider.dart';
import 'package:provider/provider.dart';

import 'package:p7/components/avatar_picker.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  const ProfilePage({super.key, required this.uid});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final DatabaseProvider _databaseProvider;
  UserProfile? _user;
  final _bioCtrl = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _databaseProvider = context.read<DatabaseProvider>();
    _loadUser();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await _databaseProvider.userProfile(widget.uid);
    if (mounted) {
      setState(() {
        _user = u;
        _loading = false;
      });
    }
  }

  /* ---------- BIO ----------- */

  void _showBioEditor() {
    _bioCtrl.text = _user?.bio ?? '';
    showDialog(
      context: context,
      builder: (_) => InputBox(
        textEditingController: _bioCtrl,
        hintText: 'Edit bio',
        onPressed: _saveBio,
        onPressedText: 'Save',
      ),
    );
  }

  Future<void> _saveBio() async {
    setState(() => _loading = true);

    await _databaseProvider.updateBio(_bioCtrl.text);
    await _loadUser();
    setState(() {
      _loading=false;
    });

  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _loading ? 'Loading...' : (_user?.name ?? 'Profile'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(
        child: Text(
          'User not found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: ListView(
          children: [
            Center(
              child: Text(
                '@${_user!.username}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface,
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Center(child: AvatarPicker()),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cake,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    children: [
                      const TextSpan(text: 'Age: '),
                      TextSpan(
                        text: '${_calculateAge(_user!.birthDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' years'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bio',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: _showBioEditor,
                  icon: Icon(Icons.edit,
                      color: Theme.of(context)
                          .colorScheme
                          .primary),
                ),
              ],
            ),
            BioBox(text: _user!.bio.isEmpty ? '...' : _user!.bio),
          ],
        ),
      ),
    );
  }
}