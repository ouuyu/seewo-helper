import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _version = '...';
  String _hitokoto = '正在获取一言...';
  String _hitokotoFrom = '';

  @override
  void initState() {
    super.initState();
    _initVersion();
    _fetchHitokoto();
  }

  Future<void> _initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = '无法获取版本';
        });
      }
    }
  }

  Future<void> _fetchHitokoto() async {
    try {
      final response = await http.get(Uri.parse('https://v1.hitokoto.cn')).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _hitokoto = data['hitokoto'] ?? '命中注定。';
            _hitokotoFrom = data['from'] ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hitokoto = '每一个不曾起舞的日子，都是对生命的辜负。';
          _hitokotoFrom = '尼采';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 使用应用图标
            Image.asset(
              'assets/app_icon.ico',
              width: 128,
              height: 128,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.computer, size: 128, color: Colors.blue),
            ),
            const SizedBox(height: 32),
            const Text(
              'Seewo Helper',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v$_version',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  Text(
                    _hitokoto,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.withAlpha(200),
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  if (_hitokotoFrom.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '—— $_hitokotoFrom',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.withAlpha(160),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
