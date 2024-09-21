import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import '../AuthFlow/AuthFlow.dart';

class AccountEditPage extends StatefulWidget {
  @override
  _AccountEditPageState createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _pledgeClassController;
  late TextEditingController _majorController;
  late TextEditingController _graduationYearController;

  String? _currentProfileImageUrl;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _pledgeClassController = TextEditingController();
    _majorController = TextEditingController();
    _graduationYearController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      _firstNameController.text = userData['firstName'] ?? '';
      _lastNameController.text = userData['lastName'] ?? '';
      _pledgeClassController.text = userData['pledgeClass'] ?? '';
      _majorController.text = userData['major'] ?? '';
      _graduationYearController.text =
          userData['graduationYear']?.toString() ?? '';
      _currentProfileImageUrl = userData['profileImageUrl'];
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File? croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null) {
        File compressedFile = await compressImage(croppedFile);
        setState(() {
          _imageFile = compressedFile;
        });
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: Color(0xFF121212),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          statusBarColor: Color(0xFF121212),
          activeControlsWidgetColor: AgoraTheme.accentColor,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
        dir.absolute.path, "${path.basename(file.path)}_compressed.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 88,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) {
      return file;
    }

    if (await result.length() > 500 * 1024) {
      result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null || await result.length() > 500 * 1024) {
        result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );
      }
    }

    return File(result?.path ?? file.path);
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        String fileName = '${_auth.currentUser!.uid}_profile.jpg';
        Reference ref = _storage.ref().child('profile_images/$fileName');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'pledgeClass': _pledgeClassController.text,
        'major': _majorController.text,
        'graduationYear': int.tryParse(_graduationYearController.text),
        if (imageUrl != null) 'profileImageUrl': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Edit Account',
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfilePicture(),
                    SizedBox(height: 24),
                    _buildTextField(_firstNameController, 'First Name'),
                    SizedBox(height: 16),
                    _buildTextField(_lastNameController, 'Last Name'),
                    SizedBox(height: 16),
                    _buildTextField(_pledgeClassController, 'Pledge Class'),
                    SizedBox(height: 16),
                    _buildTextField(_majorController, 'Major'),
                    SizedBox(height: 16),
                    _buildTextField(
                        _graduationYearController, 'Graduation Year'),
                    SizedBox(height: 32),
                    _buildUpdateButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : _currentProfileImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_currentProfileImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: (_imageFile == null && _currentProfileImageUrl == null)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 40, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style:
                        GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: CircleAvatar(
                  backgroundColor: AgoraTheme.accentColor,
                  radius: 18,
                  child: Icon(Icons.edit, size: 18, color: Colors.white),
                ),
              ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        cursorColor: Colors.white,
        controller: controller,
        style: GoogleFonts.roboto(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.roboto(color: Colors.white60),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildUpdateButton() {
    return ElevatedButton(
      onPressed: _updateProfile,
      child: Text(
        'Update Profile',
        style: GoogleFonts.roboto(fontSize: 16, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AgoraTheme.accentColor,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pledgeClassController.dispose();
    _majorController.dispose();
    _graduationYearController.dispose();
    super.dispose();
  }
}
