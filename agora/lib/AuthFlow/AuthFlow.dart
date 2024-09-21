import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../main.dart';
import 'package:image_cropper/image_cropper.dart';

class AgoraTheme {
  static const backgroundColor = Color(0xFF121212);
  static const surfaceColor = Color(0xFF1E1E1E);
  static const primaryColor = Color(0xFF368eae);
  static const accentColor = Color(0xFF1C7BA7);
  static const textColor = Color(0xFFE0E0E0);
  static const subtleTextColor = Color(0xFF9E9E9E);
  static const inputFillColor = Color(0xFF2A2A2A);
}

class AgoraAuthFlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF121212),
        primaryColor: Color(0xFF1E1E1E),
        hintColor: Color(0xFFE0E0E0),
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      home: WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Email Verification Required'),
            content: Text(
              'Please verify your email to complete the registration process. Check your inbox for the verification email.',
            ),
            actions: [
              TextButton(
                child: Text('Resend Email'),
                onPressed: () async {
                  await user.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification email resent')),
                  );
                },
              ),
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgoraTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'AGORA',
                    style: GoogleFonts.vollkorn(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AgoraTheme.primaryColor,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 1000.ms)
                      .slideY(begin: -0.2, end: 0),
                  SizedBox(height: 16),
                  Text(
                    'Elevate Your Greek Life Experience',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AgoraTheme.subtleTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 500.ms, duration: 800.ms),
                  SizedBox(height: 80),
                  _buildElegantButton('Sign In', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SignInPage()));
                  }),
                  SizedBox(height: 16),
                  _buildElegantButton('Sign Up', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SignUpPage()));
                  }, isOutlined: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantButton(String label, VoidCallback onPressed,
      {bool isOutlined = false}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isOutlined
            ? null
            : LinearGradient(
                colors: [AgoraTheme.primaryColor, AgoraTheme.accentColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        border: isOutlined
            ? Border.all(color: AgoraTheme.primaryColor, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isOutlined ? AgoraTheme.primaryColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: isOutlined ? 1000.ms : 800.ms, duration: 800.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgoraTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AgoraTheme.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome Back',
                    style: GoogleFonts.roboto(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AgoraTheme.textColor,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .slideX(begin: -0.2, end: 0),
                  SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AgoraTheme.subtleTextColor,
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
                  SizedBox(height: 48),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildElegantTextField('Email', _emailController,
                              validator: _validateEmail),
                          SizedBox(height: 24),
                          _buildElegantTextField(
                              'Password', _passwordController,
                              isPassword: true, validator: _validatePassword),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  AgoraDialogs.showForgotPasswordDialog(
                                      context),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.roboto(
                                  color: AgoraTheme.accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Spacer(),
                          _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AgoraTheme.primaryColor))
                              : _buildSignInButton(),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantTextField(String label, TextEditingController controller,
      {bool isPassword = false, String? Function(String?)? validator}) {
    return TextFormField(
      cursorColor: Colors.white,
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.roboto(color: AgoraTheme.textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(color: AgoraTheme.subtleTextColor),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: AgoraTheme.subtleTextColor.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AgoraTheme.accentColor),
        ),
        filled: true,
        fillColor: AgoraTheme.inputFillColor,
      ),
      validator: validator,
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildSignInButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [AgoraTheme.primaryColor, AgoraTheme.accentColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _signIn,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              'Sign In',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 800.ms)
        .slideY(begin: 0.2, end: 0);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          if (userCredential.user!.emailVerified) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid)
                .update({
              'emailVerified': true,
            });

            // Navigate to HomePage
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomePage()),
            );
          } else {
            _showEmailVerificationDialog(userCredential.user!);
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect email or password. Please try again.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is not valid.';
            break;
          case 'user-disabled':
            errorMessage =
                'This account has been disabled. Please contact support.';
            break;
          case 'too-many-requests':
            errorMessage =
                'Too many failed login attempts. Please try again later.';
            break;
          case 'invalid-credential':
            errorMessage = 'Incorrect email or password. Please try again.';
            break;
          default:
            errorMessage =
                'An error occurred during sign in. Please try again.';
        }
        _showErrorDialog(errorMessage);
      } catch (e) {
        _showErrorDialog('An unexpected error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Email Not Verified'),
          content: Text(
              'Please verify your email to sign in. If you haven\'t received the verification email, you can request a new one.'),
          actions: [
            TextButton(
              child: Text(
                'Resend Verification Email',
                style: TextStyle(
                  color: AgoraTheme.primaryColor,
                ),
              ),
              onPressed: () async {
                await user.sendEmailVerification();
                Navigator.of(context).pop();
                _showErrorDialog(
                    'Verification email sent. Please check your inbox.');
              },
            ),
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog() {
    AgoraDialogs.showForgotPasswordDialog(context);
    // final _resetEmailController = TextEditingController();

    // showDialog(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: Text('Reset Password'),
    //       content: TextField(
    //         controller: _resetEmailController,
    //         decoration: InputDecoration(hintText: "Enter your email"),
    //       ),
    //       actions: [
    //         TextButton(
    //           child: Text('Cancel'),
    //           onPressed: () => Navigator.of(context).pop(),
    //         ),
    //         TextButton(
    //           child: Text('Send Reset Email'),
    //           onPressed: () async {
    //             try {
    //               await FirebaseAuth.instance.sendPasswordResetEmail(
    //                 email: _resetEmailController.text,
    //               );
    //               Navigator.of(context).pop();
    //               _showSuccessDialog(
    //                   'Password reset email sent. Please check your inbox.');
    //             } catch (e) {
    //               Navigator.of(context).pop();
    //               _showErrorDialog(
    //                   'Failed to send password reset email: ${e.toString()}');
    //             }
    //           },
    //         ),
    //       ],
    //     );
    //   },
    // );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AgoraTheme.primaryColor.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.7,
          size.width * 0.5, size.height * 0.8)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.9, size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = AgoraTheme.accentColor.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.85,
          size.width * 0.5, size.height * 0.9)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.95, size.width, size.height * 0.9)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AgoraDialogs {
  static Future<void> showForgotPasswordDialog(BuildContext context) async {
    final _resetEmailController = TextEditingController();
    bool _isLoading = false;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AgoraTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_reset,
                      size: 50, color: AgoraTheme.accentColor),
                  SizedBox(height: 20),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AgoraTheme.textColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    cursorColor: Colors.white,
                    controller: _resetEmailController,
                    style: GoogleFonts.roboto(color: AgoraTheme.textColor),
                    decoration: InputDecoration(
                      hintText: "Enter your email",
                      hintStyle:
                          GoogleFonts.roboto(color: AgoraTheme.subtleTextColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: AgoraTheme.subtleTextColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AgoraTheme.accentColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AgoraTheme.inputFillColor,
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDialogButton(
                        'Cancel',
                        () => Navigator.of(context).pop(),
                        isOutlined: true,
                      ),
                      _buildDialogButton(
                        'Send Reset Email',
                        _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                try {
                                  await FirebaseAuth.instance
                                      .sendPasswordResetEmail(
                                    email: _resetEmailController.text,
                                  );
                                  Navigator.of(context).pop();
                                  _showSuccessDialog(context,
                                      'Password reset email sent successfully. Please check your inbox.');
                                } catch (e) {
                                  _showErrorDialog(context,
                                      'Failed to send password reset email: ${e.toString()}');
                                } finally {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AgoraTheme.accentColor),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  static void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildDialogButton(String label, VoidCallback? onPressed,
      {bool isOutlined = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isOutlined ? AgoraTheme.accentColor : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: isOutlined ? AgoraTheme.accentColor : Colors.white,
        backgroundColor:
            isOutlined ? Colors.transparent : AgoraTheme.accentColor,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isOutlined
              ? BorderSide(color: AgoraTheme.accentColor)
              : BorderSide.none,
        ),
        elevation: isOutlined ? 0 : 2,
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  File? _profileImage;
  int _currentPage = 0;
  bool _isLoading = false;

  // Controllers for form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fraternityController = TextEditingController();
  final _chapterController = TextEditingController();
  final _pledgeClassController = TextEditingController();
  final _schoolController = TextEditingController();
  final _schoolMajorController = TextEditingController();
  final _graduationYearController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgoraTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: AgoraTheme.textColor),
                        onPressed: () {
                          if (_currentPage > 0) {
                            _pageController.previousPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      Text(
                        'Create Account',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AgoraTheme.textColor,
                        ),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      physics: NeverScrollableScrollPhysics(),
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildPersonalInfoPage(),
                        _buildSchoolInfoPage(),
                        _buildGreekInfoPage(),
                        _buildProfilePicturePage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AgoraTheme.textColor,
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2, end: 0),
          SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildElegantTextField('First Name', _firstNameController,
                      validator: _validateNotEmpty),
                  SizedBox(height: 24),
                  _buildElegantTextField('Last Name', _lastNameController,
                      validator: _validateNotEmpty),
                  SizedBox(height: 24),
                  _buildElegantTextField('Email', _emailController,
                      validator: _validateEmail),
                  SizedBox(height: 24),
                  _buildElegantTextField('Password', _passwordController,
                      isPassword: true, validator: _validatePassword),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildNextButton('Next', () {
            if (_formKey.currentState!.validate()) {
              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildSchoolInfoPage() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Details',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AgoraTheme.textColor,
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2, end: 0),
          SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildElegantDropdown(
                      'School', ['Cal State Long Beach'], _schoolController),
                  SizedBox(height: 24),
                  _buildElegantTextField('Major', _schoolMajorController),
                  SizedBox(height: 24),
                  _buildElegantTextField(
                      'Graduation Year', _graduationYearController,
                      validator: _validateGraduationYear),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildNextButton('Next', () {
            if (_formKey.currentState!.validate()) {
              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildGreekInfoPage() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Greek Life Details',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AgoraTheme.textColor,
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2, end: 0),
          SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildElegantDropdown(
                      'Fraternity', ['Phi Kappa Tau'], _fraternityController),
                  SizedBox(height: 24),
                  _buildElegantDropdown(
                      'Chapter', ['Beta Psi'], _chapterController),
                  SizedBox(height: 24),
                  _buildElegantTextField(
                      'Pledge Class', _pledgeClassController),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildNextButton('Next', () {
            if (_formKey.currentState!.validate()) {
              _pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildProfilePicturePage() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AgoraTheme.inputFillColor,
                      border:
                          Border.all(color: AgoraTheme.accentColor, width: 2),
                      image: _profileImage != null
                          ? DecorationImage(
                              image: FileImage(_profileImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 50, color: AgoraTheme.accentColor),
                              SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: GoogleFonts.roboto(
                                    color: AgoraTheme.accentColor),
                              ),
                            ],
                          )
                        : null,
                  ),
                ).animate().scale(duration: 800.ms),
                SizedBox(height: 16),
                Text(
                  _profileImage == null
                      ? 'Tap to add a profile picture'
                      : 'Tap to change profile picture',
                  style: GoogleFonts.roboto(color: AgoraTheme.subtleTextColor),
                ),
                if (_profileImage != null) ...[
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      'Recrop Image',
                      style: GoogleFonts.roboto(
                        color: AgoraTheme.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 32),
          Spacer(),
          _isLoading
              ? CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AgoraTheme.primaryColor))
              : _buildNextButton('Create Account', _signUp),
        ],
      ),
    );
  }

  Widget _buildElegantTextField(String label, TextEditingController controller,
      {bool isPassword = false, String? Function(String?)? validator}) {
    return TextFormField(
      cursorColor: Colors.white,
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.roboto(color: AgoraTheme.textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(color: AgoraTheme.subtleTextColor),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: AgoraTheme.subtleTextColor.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AgoraTheme.accentColor),
        ),
        filled: true,
        fillColor: AgoraTheme.inputFillColor,
      ),
      validator: validator,
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildElegantDropdown(
      String label, List<String> items, TextEditingController controller) {
    return DropdownButtonFormField<String>(
      style: GoogleFonts.roboto(color: AgoraTheme.textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(color: AgoraTheme.subtleTextColor),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: AgoraTheme.subtleTextColor.withOpacity(0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AgoraTheme.accentColor),
        ),
        filled: true,
        fillColor: AgoraTheme.inputFillColor,
      ),
      dropdownColor: AgoraTheme.inputFillColor,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          controller.text = newValue;
        }
      },
      validator: _validateNotEmpty,
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildNextButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [AgoraTheme.primaryColor, AgoraTheme.accentColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 800.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      CroppedFile? croppedImage = await _cropImage(image.path);
      if (croppedImage != null) {
        File compressedImage = await compressImage(File(croppedImage.path));
        setState(() {
          _profileImage = compressedImage;
        });
      }
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: AgoraTheme.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          statusBarColor: AgoraTheme.primaryColor,
          activeControlsWidgetColor: AgoraTheme.accentColor,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
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

    // Check if the compressed file is larger than 200KB
    if (await result.length() > 200 * 1024) {
      // If it's still larger, reduce quality and try again
      result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null || await result.length() > 200 * 1024) {
        // If it's still too large, reduce size
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

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a profile picture')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });
      try {
        // Create user account
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Send email verification
        await userCredential.user!.sendEmailVerification();

        // Upload profile picture if selected
        String? profileImageUrl;
        if (_profileImage != null) {
          Reference storageReference = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${userCredential.user!.uid}.jpg');
          UploadTask uploadTask = storageReference.putFile(_profileImage!);
          TaskSnapshot taskSnapshot = await uploadTask;
          profileImageUrl = await taskSnapshot.ref.getDownloadURL();
        }

        // Save user data to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'email': _emailController.text,
          'greekOrganization': "6DgHgmtq2iLiGuvWUSh7",
          'greekOrganizationName': _fraternityController.text,
          'chapter': "aY3G5VjQhGlRTzMn8Boa",
          'chapterName': _chapterController.text,
          'pledgeClass': _pledgeClassController.text,
          'major': _schoolMajorController.text,
          'school': _schoolController.text,
          'graduationYear': _graduationYearController.text,
          'profileImageUrl': profileImageUrl,
          'displayName':
              "${_firstNameController.text} ${_lastNameController.text}"
        });

        // Sign out the user
        await FirebaseAuth.instance.signOut();

        // Show verification email sent dialog
        _showVerificationEmailSentDialog();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showErrorDialog('An account already exists for that email.');
        } else {
          _showErrorDialog(e.message ?? 'An error occurred. Please try again.');
        }
      } catch (e) {
        _showErrorDialog(e.toString());
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationEmailSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verify Your Email'),
          content: Text(
            'A verification email has been sent to ${_emailController.text}. Please verify your email to complete the registration process.',
          ),
          actions: [
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _navigateToWelcomeScreen();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToWelcomeScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => WelcomePage()),
      (Route<dynamic> route) => false,
    );
  }

  String? _validateNotEmpty(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateGraduationYear(String? value) {
    if (value == null || value.isEmpty) {
      return 'Graduation year is required';
    }
    final year = int.tryParse(value);
    if (year == null) {
      return 'Enter a valid year';
    }
    final currentYear = DateTime.now().year;
    if (year < currentYear || year > currentYear + 6) {
      return 'Enter a valid graduation year';
    }
    return null;
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              child:
                  Text('OK', style: TextStyle(color: AgoraTheme.primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
