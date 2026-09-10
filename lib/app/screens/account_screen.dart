import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../diagram/io/api_client.dart';
import '../../diagram/samples/sample_diagrams.dart';
import 'discover_screen.dart';
import 'edit_profile_sheet.dart';

/// Account tab — the signed-in user's profile plus Following / Followers.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _name = 'My Account';
  int? _myId;
  List<ApiUserRef>? _following;
  List<ApiUserRef>? _followers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient.instance;
      final id = await api.currentUserId();
      final profile = await api.getUserProfile(id);
      final following = await api.getFollowing();
      final followers = await api.getFollowers();
      if (!mounted) return;
      setState(() {
        _myId = id;
        if (profile.name.isNotEmpty) _name = profile.name;
        _following = following;
        _followers = followers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openUser(ApiUserRef u) {
    final name = u.name.isNotEmpty ? u.name : u.uname;
    showCreatorProfile(
      context,
      SampleCreator(
        id: '${u.id}',
        name: name,
        initials: _initials(name),
        colorValue: 0xFF007AFF,
        bio: '',
        followers: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                    top: topPad + 16, left: 20, right: 20, bottom: 16),
                child: Row(
                  children: [
                    Text(
                      'Account',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1C1C1E),
                              ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openEditProfile,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1C1C1E),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              _profileHeader(),
              const SizedBox(height: 8),
              Material(
                color: Colors.grey[50],
                child: TabBar(
                  labelColor: const Color(0xFF1C1C1E),
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: const Color(0xFF1C1C1E),
                  labelStyle:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Following (${_following?.length ?? 0})'),
                    Tab(text: 'Followers (${_followers?.length ?? 0})'),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TabBarView(
                        children: [
                          _userList(_following ?? const [], 'not following anyone yet'),
                          _userList(_followers ?? const [], 'no followers yet'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final saved = await showEditProfileSheet(context);
    if (saved == true) _load(); // refresh name/avatar
  }

  Widget _profileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _UserAvatar(
              userId: _myId,
              initials: _initials(_name),
              size: 56,
              background: const Color(0xFF007AFF),
              textColor: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_following?.length ?? 0} following · '
                    '${_followers?.length ?? 0} followers',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF636366)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userList(List<ApiUserRef> users, String emptyLabel) {
    if (users.isEmpty) {
      return Center(
        child: Text(emptyLabel,
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: users.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 60, color: Colors.grey[200]),
      itemBuilder: (context, i) => _UserRow(user: users[i], onTap: _openUser),
    );
  }

  static String _initials(String s) {
    final parts =
        s.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }
}

/// Circular avatar that loads a user's `/user/thumbnail/{id}` image, falling
/// back to initials while loading or when the user has no picture.
class _UserAvatar extends StatelessWidget {
  final int? userId;
  final String initials;
  final double size;
  final Color background;
  final Color textColor;

  const _UserAvatar({
    required this.userId,
    required this.initials,
    required this.size,
    required this.background,
    required this.textColor,
  });

  Widget _initialsChild() => Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget inner;
    final id = userId;
    if (id == null) {
      inner = _initialsChild();
    } else {
      inner = FutureBuilder<Uint8List?>(
        future: ApiClient.instance.getUserThumbnail(id),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes != null) {
            return Image.memory(bytes,
                width: size, height: size, fit: BoxFit.cover);
          }
          return _initialsChild();
        },
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: inner,
    );
  }
}

class _UserRow extends StatelessWidget {
  final ApiUserRef user;
  final void Function(ApiUserRef) onTap;

  const _UserRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user.name.isNotEmpty ? user.name : user.uname;
    return GestureDetector(
      onTap: () => onTap(user),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _UserAvatar(
              userId: user.id,
              initials: _AccountScreenState._initials(name),
              size: 40,
              background: Colors.grey[300]!,
              textColor: const Color(0xFF1C1C1E),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.uname.isNotEmpty)
                    Text(
                      '@${user.uname}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
