import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../services/llm_service.dart';

class ApiConfigDialog extends StatefulWidget {
  const ApiConfigDialog({super.key});

  @override
  State<ApiConfigDialog> createState() => _ApiConfigDialogState();
}

class _ApiConfigDialogState extends State<ApiConfigDialog> {
  late String _selectedProvider;
  late String _selectedModel;
  late TextEditingController _apiKeyController;
  late TextEditingController _urlController;
  late TextEditingController _systemPromptController;
  bool _obscureKey = true;
  bool _loading = true;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = LlmService.providers.first.name;
    _selectedModel = LlmService.providers.first.models.first;
    _apiKeyController = TextEditingController();
    _urlController = TextEditingController();
    _systemPromptController = TextEditingController(text: LlmService.defaultSystemPrompt);
    _apiKeyController.addListener(_onApiKeyChanged);
    _loadConfig();
  }

  void _onApiKeyChanged() {
    final has = _apiKeyController.text.trim().isNotEmpty;
    if (has != _hasApiKey) setState(() => _hasApiKey = has);
  }

  Future<void> _loadConfig() async {
    final config = await LlmService.loadConfig();
    if (mounted) {
      setState(() {
        if (config['provider'] != null) {
          _selectedProvider = config['provider']!;
        }
        if (config['model'] != null) {
          _selectedModel = config['model']!;
        }
        if (config['apiKey'] != null) {
          _apiKeyController.text = config['apiKey']!;
          _hasApiKey = config['apiKey']!.isNotEmpty;
        }
        if (config['url'] != null) {
          _urlController.text = config['url']!;
        } else {
          _updateUrl();
        }
        if (config['systemPrompt'] != null) {
          _systemPromptController.text = config['systemPrompt']!;
        }
        _loading = false;
      });
    }
  }

  void _updateUrl() {
    final provider = LlmService.providers.firstWhere(
      (p) => p.name == _selectedProvider,
      orElse: () => LlmService.providers.first,
    );
    _urlController.text = provider.baseUrl;
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedProvider = value;
      final provider = LlmService.providers.firstWhere((p) => p.name == value);
      _selectedModel = provider.models.first;
      _updateUrl();
    });
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }

    await LlmService.saveConfig(
      provider: _selectedProvider,
      apiKey: apiKey,
      model: _selectedModel,
      url: _urlController.text.trim(),
      systemPrompt: _systemPromptController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 配置已保存')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.removeListener(_onApiKeyChanged);
    _apiKeyController.dispose();
    _urlController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final accentColor = isDark ? AppColors.darkPink : AppColors.pink;
    final currentProvider = LlmService.providers.firstWhere(
      (p) => p.name == _selectedProvider,
      orElse: () => LlmService.providers.first,
    );

    if (_loading) {
      return AlertDialog(
        backgroundColor: bgColor,
        content: const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text(
        'API 配置',
        style: AppTextStyles.heading.copyWith(color: textColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提供商', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: bgColor,
                style: AppTextStyles.body.copyWith(color: textColor),
                items: LlmService.providers.map((p) =>
                  DropdownMenuItem(value: p.name, child: Text(p.name))
                ).toList(),
                onChanged: _onProviderChanged,
              ),
            ),
            const SizedBox(height: 16),
            Text('模型', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: DropdownButton<String>(
                value: _selectedModel,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: bgColor,
                style: AppTextStyles.body.copyWith(color: textColor),
                items: currentProvider.models.map((m) =>
                  DropdownMenuItem(value: m, child: Text(m))
                ).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedModel = v);
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('API Key', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: AppTextStyles.body.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: '输入你的 API Key',
                hintStyle: AppTextStyles.body.copyWith(color: subtleColor),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkPageBackground
                    : AppColors.pageBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    color: subtleColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('API URL', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _urlController,
              style: AppTextStyles.body.copyWith(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? AppColors.darkPageBackground
                    : AppColors.pageBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('System Prompt', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _systemPromptController,
              maxLines: 3,
              style: AppTextStyles.body.copyWith(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? AppColors.darkPageBackground
                    : AppColors.pageBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: subtleColor)),
        ),
        FilledButton(
          onPressed: _hasApiKey ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: _hasApiKey ? accentColor : subtleColor.withValues(alpha: 0.3),
            disabledBackgroundColor: subtleColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            '保存',
            style: TextStyle(color: _hasApiKey ? Colors.white : subtleColor),
          ),
        ),
      ],
    );
  }
}
