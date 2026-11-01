import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/design/design.dart';
import '../domain/profile_rules.dart';

/// 주소 검색: 카카오(다음) 우편번호 서비스를 앱 안의 웹 화면으로 띄운다. (API 키 없음, 무료)
/// 주소를 고르면 (우편번호, 기본 주소)를 돌려주며 닫힌다. 인터넷이 필요하다.
class PostcodeSearchScreen extends StatefulWidget {
  const PostcodeSearchScreen({super.key});

  /// 화면을 띄우고 고른 주소를 받는다. 취소하면 null.
  static Future<({String postcode, String address})?> open(
    BuildContext context,
  ) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PostcodeSearchScreen()));

  @override
  State<PostcodeSearchScreen> createState() => _PostcodeSearchScreenState();
}

/// 우편번호 서비스를 화면 가득 끼워 넣고, 고른 결과를 앱(Postcode 채널)으로 보낸다.
const _html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>html, body, #wrap { margin: 0; padding: 0; width: 100%; height: 100%; }</style>
</head>
<body>
<div id="wrap"></div>
<script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
<script>
  new daum.Postcode({
    oncomplete: function (data) { Postcode.postMessage(JSON.stringify(data)); },
    width: '100%',
    height: '100%'
  }).embed(document.getElementById('wrap'));
</script>
</body>
</html>
''';

class _PostcodeSearchScreenState extends State<PostcodeSearchScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel('Postcode', onMessageReceived: _onPicked)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // 우편번호 서비스 스크립트를 받지 못했을 때만 실패로 본다.
            if (error.isForMainFrame ?? false) {
              if (mounted) setState(() => _failed = true);
            }
          },
        ),
      );
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _web.loadHtmlString(_html, baseUrl: 'https://localhost/');
  }

  void _onPicked(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    final picked = addressFromPostcode(data);
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 검색')),
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('주소 검색을 불러오지 못했어요', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '인터넷 연결을 확인해 주세요',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _web),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
              ],
            ),
    );
  }
}
