import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:cached_network_image/cached_network_image.dart';

class AppleLinkPreview extends StatefulWidget {
  final String text;

  AppleLinkPreview({required this.text});

  @override
  _AppleLinkPreviewState createState() => _AppleLinkPreviewState();
}

class _AppleLinkPreviewState extends State<AppleLinkPreview> {
  String? _title;
  String? _description;
  String? _imageUrl;
  String? _url;

  @override
  void initState() {
    super.initState();
    _fetchLinkPreview();
  }

  void _fetchLinkPreview() async {
    final urls = RegExp(r"(https?:\/\/[^\s]+)").allMatches(widget.text);
    if (urls.isEmpty) return;

    _url = urls.first.group(0);
    if (_url == null) return;

    try {
      final response = await http.get(Uri.parse(_url!));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        _title = document.querySelector('title')?.text;
        _description = document
            .querySelector('meta[name="description"]')
            ?.attributes['content'];
        _imageUrl = document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'];

        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error fetching link preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return Linkify(
        text: widget.text,
        style: TextStyle(color: Colors.white),
        linkStyle: TextStyle(color: Colors.blue),
        onOpen: (link) async {
          if (await canLaunch(link.url)) {
            await launch(link.url);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Linkify(
          text: widget.text,
          style: TextStyle(color: Colors.white),
          linkStyle: TextStyle(color: Colors.blue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          onOpen: (link) async {
            if (await canLaunch(link.url)) {
              await launch(link.url);
            }
          },
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            if (await canLaunch(_url!)) {
              await launch(_url!);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: _imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[700],
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.grey[700],
                      child: Icon(Icons.error, color: Colors.white),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_title != null)
                        Text(
                          _title!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_description != null)
                        Text(
                          _description!,
                          style: TextStyle(color: Colors.grey[400]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: 4),
                      Text(
                        _url!,
                        style: TextStyle(color: Colors.blue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
