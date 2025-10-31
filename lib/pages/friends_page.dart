import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/friend_service.dart';

class FriendsPage extends StatefulWidget {
  final UserModel currentUser;

  const FriendsPage({super.key, required this.currentUser});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FriendService _friendService = FriendService();
  List<UserModel> _friends = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends =
          await _firestoreService.getUserFriends(widget.currentUser.uid);
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingFriends),
          ),
        );
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _firestoreService.searchUsers(query);
      setState(() {
        _searchResults = results
            .where((user) => user.uid != widget.currentUser.uid)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSearchingUsers),
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(UserModel user) async {
    try {
      await _friendService.sendFriendRequest(widget.currentUser.uid, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.friendRequestSent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await _friendService.removeFriend(widget.currentUser.uid, friendId);
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.friendRemoved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorRemovingFriend),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friends),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchUsersHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noUsersFound,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final isFriend =
                                  _friends.any((f) => f.uid == user.uid);
                              final hasPendingRequest = widget
                                  .currentUser.pendingFriendRequests
                                  .contains(user.uid);
                              final hasSentRequest = widget
                                  .currentUser.sentFriendRequests
                                  .contains(user.uid);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      user.fullName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: Text(user.email),
                                  trailing: isFriend
                                      ? IconButton(
                                          icon: const Icon(Icons.person_remove),
                                          onPressed: () =>
                                              _removeFriend(user.uid),
                                        )
                                      : hasPendingRequest
                                          ? Text(l10n.pendingRequest)
                                          : hasSentRequest
                                              ? Text(l10n.requestSent)
                                              : ElevatedButton(
                                                  onPressed: () =>
                                                      _sendFriendRequest(user),
                                                  child: Text(l10n.addFriend),
                                                ),
                                ),
                              );
                            },
                          )
                    : _friends.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noFriends,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _friends.length,
                            itemBuilder: (context, index) {
                              final friend = _friends[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      friend.fullName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(friend.fullName),
                                  subtitle: Text(friend.email),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.person_remove),
                                    onPressed: () => _removeFriend(friend.uid),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
