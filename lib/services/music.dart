import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';

class MusicService {
  // 模拟从外部API获取音乐卡片数据
  Future<String> fetchMusicCardData(String id) async {
    final url = 'https://music.163.com/song?id=$id'; // 网易云音乐URL
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
      });

      if (response.statusCode == 200) {
        // 使用latin1解码，再转utf8
        final decodedBody = utf8.decode(latin1.encode(response.body));
        // 解析HTML内容
        final document = parser.parse(decodedBody);
        final metaTags = document.getElementsByTagName('meta');

        // 获取所需内容
        String title = 'Unknown Title';
        String artist = 'Unknown Artist';
        String album = 'Unknown Album';
        String imgUrl = '';
        for (var meta in metaTags) {
          if (meta.attributes['property'] == 'og:title') {
            title = meta.attributes['content'] ?? title;
          }
          if (meta.attributes['property'] == 'og:music:artist') {
            artist = meta.attributes['content'] ?? artist;
          }
          if (meta.attributes['property'] == 'og:music:album') {
            album = meta.attributes['content'] ?? album;
          }
          if (meta.attributes['property'] == 'og:image') {
            imgUrl = meta.attributes['content'] ?? imgUrl;
          }
        }

        final musicCardString = '''
::: music-card
  title: "$title"
  artist: "$artist"
  album: "$album"
  cover: "$imgUrl"
  id: "$id"
  url: "$url"
:::
''';

        return musicCardString;
      } else {
        throw Exception('Failed to fetch music');
      }
    } catch (error) {
      throw Exception('请求出错');
    }
  }
}
