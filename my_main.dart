import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fllama/fllama.dart';
import 'dart:async';

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
  final Fllama _fllama = Fllama();
  
  String _modelPath = '';
  String _translatedText = '';
  bool _isTranslating = false;
  StreamSubscription? _subscription;

  // 选择手机里的 GGUF 模型
  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 GGUF 模型',
      type: FileType.any, // Android 上限制后缀有时会失效，所以用 any
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _modelPath = result.files.single.path!;
      });
      // 初始化 C++ 模型引擎
      _fllama.init(
        modelPath: _modelPath,
        contextSize: 2048, // 手机内存有限，上下文不宜过大
        threads: 4,        // 调用 4 个 CPU 核心
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模型加载成功！')),
      );
    }
  }

  // 执行翻译
  void _startTranslation() {
    if (_modelPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择模型！')),
      );
      return;
    }
    if (_inputController.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    String prompt = "Translate the following text into Chinese, only output the translated content:\n\n${_inputController.text}";

    // 监听 C++ 引擎的流式输出
    _subscription = _fllama.generate(prompt).listen((token) {
      setState(() {
        _translatedText += token;
      });
    }, onDone: () {
      setState(() {
        _isTranslating = false;
      });
    }, onError: (error) {
      setState(() {
        _isTranslating = false;
        _translatedText += "\n[翻译出错: $error]";
      });
    });
  }

  void _stopTranslation() {
    _subscription?.cancel();
    setState(() {
      _isTranslating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 原生翻译器 (离线版)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _pickModel,
              icon: const Icon(Icons.folder),
              label: Text(_modelPath.isEmpty ? '1. 选择 GGUF 模型' : '模型已就绪 (点击重新选择)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              maxLines: 4,
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
