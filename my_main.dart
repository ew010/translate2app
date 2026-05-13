import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart'; // 换成了这个纯 CPU 包
import 'package:permission_handler/permission_handler.dart';
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
  
  // 使用新的 Llama 实例
  Llama? _llama;
  
  String _modelPath = '';
  String _translatedText = '';
  bool _isTranslating = false;
  StreamSubscription? _subscription;
  String _debugInfo = '等待加载... (请确保模型已重命名为 model.gguf 并放在 Download 文件夹最外层)';

  // 申请高级存储权限
  Future<bool> _requestPermissions() async {
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }

  // 核心：沙盒转移大法
  Future<void> _loadFromDownloadFolder() async {
    setState(() => _debugInfo = '⏳ 正在请求存储权限...');
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      setState(() => _debugInfo = '❌ 权限被拒绝！请去系统设置中手动开启“所有文件访问”权限。');
      return;
    }

    String hardcodedPath = '/storage/emulated/0/Download/model.gguf';
    File sourceFile = File(hardcodedPath);

    if (!sourceFile.existsSync()) {
      setState(() => _debugInfo = '❌ 找不到外部文件！请确认路径: $hardcodedPath');
      return;
    }

    int fileSize = sourceFile.lengthSync();
    double sizeInMB = fileSize / (1024 * 1024);

    setState(() {
      _debugInfo = '✅ 发现文件: ${sizeInMB.toStringAsFixed(1)} MB\n⏳ 正在转移至沙盒...\n(由于文件较大，此过程可能需要 5-10 秒，请耐心等待)';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    String safePath = '${Directory.systemTemp.path}/model_safe.gguf';
    File safeFile = File(safePath);

    try {
      if (!safeFile.existsSync() || safeFile.lengthSync() != fileSize) {
        await sourceFile.copy(safePath); 
      }
      setState(() => _debugInfo += '\n✅ 沙盒转移完毕！安全路径: $safePath\n🚀 正在注入纯 CPU 引擎 (绕过驱动闪退)...');
    } catch(e) {
      setState(() => _debugInfo += '\n❌ 复制失败: $e');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 🚀 核心修复：这里就是之前报 required 参数错误的地方，现在直接传路径即可
      _llama = Llama(safePath);
      
      setState(() {
        _modelPath = safePath;
        _debugInfo += '\n🎉 CPU 引擎加载成功！(最稳定模式)';
      });
    } catch (e) {
      setState(() => _debugInfo += '\n❌ CPU 引擎加载失败: $e');
    }
  }

  void _startTranslation() {
    if (_llama == null || _inputController.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    String prompt = "Translate the following text into Chinese, only output the translated content:\n\n${_inputController.text}";

    // 调用 llama_cpp_dart 的 prompt 流式输出方法
    _subscription = _llama?.prompt(prompt).listen(
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
    _subscription?.cancel();
    setState(() => _isTranslating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 原生翻译器 (纯CPU防闪退版)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _loadFromDownloadFolder,
              icon: const Icon(Icons.memory),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              label: const Text('1. 执行纯 CPU 引擎加载 (防 GPU 闪退)'),
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
