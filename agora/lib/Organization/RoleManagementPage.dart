import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleManagementPage extends StatefulWidget {
  final String chapterId;

  RoleManagementPage({required this.chapterId});

  @override
  _RoleManagementPageState createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Role> _roles = [];
  List<Role> _filteredRoles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chapterDoc =
          await _firestore.collection('chapters').doc(widget.chapterId).get();
      final rolesData = chapterDoc.data()?['roles'] as List<dynamic>? ?? [];

      _roles = rolesData.map((roleData) => Role.fromMap(roleData)).toList();
      _roles.sort((a, b) => a.name.compareTo(b.name));
      _filteredRoles = List.from(_roles);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching roles: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch roles. Please try again.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterRoles(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredRoles = List.from(_roles);
      } else {
        _filteredRoles = _roles
            .where(
                (role) => role.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Manage Roles',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: _showAddRoleDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white60))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        SizedBox(height: 20),
                        Text(
                          'Roles',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildRolesList(),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        style: GoogleFonts.roboto(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search roles',
          hintStyle: GoogleFonts.roboto(color: Colors.white38),
          icon: Icon(Icons.search, color: Colors.white38, size: 20),
          border: InputBorder.none,
        ),
        onChanged: _filterRoles,
      ),
    );
  }

  Widget _buildRolesList() {
    if (_filteredRoles.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            _searchQuery.isEmpty ? 'No roles found' : 'No matching roles',
            style: GoogleFonts.roboto(color: Colors.white60, fontSize: 16),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final role = _filteredRoles[index];
          return _buildRoleItem(role, index);
        },
        childCount: _filteredRoles.length,
      ),
    );
  }

  Widget _buildRoleItem(Role role, int index) {
    return InkWell(
      onTap: () => _navigateToRoleDetails(role),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${role.memberIds.length} members',
                    style:
                        GoogleFonts.roboto(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms);
  }

  void _navigateToRoleDetails(Role role) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleDetailsPage(
          chapterId: widget.chapterId,
          role: role,
        ),
      ),
    );
    if (result == true) {
      _fetchRoles(); // Refresh the roles list
    }
  }

  void _showAddRoleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newRoleName = '';
        return AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          title: Text('Add New Role',
              style: GoogleFonts.roboto(color: Colors.white)),
          content: TextField(
            cursorColor: Colors.white,
            autofocus: true,
            style: GoogleFonts.roboto(
                color: Colors.white, decorationColor: Colors.white),
            decoration: InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              hintText: 'Enter role name',
              hintStyle: GoogleFonts.roboto(color: Colors.white54),
            ),
            onChanged: (value) {
              newRoleName = value;
            },
          ),
          actions: [
            TextButton(
              child: Text('Cancel',
                  style: GoogleFonts.roboto(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add',
                  style: GoogleFonts.roboto(
                      color: Theme.of(context).primaryColor)),
              onPressed: () {
                if (newRoleName.isNotEmpty) {
                  _addNewRole(newRoleName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _addNewRole(String name) async {
    try {
      final newRole = Role(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        permissions: [],
        memberIds: [],
      );

      await _firestore.collection('chapters').doc(widget.chapterId).update({
        'roles': FieldValue.arrayUnion([newRole.toMap()])
      });

      _fetchRoles();
    } catch (e) {
      print('Error adding new role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add new role. Please try again.')),
      );
    }
  }
}

class RoleDetailsPage extends StatefulWidget {
  final String chapterId;
  final Role role;

  RoleDetailsPage({required this.chapterId, required this.role});

  @override
  _RoleDetailsPageState createState() => _RoleDetailsPageState();
}

class _RoleDetailsPageState extends State<RoleDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _members = [];
  late Role _role;
  List<String> _allPermissions = [
    'Manage Events',
    'Manage Roles',
    'View Attendance',
    'Edit Attendance'
  ];
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
  }

  Future<List<Map<String, dynamic>>> _fetchRoleMembers() async {
    try {
      if (_role.memberIds.isEmpty) {
        // If there are no members, return an empty list
        return [];
      }

      final membersQuery = await _firestore
          .collection('users')
          .where('greekOrganizationName', isEqualTo: "Phi Kappa Tau")
          .where(FieldPath.documentId, whereIn: _role.memberIds)
          .get();

      List<Map<String, dynamic>> roleMembers = membersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName']} ${data['lastName']}',
        };
      }).toList();

      roleMembers.sort((a, b) => a['name'].compareTo(b['name']));
      return roleMembers;
    } catch (e) {
      print('Error fetching role members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to fetch role members. Please try again.')),
      );
      return [];
    }
  }

  Future<void> _updateRole() async {
    try {
      final updatedMemberIds = _members
          .where((member) => member['isSelected'])
          .map((member) => member['id'] as String)
          .toList();

      // Fetch the current chapter document
      final chapterDoc =
          await _firestore.collection('chapters').doc(widget.chapterId).get();
      final roles =
          List<Map<String, dynamic>>.from(chapterDoc.data()?['roles'] ?? []);

      // Update the role
      final roleIndex = roles.indexWhere((r) => r['id'] == widget.role.id);
      if (roleIndex != -1) {
        roles[roleIndex] = {
          ...roles[roleIndex],
          'memberIds': updatedMemberIds,
        };
      }

      // Update the chapter document
      await _firestore.collection('chapters').doc(widget.chapterId).update({
        'roles': roles,
      });

      // Update user profiles
      for (var member in _members) {
        final userId = member['id'];
        final isSelected = member['isSelected'];

        final userDoc = await _firestore.collection('users').doc(userId).get();
        List<String> userRoles =
            List<String>.from(userDoc.data()?['roles'] ?? []);

        if (isSelected && !userRoles.contains(widget.role.name)) {
          userRoles.add(widget.role.name);
        } else if (!isSelected && userRoles.contains(widget.role.name)) {
          userRoles.remove(widget.role.name);
        }

        await _firestore.collection('users').doc(userId).update({
          'roles': userRoles,
        });
      }

      widget.role.memberIds = updatedMemberIds;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role members updated successfully')),
      );
    } catch (e) {
      print('Error updating role members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update role members. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_dataChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            _role.name,
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRoleMembers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: Colors.white60));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              List<Map<String, dynamic>> roleMembers = snapshot.data ?? [];
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPermissionsSection(),
                      SizedBox(height: 30),
                      _buildMembersSummary(roleMembers),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _allPermissions.length,
          itemBuilder: (context, index) {
            final permission = _allPermissions[index];
            final isSelected = _role.permissions.contains(permission);
            return ListTile(
              title: Text(
                permission,
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              trailing: Switch(
                value: isSelected,
                onChanged: (bool value) {
                  setState(() {
                    if (value) {
                      _role.permissions.add(permission);
                    } else {
                      _role.permissions.remove(permission);
                    }
                  });
                  _updateRole();
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMembersSummary(List<Map<String, dynamic>> roleMembers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _navigateToMemberManagement,
              child: Text(
                'Manage',
                style:
                    GoogleFonts.roboto(color: Theme.of(context).primaryColor),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (roleMembers.isEmpty)
          Text(
            'No members in this role',
            style: GoogleFonts.roboto(color: Colors.white60, fontSize: 14),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: roleMembers.length,
            itemBuilder: (context, index) {
              final member = roleMembers[index];
              return ListTile(
                title: Text(
                  member['name'],
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
              );
            },
          ),
      ],
    );
  }

  void _navigateToMemberManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleMemberManagementPage(
          chapterId: widget.chapterId,
          role: _role,
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _dataChanged = true;
      });
      // Refresh the page
      setState(() {});
    }
  }
}

class Role {
  final String id;
  final String name;
  List<String> permissions;
  List<String> memberIds;

  Role({
    required this.id,
    required this.name,
    required this.permissions,
    required this.memberIds,
  });

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'],
      name: map['name'],
      permissions: List<String>.from(map['permissions']),
      memberIds: List<String>.from(map['memberIds']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'permissions': permissions,
      'memberIds': memberIds,
    };
  }
}

// You can add this extension to your existing imports
extension CapExtension on String {
  String get capitalize => '${this[0].toUpperCase()}${this.substring(1)}';
}

class RoleMemberManagementPage extends StatefulWidget {
  final String chapterId;
  final Role role;

  RoleMemberManagementPage({required this.chapterId, required this.role});

  @override
  _RoleMemberManagementPageState createState() =>
      _RoleMemberManagementPageState();
}

class _RoleMemberManagementPageState extends State<RoleMemberManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final membersQuery = await _firestore
          .collection('users')
          .where('greekOrganizationName', isEqualTo: 'Phi Kappa Tau')
          .get();

      _members = membersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName']} ${data['lastName']}',
          'isSelected': widget.role.memberIds.contains(doc.id),
        };
      }).toList();

      _members.sort((a, b) => a['name'].compareTo(b['name']));
      _filteredMembers = List.from(_members);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch members. Please try again.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members
            .where((member) =>
                member['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _updateRole() async {
    try {
      final updatedMemberIds = _members
          .where((member) => member['isSelected'])
          .map((member) => member['id'] as String)
          .toList();

      // Fetch the current chapter document
      final chapterDoc =
          await _firestore.collection('chapters').doc(widget.chapterId).get();
      final roles =
          List<Map<String, dynamic>>.from(chapterDoc.data()?['roles'] ?? []);

      // Remove the old role
      roles.removeWhere((r) => r['id'] == widget.role.id);

      // Create the updated role
      final updatedRole = {
        'id': widget.role.id,
        'name': widget.role.name,
        'permissions': widget.role.permissions,
        'memberIds': updatedMemberIds,
      };

      // Add the updated role
      roles.add(updatedRole);

      // Update the entire roles array
      await _firestore.collection('chapters').doc(widget.chapterId).update({
        'roles': roles,
      });

      // Update user documents
      for (var member in _members) {
        final userId = member['id'];
        final isSelected = member['isSelected'];

        final userDoc = await _firestore.collection('users').doc(userId).get();
        List<String> userRoles =
            List<String>.from(userDoc.data()?['roles'] ?? []);

        if (isSelected && !userRoles.contains(widget.role.name)) {
          userRoles.add(widget.role.name);
        } else if (!isSelected && userRoles.contains(widget.role.name)) {
          userRoles.remove(widget.role.name);
        }

        await _firestore.collection('users').doc(userId).update({
          'roles': userRoles,
        });
      }

      widget.role.memberIds = updatedMemberIds;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role members updated successfully')),
      );
    } catch (e) {
      print('Error updating role members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update role members. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop(true); // Indicate that changes were made
          return false;
        },
        child: Scaffold(
          backgroundColor: Color(0xFF121212),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              '${widget.role.name} Members',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.white60))
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: _buildSearchBar(),
                    ),
                    Expanded(
                      child: _buildMembersList(),
                    ),
                  ],
                ),
        ));
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        style: GoogleFonts.roboto(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search members',
          hintStyle: GoogleFonts.roboto(color: Colors.white38),
          icon: Icon(Icons.search, color: Colors.white38, size: 20),
          border: InputBorder.none,
        ),
        onChanged: _filterMembers,
      ),
    );
  }

  Widget _buildMembersList() {
    if (_filteredMembers.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No members found' : 'No matching members',
          style: GoogleFonts.roboto(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        final member = _filteredMembers[index];
        return _buildMemberItem(member, index);
      },
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member, int index) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member['name'],
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              member['isSelected']
                  ? Icons.check_circle
                  : Icons.add_circle_outline,
              color: member['isSelected']
                  ? Theme.of(context).primaryColor
                  : Colors.white70,
            ),
            onPressed: () {
              setState(() {
                member['isSelected'] = !member['isSelected'];
                final index =
                    _members.indexWhere((m) => m['id'] == member['id']);
                if (index != -1) {
                  _members[index]['isSelected'] = member['isSelected'];
                }
              });
              _updateRole();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms);
  }
}
