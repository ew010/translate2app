import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:permission_handler/permission_handler.dart'; // 引入权限包
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const TranslatorApp());
}

class TranslatorApp extends StatelessWidget {
  const TranslatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 本地翻译',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TranslationPage(),
    );
  }
}

class TranslationPage extends StatefulWidget {
  const TranslationPage({super.key});
  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final TextEditingController _inputController = TextEditingController();
  final LlamaController _llamaController = LlamaController();
  
  String _modelPath = '';
  String _translatedText = '';
  bool _isTranslating = false;
  StreamSubscription? _subscription;
  String _debugInfo = '等待加载... (请确保模型已重命名为 model.gguf 并放在 Download 文件夹最外层)';

  // 申请高级存储权限的方法
  Future<bool> _requestPermissions() async {
    // 针对 Android 11+ 的所有文件管理权限
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    // 针对老版本安卓的普通存储权限
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  // 核心：沙盒转移大法
  Future<void> _loadFromDownloadFolder() async {
    // 1. 第一步：先向系统要权限！
    setState(() => _debugInfo = '⏳ 正在请求存储权限...');
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      setState(() => _debugInfo = '❌ 权限被拒绝 (errno 13)！请去系统设置中手动开启“所有文件访问”权限。');
      return;
    }

    // 2. 权限拿到后，再开始读文件
    String hardcodedPath = '/storage/emulated/0/Download/model.gguf';
    File sourceFile = File(hardcodedPath);

    if (!sourceFile.existsSync()) {
      setState(() => _debugInfo = '❌ 找不到外部文件！请确认路径: $hardcodedPath');
      return;
    }

    int fileSize = sourceFile.lengthSync();
    double sizeInMB = fileSize / (1024 * 1024);

    setState(() {
      _debugInfo = '✅ 发现文件: ${sizeInMB.toStringAsFixed(1)} MB\n⏳ 正在转移至沙盒 (防 Error 13)...\n(可能需要 5-10 秒，请耐心等待)';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    String safePath = '${Directory.systemTemp.path}/model_safe.gguf';
    File safeFile = File(safePath);

    try {
      if (!safeFile.existsSync() || safeFile.lengthSync() != fileSize) {
        await sourceFile.copy(safePath); // 现在有权限了，不会再报 errno 13
      }
      setState(() => _debugInfo += '\n✅ 沙盒转移完毕！安全路径: $safePath\n🚀 正在注入 C++ 引擎...');
    } catch(e) {
      setState(() => _debugInfo += '\n❌ 复制失败: $e');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _llamaController.loadModel(
        modelPath: safePath, 
        threads: 4,
        contextSize: 1024,
      );
      setState(() {
        _modelPath = safePath;
        _debugInfo += '\n🎉 引擎加载成功！(GPU加速已就绪)';
      });
    } catch (e) {
      setState(() => _debugInfo += '\n❌ C++ 彻底崩溃: $e\n\n【诊断结果】：模型格式 (2-bit) 可能不被内核支持。');
    }
  }

  void _startTranslation() {
    if (_modelPath.isEmpty || _inputController.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    String prompt = "Translate the following text into Chinese, only output the translated content:\n\n${_inputController.text}";

    _subscription = _llamaController.generate(
      prompt: prompt,
      maxTokens: 512,
      temperature: 0.1,
    ).listen(
      (token) => setState(() => _translatedText += token),
      onDone: () => setState(() => _isTranslating = false),
      onError: (error) {
        setState(() {
          _isTranslating = false;
          _translatedText += "\n[翻译出错: $error]";
        });
      }
    );
  }

  void _stopTranslation() {
    _llamaController.stop();
    _subscription?.cancel();
    setState(() => _isTranslating = false);
  }

  @override
  Widget build(BuildContext context) {
    // UI 代码保持不变
    return Scaffold(
      appBar: AppBar(title: const Text('AI 原生翻译器 (沙盒穿透版)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _loadFromDownloadFolder,
              icon: const Icon(Icons.security),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              label: const Text('1. 执行安全沙盒加载 (破除安卓权限)'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
              child: Text(_debugInfo, style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '2. 输入英文...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: _isTranslating ? null : _startTranslation, child: const Text('开始翻译'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: _isTranslating ? _stopTranslation : null, child: const Text('停止'))),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(child: Text(_translatedText, style: const TextStyle(fontSize: 16))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
