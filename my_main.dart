import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
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
  
  // 使用全新的 Android 专属控制器
  final LlamaController _llamaController = LlamaController();
  
  String _modelPath = '';
  String _translatedText = '';
  bool _isTranslating = false;
  StreamSubscription? _subscription;

  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 GGUF 模型',
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _modelPath = result.files.single.path!;
      });
      
      try {
        // 加载模型，配置极简
        await _llamaController.loadModel(
          modelPath: _modelPath,
          threads: 4,
          contextSize: 2048,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('模型加载成功！支持 GPU 加速 ⚡️')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('模型加载失败: $e')),
          );
        }
      }
    }
  }

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

    // 调用全新引擎的流式输出
    _subscription = _llamaController.generate(
      prompt: prompt,
      maxTokens: 1024,
      temperature: 0.1, // 翻译任务需要较低的温度以保持准确性
    ).listen(
      (token) {
        setState(() {
          _translatedText += token;
        });
      },
      onDone: () {
        setState(() {
          _isTranslating = false;
        });
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
    // 这个新引擎完美支持中途强制停止
    _llamaController.stop();
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
