import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../data/profile_remote.dart';
import '../domain/profile_rules.dart';
import 'postcode_search_screen.dart';

/// 주소 검색을 띄우는 함수. 테스트에서는 웹 화면 대신 정해 둔 주소를 돌려주게 바꿔 끼운다.
final addressSearchProvider =
    Provider<
      Future<({String postcode, String address})?> Function(BuildContext)
    >((ref) => PostcodeSearchScreen.open);

/// 특정 기능이 개인정보를 요구할 때 함께 넘긴다. 예: 포토북 배송 → 이름·휴대폰 번호·주소
class PrivateInfoRequest {
  const PrivateInfoRequest({required this.fields, required this.purpose});

  final Set<PrivateField> fields;

  /// 무엇 때문에 필요한지. 예: "포토북 배송"
  final String purpose;
}

/// 기능을 쓰기 전에 필요한 개인정보가 있는지 확인한다.
/// 다 있으면 바로 true. 없으면 왜 필요한지 알리고, 입력을 마치면 true(그만두면 false).
/// 동호회 가입·포토북 결제 같은 기능의 시작 버튼에서 부른다.
Future<bool> requirePrivateInfo(
  BuildContext context, {
  required Set<PrivateField> fields,
  required String purpose,
}) async {
  final PrivateInfo info;
  try {
    info = await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(profileRemoteProvider).fetchPrivateInfo();
  } catch (e) {
    debugPrint('[private] $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage(e, failed: '개인정보를 확인하지 못했어요'))),
        );
    }
    return false;
  }
  final missing = info.missing(fields);
  if (missing.isEmpty) return true;
  if (!context.mounted) return false;

  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.background,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$purpose에 필요한 정보가 있어요', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${missing.map((f) => f.label).join(', ')}을(를) 입력하면 바로 이어서 진행할게요.\n'
              '입력한 정보는 나만 볼 수 있고, 다른 사람에게는 보이지 않아요.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: '입력하기',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: '나중에 할게요',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  if (go != true || !context.mounted) return false;
  final saved = await context.push<bool>(
    AppRoutes.privateInfo,
    extra: PrivateInfoRequest(fields: fields, purpose: purpose),
  );
  return saved ?? false;
}

/// 개인정보 관리: 이름, 휴대폰 번호, 주소. 본인만 보고, 비워 둬도 된다.
/// [request]가 있으면(기능이 요구해서 들어온 경우) 필요한 항목을 표시하고, 다 채워야 저장할 수 있다.
class PrivateInfoScreen extends ConsumerStatefulWidget {
  const PrivateInfoScreen({super.key, this.request});

  final PrivateInfoRequest? request;

  @override
  ConsumerState<PrivateInfoScreen> createState() => _PrivateInfoScreenState();
}

class _PrivateInfoScreenState extends ConsumerState<PrivateInfoScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _detail = TextEditingController();
  String? _postcode;
  String? _address;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _detail]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    super.dispose();
  }

  PrivateInfo get _current => PrivateInfo(
    name: _name.text.trim(),
    phone: normalizePhone(_phone.text),
    postcode: _postcode,
    address: _address,
    addressDetail: _detail.text.trim(),
  );

  Set<PrivateField> get _required => widget.request?.fields ?? const {};

  Future<void> _searchAddress() async {
    final picked = await ref.read(addressSearchProvider)(context);
    if (picked == null || !mounted) return;
    setState(() {
      _postcode = picked.postcode;
      _address = picked.address;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRemoteProvider).savePrivateInfo(_current);
      ref.invalidate(myPrivateInfoProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('개인정보를 저장했어요')));
      if (mounted) context.pop(true);
    } catch (e) {
      debugPrint('[private] $e');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(errorMessage(e, failed: '저장하지 못했어요'))),
        );
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 항목 제목. 기능이 요구한 항목이면 "필수"를 붙이고, 비어 있으면 빨간색으로 알린다.
  Widget _label(String text, PrivateField field) {
    final needed = _required.contains(field);
    final missing = needed && !_current.has(field);
    return Row(
      children: [
        Text(text, style: AppTypography.subtitle),
        if (needed) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            missing ? '필수 · 입력해 주세요' : '필수',
            style: AppTypography.caption.copyWith(
              color: missing ? AppColors.danger : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(myPrivateInfoProvider);
    final value = info.value;
    if (value != null && !_loaded) {
      _loaded = true;
      _name.text = value.name ?? '';
      _phone.text = value.phone == null ? '' : formatPhone(value.phone!);
      _detail.text = value.addressDetail ?? '';
      _postcode = value.postcode;
      _address = value.address;
    }
    final request = widget.request;
    final missing = _current.missing(_required);
    final phoneProblem = phoneError(_phone.text);
    final canSave =
        !_busy && _loaded && phoneProblem == null && missing.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 관리')),
      body: switch (info) {
        _ when info.hasError && !_loaded => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('개인정보를 불러오지 못했어요', style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => ref.invalidate(myPrivateInfoProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        _ when !_loaded => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: SkeletonBox(width: double.infinity, height: 240),
        ),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrouped,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      request == null
                          ? '나만 볼 수 있어요. 지금 입력하지 않아도 되고, 동호회 가입·포토북 배송처럼 '
                                '꼭 필요한 기능을 쓸 때만 입력을 요청해요.'
                          : '${request.purpose}에 필요한 항목을 입력해 주세요. '
                                '나만 볼 수 있고, 다른 사람에게는 보이지 않아요.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _label('이름', PrivateField.name),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              maxLength: 20,
              style: AppTypography.body,
              decoration: const InputDecoration(hintText: '받는 분 이름'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('휴대폰 번호', PrivateField.phone),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 13,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: '010-1234-5678',
                errorText: phoneProblem,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('주소', PrivateField.address),
            const SizedBox(height: AppSpacing.sm),
            Pressable(
              onPressed: _busy ? null : _searchAddress,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _address == null
                          ? Text(
                              '주소 검색',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _postcode ?? '',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(_address!, style: AppTypography.body),
                              ],
                            ),
                    ),
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_address != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _detail,
                maxLength: 100,
                style: AppTypography.body,
                decoration: const InputDecoration(hintText: '상세 주소 (동·호수 등)'),
              ),
            ],
          ],
        ),
      },
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _busy
              ? '저장하는 중…'
              : missing.isNotEmpty
              ? '${missing.map((f) => f.label).join(', ')}을(를) 입력해 주세요'
              : request == null
              ? '저장하기'
              : '저장하고 계속하기',
          onPressed: canSave ? _save : null,
        ),
      ),
    );
  }
}
