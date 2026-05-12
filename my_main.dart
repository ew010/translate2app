import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
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
  String _debugInfo = '等待加载...';

  // 核心：直接读取公共 Download 文件夹的硬核方法
  Future<void> _loadFromDownloadFolder() async {
    // 安卓标准的公共下载目录路径
    String hardcodedPath = '/storage/emulated/0/Download/model.gguf';
    File file = File(hardcodedPath);

    if (!file.existsSync()) {
      setState(() {
        _debugInfo = '❌ 找不到文件！请确保模型命名为 model.gguf 且放在 Download 文件夹的最外层。';
      });
      return;
    }

    // 检测文件大小
    int fileSize = file.lengthSync();
    double sizeInMB = fileSize / (1024 * 1024);
    setState(() {
      _modelPath = hardcodedPath;
      _debugInfo = '✅ 找到文件: ${sizeInMB.toStringAsFixed(1)} MB\n正在注入 C++ 引擎...';
    });

    if (sizeInMB == 0) {
      setState(() => _debugInfo += '\n❌ 文件大小为 0，文件已损坏！');
      return;
    }

    try {
      await _llamaController.loadModel(
        modelPath: _modelPath,
        threads: 4,
        contextSize: 1024, // 进一步调小上下文，防止内存溢出
      );
      setState(() {
        _debugInfo = '🎉 模型加载成功！引擎已就绪 (GPU加速已开启)';
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ C++ 引擎加载崩溃: $e';
      });
    }
  }

  void _startTranslation() {
    if (_modelPath.isEmpty) return;
    if (_inputController.text.isEmpty) return;

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
      (token) {
        setState(() => _translatedText += token);
      },
      onDone: () {
        setState(() => _isTranslating = false);
      },
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
    setState(() {
      _isTranslating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 原生翻译器 (硬核排错版)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 新增的硬核加载按钮
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _loadFromDownloadFolder,
              icon: const Icon(Icons.download),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              label: const Text('1. 从 Download 文件夹强行加载 model.gguf'),
            ),
            const SizedBox(height: 8),
            // 状态显示面板
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
              child: Text(_debugInfo, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '2. 输入需要翻译的英文...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: _isTranslating ? null : _startTranslation,
                    child: const Text('开始翻译'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: _isTranslating ? _stopTranslation : null,
                    child: const Text('停止'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('翻译结果:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_translatedText, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
