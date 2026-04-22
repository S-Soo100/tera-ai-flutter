import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../data/camera_exceptions.dart';
import '../domain/camera_register_input.dart';
import 'my_cage_providers.dart';

class CameraAddScreen extends ConsumerStatefulWidget {
  const CameraAddScreen({super.key, this.prefilledPetId});

  final String? prefilledPetId;

  @override
  ConsumerState<CameraAddScreen> createState() => _CameraAddScreenState();
}

class _CameraAddScreenState extends ConsumerState<CameraAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _hostController = TextEditingController(text: '192.168.0.');
  final _portController = TextEditingController(text: '554');
  final _pathController = TextEditingController(text: 'stream1');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedPetId;
  bool _obscurePassword = true;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.prefilledPetId;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _pathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  CameraRegisterInput _buildInput() {
    return CameraRegisterInput(
      displayName: _displayNameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 554,
      path: _pathController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      petId: _selectedPetId,
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    try {
      final result =
          await ref.read(cameraRepositoryProvider).testConnection(_buildInput());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? 'camera_test_success'.tr()
              : '${'camera_test_fail'.tr()}: ${result.detail ?? ''}'),
          backgroundColor: result.success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'camera_test_fail'.tr()}: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(cameraRepositoryProvider).register(_buildInput());
      if (!mounted) return;
      ref.invalidate(camerasProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('camera_register_success'.tr())),
      );
    } on CameraConflictException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('camera_register_conflict'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.statusCode}: ${e.detail}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'error_generic'.tr()}: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petListProvider);
    final isBusy = _testing || _saving;

    return Scaffold(
      appBar: AppBar(
        title: Text('camera_form_title'.tr()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppStyles.pagePadding,
          children: [
            // 카메라 이름
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'camera_form_display_name'.tr(),
                hintText: 'camera_form_display_name_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'camera_form_display_name'.tr() : null,
            ),
            const SizedBox(height: AppStyles.spacing16),

            // IP 주소
            TextFormField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'camera_form_host'.tr(),
                hintText: 'camera_form_host_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'camera_form_host'.tr() : null,
            ),
            const SizedBox(height: AppStyles.spacing16),

            // 포트
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'camera_form_port'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'camera_form_port'.tr();
                final n = int.tryParse(v);
                if (n == null || n < 1 || n > 65535) return 'camera_form_port'.tr();
                return null;
              },
            ),
            const SizedBox(height: AppStyles.spacing16),

            // RTSP 경로
            TextFormField(
              controller: _pathController,
              decoration: InputDecoration(
                labelText: 'camera_form_path'.tr(),
                hintText: 'camera_form_path_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'camera_form_path'.tr() : null,
            ),
            const SizedBox(height: AppStyles.spacing16),

            // 아이디
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'camera_form_username'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'camera_form_username'.tr() : null,
            ),
            const SizedBox(height: AppStyles.spacing16),

            // 비밀번호
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'camera_form_password'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'camera_form_password'.tr() : null,
            ),
            const SizedBox(height: AppStyles.spacing16),

            // 연결할 개체 (선택)
            DropdownButtonFormField<String?>(
              initialValue: _selectedPetId,
              decoration: InputDecoration(
                labelText: 'camera_form_pet'.tr(),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('camera_form_pet_none'.tr()),
                ),
                ...pets.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedPetId = v),
            ),
            const SizedBox(height: AppStyles.spacing24),

            // 연결 테스트 버튼
            OutlinedButton.icon(
              onPressed: isBusy ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: _SmallSpinner(),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(
                _testing
                    ? 'camera_test_running'.tr()
                    : 'camera_test_connection'.tr(),
              ),
            ),
            const SizedBox(height: AppStyles.spacing12),

            // 등록 버튼
            FilledButton.icon(
              onPressed: isBusy ? null : _register,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: _SmallSpinner(),
                    )
                  : const Icon(Icons.save),
              label: Text('camera_register'.tr()),
            ),
            const SizedBox(height: AppStyles.spacing16),
          ],
        ),
      ),
    );
  }
}

/// 버튼 내부용 소형 스피너 (shimmer 불가 위치이므로 예외 사용)
class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: 2,
      color: Theme.of(context).colorScheme.onPrimary,
    );
  }
}
