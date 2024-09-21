import 'package:flutter/material.dart' hide CarouselController;
import 'package:chatview/chatview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import './ChatProfilePage.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './LinkPreview.dart';
import './linkPreview.dart' as prefix;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

class ChatViewPage extends StatefulWidget {
  final String conversationId;
  final String currentUserId;

  ChatViewPage({required this.conversationId, required this.currentUserId});

  @override
  _ChatViewPageState createState() => _ChatViewPageState();
}

class _ChatViewPageState extends State<ChatViewPage> {
  late FocusNode _messageFocusNode;
  late ChatController _chatController;
  List<Message> messageList = [];
  bool _isLoading = true;
  String _chatName = '';
  List<ChatUser> _chatUsers = [];
  bool _currentUserInChat = false;
  StreamSubscription? _messagesSubscription;
  bool _isOneOnOneChat = false;
  Map<String, dynamic> _mediaData = {};

  @override
  void initState() {
    super.initState();
    _messageFocusNode = FocusNode();
    _loadChatDetails();
  }

  String encodeMediaUrl(String url) {
    return Uri.encodeFull(url);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> pickMedia() async {
    final ImagePicker _picker = ImagePicker();
    try {
      final XFile? media = await _picker.pickMedia();
      if (media != null) {
        final File mediaFile = File(media.path);
        print("Picked media path: ${mediaFile.path}");
        if (!await mediaFile.exists()) {
          print("File does not exist at path: ${mediaFile.path}");
          throw Exception('Selected media file does not exist');
        }
        if (media.name.toLowerCase().endsWith('.mp4')) {
          await _handleVideoMessage(mediaFile);
        } else {
          await _handleImageMessage(mediaFile);
        }
      }
    } catch (e) {
      print("Error picking media: $e");
      _showErrorDialog('Error', 'Failed to pick media. Please try again.');
    }
  }

  Future<void> _handleImageMessage(File imageFile) async {
    try {
      print("Handling image message. Image path: ${imageFile.path}");
      if (!await imageFile.exists()) {
        print("Image file does not exist at path: ${imageFile.path}");
        throw Exception('Image file not found');
      }

      // Create a copy of the image in the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imageFile.path);
      final savedImage = await imageFile.copy('${appDir.path}/$fileName');
      print("Saved image to: ${savedImage.path}");

      final compressedImage = await compressImage(savedImage);
      print("Compressed image path: ${compressedImage.path}");

      final imageRef = FirebaseStorage.instance
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await imageRef.putFile(compressedImage);
      final imageUrl = await imageRef.getDownloadURL();
      print("Uploaded image URL: $imageUrl");

      final newMessage = {
        'text': imageUrl,
        'senderId': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'messageType': 'image',
      };

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add(newMessage);

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': 'Image',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      print("Image message successfully handled and uploaded");
    } catch (e) {
      print('Error handling image message: $e');
      throw e;
    }
  }

  Future<File> compressImage(File file) async {
    print("Compressing image: ${file.path}");
    final dir = await getTemporaryDirectory();
    final targetPath =
        path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Failed to compress image');
    }
    print("Compressed image path: ${result.path}");
    return File(result.path);
  }

  Future<void> _handleVideoMessage(File videoFile) async {
    try {
      print("Handling video message. Video path: ${videoFile.path}");
      if (!await videoFile.exists()) {
        print("Video file does not exist at path: ${videoFile.path}");
        throw Exception('Video file not found');
      }

      final compressedVideo = await compressVideo(videoFile);
      print("Compressed video path: ${compressedVideo.path}");

      final thumbnailFile = await generateVideoThumbnail(compressedVideo.path);
      print("Generated thumbnail path: ${thumbnailFile.path}");

      final compressedThumbnail = await compressImage(thumbnailFile);
      print("Compressed thumbnail path: ${compressedThumbnail.path}");

      // Upload video
      final videoFileName =
          '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
      final videoRef =
          FirebaseStorage.instance.ref().child('videos/$videoFileName');
      await videoRef.putFile(compressedVideo);
      final videoUrl = await videoRef.getDownloadURL();

      // Upload thumbnail
      final thumbnailFileName =
          '${DateTime.now().millisecondsSinceEpoch}_thumbnail.jpg';
      final thumbnailRef =
          FirebaseStorage.instance.ref().child('thumbnails/$thumbnailFileName');
      await thumbnailRef.putFile(compressedThumbnail);
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      final newMessage = {
        'text': json.encode({
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
        }),
        'senderId': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'messageType': 'video',
      };

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add(newMessage);

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': 'Video',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error handling video message: $e');
      throw e;
    }
  }

  Future<File> compressVideo(File videoFile) async {
    print("Compressing video: ${videoFile.path}");
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoFile.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (mediaInfo?.path == null) {
      throw Exception('Failed to compress video');
    }
    print("Compressed video path: ${mediaInfo!.path}");
    return File(mediaInfo.path!);
  }

  Future<File> generateVideoThumbnail(String videoPath) async {
    print("Generating thumbnail for video: $videoPath");
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );
    if (thumbnailPath == null) {
      throw Exception('Failed to generate video thumbnail');
    }
    print("Generated thumbnail path: $thumbnailPath");
    return File(thumbnailPath);
  }

  bool _containsUrl(String text) {
    final urlRegExp = RegExp(r"(https?:\/\/[^\s]+)");
    return urlRegExp.hasMatch(text);
  }

  Widget _buildTextWithClickableLinks(String text) {
    final urlRegex = RegExp(r'https?://\S+');
    final spans = <TextSpan>[];
    int start = 0;

    String shortenUrl(String url) {
      if (url.length > 30) {
        return url.substring(0, 15) + '...' + url.substring(url.length - 15);
      }
      return url;
    }

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(fontFamily: 'roboto', color: Colors.white),
        ));
      }
      spans.add(TextSpan(
        text: shortenUrl(match.group(0)!),
        style: TextStyle(
            fontFamily: 'roboto',
            color: Colors.blue,
            decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (await canLaunch(match.group(0)!)) {
              await launch(match.group(0)!);
            }
          },
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(fontFamily: 'roboto', color: Colors.white),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<void> _loadChatDetails() async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation does not exist');
      }

      final data = conversationDoc.data() as Map<String, dynamic>;
      final List<String> participantIds =
          List<String>.from(data['participants']);

      _currentUserInChat = participantIds.contains(widget.currentUserId);
      _isOneOnOneChat = participantIds.length == 2;

      if (!_currentUserInChat) {
        throw Exception('Current user is not a participant in this chat');
      }

      // Load user details
      final userDocs = await Future.wait(participantIds.map((id) =>
          FirebaseFirestore.instance.collection('users').doc(id).get()));

      if (mounted) {
        setState(() {
          _chatUsers = userDocs.map((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            return ChatUser(
              id: doc.id,
              name: '${userData['firstName']} ${userData['lastName']}',
              profilePhoto: userData['profileImageUrl'] ?? '',
            );
          }).toList();

          _chatName = _generateChatName(_chatUsers);
        });
      }

      _initializeChatController();
      _setupMessagesListener();
    } catch (e) {
      print('Error loading chat details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog(
          'Error', 'Unable to load chat details. Please try again later.');
    }
  }

  String _generateChatName(List<ChatUser> users) {
    if (users.length <= 1) return 'Chat';

    final otherUsers =
        users.where((user) => user.id != widget.currentUserId).toList();
    String name = otherUsers.map((user) => user.name).join(', ');

    if (name.length > 30) {
      name = name.substring(0, 27) + '...';
    }

    return name;
  }

  void _initializeChatController() {
    final currentUser = _chatUsers.firstWhere(
      (user) => user.id == widget.currentUserId,
      orElse: () => ChatUser(id: widget.currentUserId, name: 'Current User'),
    );

    _chatController = ChatController(
      initialMessageList: messageList,
      scrollController: ScrollController(),
      otherUsers: _chatUsers,
      currentUser: currentUser,
    );
  }

  void _setupMessagesListener() {
    _messagesSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit to last 50 messages for performance
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print("New message received");
        final newMessages = snapshot.docs
            .map((doc) => _createMessage(doc))
            .whereType<Message>()
            .toList();
        newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        setState(() {
          messageList = [
            ...messageList,
            ...newMessages
                .where((message) => !messageList.any((m) => m.id == message.id))
          ];
          _isLoading = false;
        });

        // Update the chat controller outside of setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final message in newMessages) {
            if (!_chatController.initialMessageList
                .any((m) => m.id == message.id)) {
              _chatController.addMessage(message);
            }
          }
        });
      }
    }, onError: (error) {
      print('Error loading messages: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog(
          'Error', 'Unable to load messages. Please try again later.');
    });
  }

  MessageType _getMessageType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.custom;
      case 'voice':
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }

  Widget _buildCustomMessage(Message message) {
    if (message.messageType == MessageType.custom) {
      try {
        final videoData = json.decode(message.message);
        return GestureDetector(
          onTap: () => _showMediaViewer(context, videoData['videoUrl'], "",
              isVideo: true),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  videoData['thumbnailUrl'],
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
                Icon(
                  Icons.play_circle_fill,
                  size: 50,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        print('Error parsing custom message: $e');
        return Text('Invalid video message');
      }
    }
    return SizedBox.shrink();
  }

  void _showMediaViewer(BuildContext context, String mediaUrl, String senderId,
      {bool isVideo = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MediaViewerDialog(
          mediaUrl: mediaUrl,
          isVideo: isVideo,
          senderName: senderId,
        );
      },
    );
  }

  void playVideo(BuildContext context, String videoUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Chewie(
              controller: ChewieController(
                videoPlayerController: VideoPlayerController.network(videoUrl),
                autoPlay: true,
                looping: false,
                errorBuilder: (context, errorMessage) {
                  return Center(
                    child: Text(
                      'Error: $errorMessage',
                      style:
                          TextStyle(fontFamily: 'roboto', color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        backgroundColor: Colors.black,
      ),
    ));
  }

  Future<Map<String, String>> uploadMedia(File file, bool isVideo) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${isVideo ? 'video.mp4' : 'image.jpg'}';
    final ref = FirebaseStorage.instance
        .ref()
        .child(isVideo ? 'videos/$fileName' : 'images/$fileName');

    if (isVideo) {
      final compressedVideo = await compressVideo(file);
      final thumbnail = await generateVideoThumbnail(compressedVideo.path);
      final compressedThumbnail = await compressImage(thumbnail);

      await ref.putFile(compressedVideo);
      final videoUrl = await ref.getDownloadURL();

      final thumbnailRef =
          FirebaseStorage.instance.ref().child('thumbnails/$fileName');
      await thumbnailRef.putFile(compressedThumbnail);
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      return {
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'isVideo': 'true',
      };
    } else {
      final compressedImage = await compressImage(file);
      await ref.putFile(compressedImage);
      final imageUrl = await ref.getDownloadURL();

      return {
        'url': imageUrl,
        'isVideo': 'false',
      };
    }
  }

  Message _createMessage(QueryDocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final messageType = _getMessageType(data['messageType'] as String?);

      String messageContent = data['text'] ?? '';
      if (messageType == MessageType.image && data['mediaUrl'] != null) {
        messageContent = data['mediaUrl'];
      } else if (messageType == MessageType.custom && data['text'] != null) {
        try {
          final videoData = json.decode(data['text']);
          messageContent = json.encode({
            'videoUrl': videoData['videoUrl'] ?? '',
            'thumbnailUrl': videoData['thumbnailUrl'] ?? '',
          });
        } catch (e) {
          print('Error parsing video data: $e');
          messageContent = 'Error: Unable to load video';
        }
      }

      return Message(
        id: doc.id,
        message: messageContent,
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        sentBy: data['senderId'] ?? '',
        messageType: messageType,
        status: _getMessageStatus(data),
        replyMessage: data['replyTo'] != null
            ? ReplyMessage(
                message: data['replyTo']['text'] ?? '',
                replyTo: data['replyTo']['senderId'] ?? '',
                replyBy: data['senderId'] ?? '',
              )
            : const ReplyMessage(),
        reaction: data['reactions'] != null
            ? Reaction(
                reactions: List<String>.from(data['reactions'].values),
                reactedUserIds: List<String>.from(data['reactions'].keys),
              )
            : null,
      );
    } catch (e) {
      print('Error creating message from document: $e');
      return Message(
        id: doc.id,
        message: 'Error: Unable to load message',
        createdAt: DateTime.now(),
        sentBy: '',
        messageType: MessageType.text,
      );
    }
  }

  MessageStatus _getMessageStatus(Map<String, dynamic> data) {
    if (_isOneOnOneChat) {
      if (data['seen'] == true) {
        return MessageStatus.read;
      } else if (data['delivered'] == true) {
        return MessageStatus.delivered;
      }
    }
    return MessageStatus.pending;
  }

  void _updateSeenStatus() async {
    if (_isOneOnOneChat) {
      final otherUserId =
          _chatUsers.firstWhere((user) => user.id != widget.currentUserId).id;
      final unseenMessages = messageList.where((message) =>
          message.sentBy == otherUserId &&
          message.status != MessageStatus.read);

      for (var message in unseenMessages) {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .doc(message.id)
            .update({'seen': true});
      }
    }
  }

  Future<String> generateAndSaveThumbnail(String videoPath) async {
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );

    // Compress the thumbnail
    final compressedThumbnail = await compressImage(File(thumbnailPath!));

    // Overlay play button on thumbnail
    final image =
        await decodeImageFromList(compressedThumbnail.readAsBytesSync());
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(image, Offset.zero, Paint());

    final playButton = Icons.play_circle_filled;
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(playButton.codePoint),
      style: TextStyle(
        fontFamily: 'roboto',
        fontSize: 50,
        color: Colors.white.withOpacity(0.8),
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
        canvas,
        Offset(
          (image.width - iconPainter.width) / 2,
          (image.height - iconPainter.height) / 2,
        ));

    final picture = recorder.endRecording();
    final img = await picture.toImage(image.width, image.height);
    final pngBytes = await img.toByteData(format: ImageByteFormat.png);

    final thumbnailWithPlayButton =
        File('${compressedThumbnail.path}_with_play.png')
          ..writeAsBytesSync(pngBytes!.buffer.asUint8List());

    return thumbnailWithPlayButton.path;
  }

  Future<Map<String, String>> uploadVideoAndThumbnail(File videoFile) async {
    final videoFileName = '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
    final thumbnailFileName =
        '${DateTime.now().millisecondsSinceEpoch}_thumbnail.jpg';

    final videoRef =
        FirebaseStorage.instance.ref().child('videos/$videoFileName');
    final thumbnailRef =
        FirebaseStorage.instance.ref().child('thumbnails/$thumbnailFileName');

    // Compress video
    final compressedVideo = await compressVideo(videoFile);

    // Generate and save thumbnail
    final thumbnailPath = await generateAndSaveThumbnail(compressedVideo.path);

    // Upload compressed video and thumbnail
    await videoRef.putFile(compressedVideo);
    await thumbnailRef.putFile(File(thumbnailPath));

    final videoUrl = await videoRef.getDownloadURL();
    final thumbnailUrl = await thumbnailRef.getDownloadURL();

    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'isVideo': 'true',
    };
  }

  Future<void> _onSendTap(String message, ReplyMessage? replyMessage,
      MessageType messageType) async {
    try {
      if (messageType == MessageType.image) {
        // The 'message' here is actually the path to the image file
        File imageFile = File(message);
        await _handleImageMessage(imageFile);
      } else if (messageType == MessageType.custom) {
        // Assuming custom type is for videos
        final videoData = json.decode(message);
        File videoFile = File(videoData['videoUrl']);
      } else {
        await _handleTextMessage(message, replyMessage, messageType);
      }
    } catch (e) {
      print('Error sending message: $e');
      String errorMessage = 'Unable to send message. Please try again.';
      if (e.toString().contains('Failed to upload image')) {
        errorMessage = 'Failed to upload image. Please try again.';
      } else if (e.toString().contains('Failed to upload video')) {
        errorMessage = 'Failed to upload video. Please try again.';
      }
      _showErrorDialog('Error', errorMessage);
    }
  }

  Future<void> _handleTextMessage(String message, ReplyMessage? replyMessage,
      MessageType messageType) async {
    final newMessage = {
      'text': message,
      'senderId': widget.currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'messageType': messageType.name,
    };

    if (replyMessage != null && replyMessage.message.isNotEmpty) {
      newMessage['replyTo'] = {
        'text': replyMessage.message,
        'senderId': replyMessage.replyTo,
      };
    }

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .add(newMessage);

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({
      'lastMessage': message,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _markMessageAsSeen(String messageId) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'seen': true});
  }

  void _onMessageReactionPress(Message message, String reaction) async {
    try {
      final messageRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(message.id);

      final messageDoc = await messageRef.get();
      final currentReactions =
          (messageDoc.data()?['reactions'] as Map<String, dynamic>?) ?? {};

      if (currentReactions[widget.currentUserId] == reaction) {
        currentReactions.remove(widget.currentUserId);
      } else {
        currentReactions[widget.currentUserId] = reaction;
      }

      await messageRef.update({'reactions': currentReactions});
    } catch (e) {
      print('Error updating reaction: $e');
      _showErrorDialog('Error', 'Unable to update reaction. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _currentUserInChat
              ? ChatView(
                  chatController: _chatController,
                  onSendTap: _onSendTap,
                  chatViewState: messageList.isEmpty
                      ? ChatViewState.noData
                      : ChatViewState.hasMessages,
                  chatBackgroundConfig: ChatBackgroundConfiguration(
                    backgroundColor: Color(0xFF121212),
                  ),
                  reactionPopupConfig: ReactionPopupConfiguration(
                    backgroundColor: Colors.grey[800],
                    shadow: BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    userReactionCallback: (message, reaction) {
                      print("called");
                      _onMessageReactionPress(message, reaction);
                    },
                  ),
                  featureActiveConfig: const FeatureActiveConfig(

                      /// Controls the visibility of message seen ago receipts default is true
                      lastSeenAgoBuilderVisibility: true,

                      /// Controls the visibility of the message [receiptsBuilder]
                      receiptsBuilderVisibility: false),
                  messageConfig: MessageConfiguration(
                    messageReactionConfig: MessageReactionConfiguration(
                      backgroundColor: Colors.grey[800],
                      borderColor: Colors.grey[800],
                      reactionsBottomSheetConfig:
                          ReactionsBottomSheetConfiguration(
                        backgroundColor: Colors.grey[900],
                        reactedUserTextStyle: TextStyle(
                            fontFamily: 'roboto', color: Colors.white),
                        reactionWidgetDecoration: BoxDecoration(
                          color: Colors.grey[800],
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    imageMessageConfig: ImageMessageConfiguration(
                      onTap: (imageUrl) =>
                          _showMediaViewer(context, imageUrl, ""),
                    ),
                    customMessageBuilder: (message) =>
                        _buildCustomMessage(message),
                  ),
                  sendMessageConfig: SendMessageConfiguration(
                    textFieldBackgroundColor: Colors.grey[900],
                    textFieldConfig: TextFieldConfiguration(
                      textStyle:
                          TextStyle(fontFamily: 'roboto', color: Colors.white),
                    ),
                    defaultSendButtonColor: Colors.blue,
                    replyMessageColor: Colors.grey[700],
                    replyDialogColor: Colors.grey[800],
                    replyTitleColor: Colors.white,
                    closeIconColor: Colors.white,
                    imagePickerIconsConfig: ImagePickerIconsConfiguration(
                      cameraIconColor: Colors.black,
                      galleryIconColor: Colors.black,
                    ),
                    enableCameraImagePicker: false,
                    enableGalleryImagePicker: false,
                    allowRecordingVoice: false,
                  ),
                  chatBubbleConfig: ChatBubbleConfiguration(
                    outgoingChatBubbleConfig: ChatBubble(
                      linkPreviewConfig: LinkPreviewConfiguration(
                        backgroundColor: Colors.blueGrey[800],
                        bodyStyle: TextStyle(
                            fontFamily: 'roboto',
                            color: Colors.white70,
                            fontSize: 12),
                        titleStyle: TextStyle(
                            fontFamily: 'roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        linkStyle:
                            TextStyle(fontFamily: 'roboto', color: Colors.blue),
                        onUrlDetect: (url) {
                          print("Detected URL: $url");
                        },
                      ),
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      textStyle:
                          TextStyle(fontFamily: 'roboto', color: Colors.white),
                    ),
                    inComingChatBubbleConfig: ChatBubble(
                      linkPreviewConfig: LinkPreviewConfiguration(
                        backgroundColor: Colors.grey[700],
                        bodyStyle: TextStyle(
                            fontFamily: 'roboto',
                            color: Colors.white70,
                            fontSize: 12),
                        titleStyle: TextStyle(
                            fontFamily: 'roboto',
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        linkStyle:
                            TextStyle(fontFamily: 'roboto', color: Colors.blue),
                        onUrlDetect: (url) {
                          print("Detected URL: $url");
                        },
                      ),
                      onMessageRead: (message) {
                        if (_isOneOnOneChat &&
                            message.sentBy != widget.currentUserId) {
                          _markMessageAsSeen(message.id);
                        }
                      },
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                      textStyle:
                          TextStyle(fontFamily: 'roboto', color: Colors.white),
                    ),
                  ),
                  repliedMessageConfig: RepliedMessageConfiguration(
                    textStyle:
                        TextStyle(fontFamily: 'roboto', color: Colors.white),
                    backgroundColor: Colors.grey[800],
                    verticalBarColor: Colors.blue,
                    repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(
                      enableHighlightRepliedMsg: true,
                      highlightColor: Colors.grey[700]!,
                      highlightScale: 1.1,
                    ),
                  ),
                  swipeToReplyConfig: SwipeToReplyConfiguration(
                    replyIconColor: Colors.blue,
                  ),
                  replyPopupConfig: ReplyPopupConfiguration(
                    backgroundColor: Colors.grey[800],
                    buttonTextStyle:
                        TextStyle(fontFamily: 'roboto', color: Colors.white),
                    topBorderColor: Colors.grey[700]!,
                  ),
                  appBar: ChatViewAppBar(
                    profilePicture: _chatUsers.length > 2
                        ? null
                        : _chatUsers.first.profilePhoto != null
                            ? _chatUsers.first.profilePhoto
                            : null,
                    leading: _chatUsers.length > 2
                        ? null
                        : _chatUsers.first.profilePhoto == null
                            ? CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  _chatUsers.first.name[0].toUpperCase(),
                                  style: TextStyle(
                                      fontFamily: 'roboto',
                                      color: Colors.white),
                                ),
                              )
                            : null,
                    chatTitle: _chatName,
                    userStatus: _chatUsers.length > 2
                        ? '${_chatUsers.length} participants'
                        : null,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.attach_file),
                        onPressed: pickMedia,
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatProfilePage(
                                conversationId: widget.conversationId,
                                chatUsers: _chatUsers,
                                isGroupChat: _chatUsers.length > 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    backGroundColor: Color(0xFF121212),
                    chatTitleTextStyle: TextStyle(
                      fontFamily: 'roboto',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    userStatusTextStyle: TextStyle(
                      fontFamily: 'roboto',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                )
              : Center(
                  child: Text('You are not a participant in this chat.',
                      style: TextStyle(
                          fontFamily: 'roboto', color: Colors.white))),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                    child: Text('Error loading image',
                        style: TextStyle(
                            fontFamily: 'roboto', color: Colors.white)));
              },
            ),
          ),
        ),
        backgroundColor: Colors.black,
      ),
    ));
  }

  Widget _buildTextWithShortenedLinks(String text) {
    final urlRegex = RegExp(r'https?://\S+');
    final spans = <TextSpan>[];
    int start = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(fontFamily: 'roboto', color: Colors.white),
        ));
      }
      spans.add(TextSpan(
        text: _shortenUrl(match.group(0)!),
        style: TextStyle(
            fontFamily: 'roboto',
            color: Colors.blue,
            decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            if (await canLaunch(match.group(0)!)) {
              await launch(match.group(0)!);
            }
          },
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(fontFamily: 'roboto', color: Colors.white),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _shortenUrl(String url) {
    Uri uri = Uri.parse(url);
    String shortenedUrl = '${uri.scheme}://${uri.host}';
    if (uri.path.isNotEmpty && uri.path != '/') {
      shortenedUrl +=
          '${uri.path.substring(0, uri.path.length > 15 ? 15 : uri.path.length)}...';
    }
    return shortenedUrl;
  }

  Widget _buildMessageWidget(Message message) {
    if (message.messageType == MessageType.text) {
      return _buildTextWithShortenedLinks(message.message);
    }
    // For other message types, return a placeholder widget
    return SizedBox.shrink();
  }
}

class MediaViewerDialog extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;
  final String senderName;

  MediaViewerDialog({
    required this.mediaUrl,
    required this.isVideo,
    required this.senderName,
  });

  @override
  _MediaViewerDialogState createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<MediaViewerDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideoPlayer();
    } else {
      _isLoading = false;
    }
  }

  void _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.mediaUrl);
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: TextStyle(fontFamily: 'roboto', color: Colors.white),
            ),
          );
        },
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
            // Media content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : _errorMessage != null
                            ? Text(_errorMessage!,
                                style: TextStyle(
                                    fontFamily: 'roboto', color: Colors.white))
                            : widget.isVideo && _chewieController != null
                                ? Chewie(controller: _chewieController!)
                                : !widget.isVideo
                                    ? CachedNetworkImage(
                                        imageUrl: widget.mediaUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            CircularProgressIndicator(),
                                        errorWidget: (context, url, error) {
                                          print(
                                              'DEBUG: Error loading image in dialog: $error');
                                          return Text('Error loading image',
                                              style: TextStyle(
                                                  fontFamily: 'roboto',
                                                  color: Colors.white));
                                        },
                                      )
                                    : SizedBox(),
                  ),
                ),
                // "Sent by" text
                if (widget.senderName != "")
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    color: Colors.black.withOpacity(0.5),
                    child: Text(
                      'Sent by ${widget.senderName}',
                      style: TextStyle(
                          fontFamily: 'roboto',
                          color: Colors.white,
                          fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return Scaffold(
        body: Center(
          child: Text(
            'An error occurred: ${errorDetails.exception}',
            style: TextStyle(fontFamily: 'roboto', color: Colors.red),
          ),
        ),
      );
    };
    return child;
  }
}
