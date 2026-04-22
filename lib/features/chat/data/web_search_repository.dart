import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final webSearchRepositoryProvider = Provider<WebSearchRepository>((ref) {
  return WebSearchRepository();
});

class WebSearchRepository {
  /// DuckDuckGo Lite 검색. API 키 불필요, 무료.
  /// 실패 시 빈 결과 반환 (graceful degradation).
  Future<WebSearchResult> search(String query, {int count = 3}) async {
    try {
      // DuckDuckGo Lite — HTML 기반, 가벼움
      final uri = Uri.parse('https://lite.duckduckgo.com/lite/').replace(
        queryParameters: {'q': query, 'kl': 'kr-ko'},
      );

      final response = await http
          .post(uri, headers: {
            'User-Agent': 'TeraAI/1.0',
            'Accept': 'text/html',
          })
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return const WebSearchResult(items: [], success: false);
      }

      final items = _parseHtmlResults(response.body, count);
      return WebSearchResult(items: items, success: true);
    } catch (_) {
      return const WebSearchResult(items: [], success: false);
    }
  }

  /// DuckDuckGo Lite HTML에서 검색 결과를 파싱
  List<WebSearchItem> _parseHtmlResults(String html, int count) {
    final items = <WebSearchItem>[];

    // 결과 링크: class='result-link'를 포함하는 <a> 태그 (속성 순서 무관)
    final linkRegex = RegExp(
      r"<a[^>]*class='result-link'[^>]*>(.*?)</a>",
      dotAll: true,
    );
    final hrefRegex = RegExp(r'''href=['"]([^'"]+)['"]''');
    // 스니펫 패턴: <td class="result-snippet">...</td>
    final snippetRegex = RegExp(
      r'<td\s+class="result-snippet">(.*?)</td>',
      dotAll: true,
    );

    final linkMatches = linkRegex.allMatches(html).toList();
    final snippetMatches = snippetRegex.allMatches(html).toList();

    for (var i = 0; i < linkMatches.length && items.length < count; i++) {
      final fullTag = linkMatches[i].group(0) ?? '';
      final hrefMatch = hrefRegex.firstMatch(fullTag);
      final url = _decodeHtml(hrefMatch?.group(1) ?? '');
      final title = _stripHtml(linkMatches[i].group(1) ?? '');
      final description = i < snippetMatches.length
          ? _stripHtml(snippetMatches[i].group(1) ?? '')
          : '';

      if (url.isNotEmpty && title.isNotEmpty) {
        items.add(WebSearchItem(
          title: title,
          url: url,
          description: description,
        ));
      }
    }

    return items;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _decodeHtml(String text) {
    var decoded = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'");
    try {
      return Uri.decodeFull(decoded);
    } catch (_) {
      return decoded;
    }
  }
}

class WebSearchResult {
  final List<WebSearchItem> items;
  final bool success;

  const WebSearchResult({required this.items, required this.success});
}

class WebSearchItem {
  final String title;
  final String url;
  final String description;

  const WebSearchItem({
    required this.title,
    required this.url,
    required this.description,
  });

  /// ChatMessage.webSources에 저장할 형식
  String get encoded => '$title|$url';
}
