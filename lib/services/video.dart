import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';

class VideoCardService {
  // 模拟从外部API获取音乐卡片数据
  Future<String> fetchVideoCardData(String id) async {
    final url = 'https://www.bilibili.com/video/$id'; // 网易云音乐URL
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
      });
      if (response.statusCode == 200) {
        // 使用latin1解码，再转utf8
        final decodedBody = response.body;
        // 解析HTML内容
        final document = parser.parse(decodedBody);
        final metaTags = document.getElementsByTagName('meta');
        // 获取所需内容
        String title = 'Unknown Title';
        String author = 'Unknown author';
        String url = 'Unknown url';
        String imgUrl = '';
        for (var meta in metaTags) {
          if (meta.attributes['itemprop'] == 'name') {
            title = meta.attributes['content'] ?? title;
          }
          if (meta.attributes['itemprop'] == 'author') {
            author = meta.attributes['content'] ?? author;
          }
          if (meta.attributes['itemprop'] == 'url') {
            url = meta.attributes['content'] ?? url;
          }
          if (meta.attributes['itemprop'] == 'image') {
            imgUrl = meta.attributes['content'] ?? imgUrl;
          }
        }

        final cardString = '''
::: video-card
  title: "$title"
  author: "$author"
  cover: https:"$imgUrl"
  id: "$id"
  url: "$url"
:::
''';

        return cardString;
      } else {
        throw Exception('Failed to fetch video');
      }
    } catch (error) {
      print(error);
      throw Exception('请求出错');
    }
  }
}
