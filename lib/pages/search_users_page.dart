import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/friend_service.dart';

class SearchUsersPage extends StatefulWidget {
  final UserModel currentUser;

  const SearchUsersPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _firestoreService.searchUsers(query);
      setState(() {
        _searchResults = results
            .where((user) => user.uid != widget.currentUser.uid)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSearchingUsers),
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    try {
      await _friendService.sendFriendRequest(widget.currentUser.uid, friendId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.friendRequestSent),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.searchUsers),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchUsersHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noUsersFound,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isFriend =
                              widget.currentUser.friends.contains(user.uid);
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user.fullName),
                              subtitle: Text(user.email),
                              trailing: isFriend
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : hasPendingRequest
                                      ? Text(AppLocalizations.of(context)!
                                          .pendingRequest)
                                      : hasSentRequest
                                          ? Text(AppLocalizations.of(context)!
                                              .requestSent)
                                          : IconButton(
                                              icon:
                                                  const Icon(Icons.person_add),
                                              onPressed: () =>
                                                  _sendFriendRequest(user.uid),
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
