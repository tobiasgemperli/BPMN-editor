import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../diagram/io/api_client.dart';

/// Bottom sheet for editing the signed-in user's profile: name, surname,
/// email, phone, avatar, and password. Returns true if anything was saved.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  ApiUserSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Newly-picked avatar (raw bytes for preview, base64 for upload).
  Uint8List? _avatarBytes;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ApiClient.instance.getUserSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _name.text = s.name;
        _surname.text = s.surname;
        _email.text = s.email;
        _phone.text = s.phone;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your profile.';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarBase64 = base64Encode(bytes);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.updateUserSettings(
        name: _name.text.trim(),
        surname: _surname.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        thumbnailBase64: _avatarBase64,
      );
      if (_password.text.isNotEmpty) {
        await ApiClient.instance.setPassword(_password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: (mq.size.height - mq.viewInsets.bottom) * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  const Text('Edit Profile',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const Spacer(),
                  TextButton(
                    onPressed: (_saving || _loading) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _avatarPicker()),
                      const SizedBox(height: 20),
                      _field('Name', _name),
                      _field('Surname', _surname),
                      _field('Email', _email,
                          keyboardType: TextInputType.emailAddress),
                      _field('Phone', _phone,
                          keyboardType: TextInputType.phone),
                      if (_settings != null) _readOnly('Username', _settings!.uname),
                      const SizedBox(height: 8),
                      Text('Change Password',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: _decoration('New password (leave blank to keep)'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(
                                color: Color(0xFFFF3B30), fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPicker() {
    final userId = int.tryParse(_settings?.id ?? '');
    Widget avatar;
    if (_avatarBytes != null) {
      avatar = Image.memory(_avatarBytes!, fit: BoxFit.cover);
    } else if (userId != null) {
      avatar = FutureBuilder<Uint8List?>(
        future: ApiClient.instance.getUserThumbnail(userId),
        builder: (context, snap) => snap.data != null
            ? Image.memory(snap.data!, fit: BoxFit.cover)
            : _avatarPlaceholder(),
      );
    } else {
      avatar = _avatarPlaceholder();
    }
    return GestureDetector(
      onTap: _pickAvatar,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(width: 88, height: 88, child: avatar),
          ),
          const SizedBox(height: 8),
          const Text('Change photo',
              style: TextStyle(color: Color(0xFF007AFF), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: const Color(0xFFF2F4F7),
        child: const Icon(Icons.person, color: Colors.black26, size: 44),
      );

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E))),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: keyboardType,
            decoration: _decoration(null),
          ),
        ],
      ),
    );
  }

  Widget _readOnly(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value.isEmpty ? '—' : value,
                  style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        ),
      );

  InputDecoration _decoration(String? hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}
