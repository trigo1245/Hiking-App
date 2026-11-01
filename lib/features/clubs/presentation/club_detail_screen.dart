import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/nickname_text.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/public_profile_sheet.dart';
import '../data/club_remote.dart';
import '../domain/club.dart';
import 'club_avatar.dart';
import 'club_event_form_screen.dart';
import 'club_format.dart';

/// 클럽 화면을 다시 받아야 할 때 (가입·탈퇴·승인·공지·일정 등)
void refreshClub(WidgetRef ref, String clubId) {
  ref
    ..invalidate(clubDetailProvider(clubId))
    ..invalidate(clubMembersProvider(clubId))
    ..invalidate(clubNoticesProvider(clubId))
    ..invalidate(clubEventsProvider(clubId))
    ..invalidate(clubJoinRequestsProvider(clubId))
    ..invalidate(myClubStatusProvider)
    ..invalidate(clubListProvider)
    ..invalidate(clubRankingProvider);
}

/// 서버 요청을 하고 결과를 짧게 알린다. 성공하면 true.
Future<bool> runClubAction(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    }
    return true;
  } catch (e) {
    debugPrint('[club] $e');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(clubErrorMessage(e))));
    return false;
  }
}

/// 동호회 상세 (목록·랭킹에서 들어온다). 회원이 아니면 아래에 가입 신청 버튼.
class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubDetailProvider(clubId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(club?.name ?? '동호회')),
      body: ClubBody(clubId: clubId),
      bottomNavigationBar: club == null || club.status.isMember
          ? null
          : BottomActionBar(child: _JoinButton(club: club)),
    );
  }
}

class _JoinButton extends ConsumerWidget {
  const _JoinButton({required this.club});

  final ClubDetail club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.read(clubRemoteProvider);
    return switch (club.status) {
      ClubStatus.pending => AppButton(
        label: '가입 신청 취소하기',
        variant: AppButtonVariant.secondary,
        onPressed: () async {
          await runClubAction(
            context,
            remote.cancelJoinRequest,
            done: '가입 신청을 취소했어요',
          );
          refreshClub(ref, club.id);
        },
      ),
      ClubStatus.otherClub => const AppButton(
        label: '이미 다른 동호회에 소속돼 있어요',
        onPressed: null,
      ),
      _ when club.isFull => const AppButton(
        label: '인원이 가득 찼어요',
        onPressed: null,
      ),
      _ => AppButton(
        label: '가입 신청하기',
        onPressed: () async {
          await runClubAction(
            context,
            () => remote.requestJoin(club.id),
            done: '가입 신청했어요. 클럽장이 승인하면 회원이 돼요',
          );
          refreshClub(ref, club.id);
        },
      ),
    };
  }
}

enum _Section { notices, events, members }

/// 클럽 내용: 소개(누구나) + 공지·일정·회원(회원만) + 클럽장 도구.
/// 동호회 탭의 "내 클럽"과 상세 화면이 함께 쓴다.
class ClubBody extends ConsumerStatefulWidget {
  const ClubBody({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<ClubBody> createState() => _ClubBodyState();
}

class _ClubBodyState extends ConsumerState<ClubBody> {
  _Section _section = _Section.notices;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(clubDetailProvider(widget.clubId));
    return switch (detail) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () async => refreshClub(ref, widget.clubId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          children: [
            _Header(club: value),
            if (value.status == ClubStatus.leader) ...[
              const SizedBox(height: AppSpacing.lg),
              _LeaderTools(club: value),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (!value.status.isMember)
              Text(
                '회원 목록·공지·일정은 회원만 볼 수 있어요',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else ...[
              SegmentedTabs<_Section>(
                options: const {
                  _Section.notices: '공지',
                  _Section.events: '일정',
                  _Section.members: '회원',
                },
                selected: _section,
                onChanged: (s) => setState(() => _section = s),
              ),
              const SizedBox(height: AppSpacing.lg),
              switch (_section) {
                _Section.notices => _Notices(club: value),
                _Section.events => _Events(club: value),
                _Section.members => _Members(club: value),
              },
              const SizedBox(height: AppSpacing.xxxl),
              _LeaveRow(club: value),
            ],
          ],
        ),
      ),
      AsyncValue(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is StateError ? '동호회를 찾지 못했어요' : '동호회를 불러오지 못했어요',
              style: AppTypography.subtitle,
            ),
            TextButton(
              onPressed: () => refreshClub(ref, widget.clubId),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      AsyncData() => const Center(
        child: Text('없어진 동호회예요', style: AppTypography.subtitle),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenHorizontal),
        child: SkeletonBox(width: double.infinity, height: 200),
      ),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.club});

  final ClubDetail club;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClubAvatar(name: club.name, photoUrl: club.photoUrl, size: 72),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: AppTypography.title),
                  if (club.region case final region? when region.isNotEmpty)
                    Text(
                      region,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        '회원 ${club.memberCount}/${club.maxMembers} · 클럽장 ',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: NicknameText(
                          nickname: club.leaderNickname,
                          tag: club.leaderTag,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.backgroundGrouped,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 시즌 클럽 완등 ${club.seasonCompletions}회',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                (club.bio ?? '').isEmpty ? '아직 소개가 없어요' : club.bio!,
                style: AppTypography.body.copyWith(
                  color: (club.bio ?? '').isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 클럽장 도구: 가입 신청, 정보 수정
class _LeaderTools extends StatelessWidget {
  const _LeaderTools({required this.club});

  final ClubDetail club;

  @override
  Widget build(BuildContext context) {
    Widget tool(String label, VoidCallback onTap, {String? badge}) => Expanded(
      child: Pressable(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTypography.body),
              if (badge != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        tool(
          '가입 신청',
          () => context.push(AppRoutes.clubRequests(club.id)),
          badge: club.pendingRequests > 0 ? '${club.pendingRequests}' : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        tool('정보 수정', () => context.push(AppRoutes.clubEdit(club.id))),
      ],
    );
  }
}

class _Notices extends ConsumerWidget {
  const _Notices({required this.club});

  final ClubDetail club;

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
          AppSpacing.screenHorizontal,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('공지 쓰기', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: clubNoticeMaxLength,
              minLines: 3,
              maxLines: 8,
              style: AppTypography.body,
              decoration: const InputDecoration(hintText: '회원에게 알릴 내용을 적어 주세요'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '올리기',
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty || !context.mounted) return;
    await runClubAction(
      context,
      () => ref.read(clubRemoteProvider).postNotice(club.id, body),
      done: '공지를 올렸어요',
    );
    ref.invalidate(clubNoticesProvider(club.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(clubNoticesProvider(club.id));
    final leader = club.status == ClubStatus.leader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leader) ...[
          AppButton(
            label: '공지 쓰기',
            variant: AppButtonVariant.secondary,
            onPressed: () => _write(context, ref),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ...switch (notices) {
          AsyncValue(:final value?) when value.isEmpty => [
            const _Empty('아직 공지가 없어요'),
          ],
          AsyncValue(:final value?) => [
            for (final n in value)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formatShortDate(n.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        if (leader)
                          Pressable(
                            onPressed: () async {
                              final ok = await showConfirmSheet(
                                context,
                                title: '이 공지를 지울까요?',
                                message: '지운 공지는 다시 살릴 수 없어요.',
                                confirmLabel: '지우기',
                                cancelLabel: '취소',
                              );
                              if (ok != true || !context.mounted) return;
                              await runClubAction(
                                context,
                                () => ref
                                    .read(clubRemoteProvider)
                                    .deleteNotice(n.id),
                              );
                              ref.invalidate(clubNoticesProvider(club.id));
                            },
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                              semanticLabel: '공지 지우기',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(n.body, style: AppTypography.body),
                  ],
                ),
              ),
          ],
          AsyncValue(:final error?) => [_Empty(clubErrorMessage(error))],
          _ => [const SkeletonBox(width: double.infinity, height: 80)],
        },
      ],
    );
  }
}

class _Events extends ConsumerWidget {
  const _Events({required this.club});

  final ClubDetail club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(clubEventsProvider(club.id));
    final leader = club.status == ClubStatus.leader;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leader) ...[
          AppButton(
            label: '일정 만들기',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              final created = await ClubEventFormScreen.open(context, club.id);
              if (created == true) ref.invalidate(clubEventsProvider(club.id));
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ...switch (events) {
          AsyncValue(:final value?) when value.isEmpty => [
            const _Empty('아직 일정이 없어요'),
          ],
          AsyncValue(:final value?) => [
            for (final e in value)
              _EventCard(
                club: club,
                event: e,
                past: e.isPast(now),
                leader: leader,
              ),
          ],
          AsyncValue(:final error?) => [_Empty(clubErrorMessage(error))],
          _ => [const SkeletonBox(width: double.infinity, height: 120)],
        },
      ],
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.club,
    required this.event,
    required this.past,
    required this.leader,
  });

  final ClubDetail club;
  final ClubEvent event;
  final bool past;
  final bool leader;

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    EventAnswer answer,
  ) async {
    // 같은 답을 다시 누르면 답을 지운다.
    final next = event.myAnswer == answer ? null : answer;
    await runClubAction(
      context,
      () => ref.read(clubRemoteProvider).vote(event.id, next),
    );
    ref.invalidate(clubEventsProvider(club.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget voteButton(EventAnswer answer, int count) {
      final selected = event.myAnswer == answer;
      return Expanded(
        child: Pressable(
          onPressed: past ? null : () => _vote(context, ref, answer),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Text(
              '${answer.label} $count',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: past ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundGrouped,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    past
                        ? '지난 일정 · ${formatEventTime(event.startsAt)}'
                        : formatEventTime(event.startsAt),
                    style: AppTypography.caption.copyWith(
                      color: past ? AppColors.textTertiary : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (leader)
                  Pressable(
                    onPressed: () async {
                      final ok = await showConfirmSheet(
                        context,
                        title: '이 일정을 지울까요?',
                        message: '참석 투표도 함께 지워져요.',
                        confirmLabel: '지우기',
                        cancelLabel: '취소',
                      );
                      if (ok != true || !context.mounted) return;
                      await runClubAction(
                        context,
                        () =>
                            ref.read(clubRemoteProvider).deleteEvent(event.id),
                      );
                      ref.invalidate(clubEventsProvider(club.id));
                    },
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                      semanticLabel: '일정 지우기',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(event.title, style: AppTypography.subtitle),
            if (event.place case final place? when place.isNotEmpty)
              Text(
                place,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (event.memo case final memo? when memo.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(memo, style: AppTypography.body),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                voteButton(EventAnswer.going, event.going),
                const SizedBox(width: AppSpacing.sm),
                voteButton(EventAnswer.notGoing, event.notGoing),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Pressable(
              onPressed: () => _showVotes(context, event),
              child: Text(
                '누가 오는지 보기',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showVotes(BuildContext context, ClubEvent event) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final votes = ref.watch(eventVotesProvider(event.id));
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.xl,
              ),
              child: switch (votes) {
                AsyncValue(:final value?) => ListView(
                  shrinkWrap: true,
                  children: [
                    Text(event.title, style: AppTypography.subtitle),
                    const SizedBox(height: AppSpacing.md),
                    for (final answer in EventAnswer.values) ...[
                      Text(
                        '${answer.label} ${value.where((v) => v.answer == answer).length}명',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final v in value.where((v) => v.answer == answer))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              UserAvatar(
                                nickname: v.nickname,
                                imageUrl: v.avatarUrl,
                                size: 28,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: NicknameText(
                                  nickname: v.nickname,
                                  tag: v.nicknameTag,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
                AsyncValue(:final error?) => _Empty(clubErrorMessage(error)),
                _ => const SkeletonBox(width: double.infinity, height: 80),
              },
            ),
          );
        },
      ),
    );
  }
}

class _Members extends ConsumerWidget {
  const _Members({required this.club});

  final ClubDetail club;

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    ClubMember m,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: '${m.nickname}님에게 클럽장을 넘길까요?',
      message: '넘기면 가입 승인·공지·일정은 새 클럽장이 맡아요. 나는 일반 회원이 돼요.',
      confirmLabel: '넘기기',
      cancelLabel: '취소',
    );
    if (ok != true || !context.mounted) return;
    await runClubAction(
      context,
      () => ref.read(clubRemoteProvider).transferLeader(club.id, m.userId),
      done: '클럽장을 넘겼어요',
    );
    refreshClub(ref, club.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(clubMembersProvider(club.id));
    final leader = club.status == ClubStatus.leader;
    return switch (members) {
      AsyncValue(:final value?) => Column(
        children: [
          for (final m in value)
            Pressable(
              onPressed: () => showPublicProfile(
                context,
                nickname: m.nickname,
                tag: m.nicknameTag,
                avatarUrl: m.avatarUrl,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    UserAvatar(
                      nickname: m.nickname,
                      imageUrl: m.avatarUrl,
                      size: 40,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NicknameText(
                            nickname: m.nickname,
                            tag: m.nicknameTag,
                            suffix: m.isMe ? ' (나)' : null,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${m.isLeader ? '클럽장 · ' : ''}이번 시즌 완등 ${m.seasonCompletions}회',
                            style: AppTypography.caption.copyWith(
                              color: m.isLeader
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (leader && !m.isLeader)
                      PopupMenuButton<String>(
                        tooltip: '회원 관리',
                        onSelected: (_) => _transfer(context, ref, m),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'transfer',
                            child: Text('클럽장 넘기기'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      AsyncValue(:final error?) => _Empty(clubErrorMessage(error)),
      _ => const SkeletonBox(width: double.infinity, height: 160),
    };
  }
}

/// 맨 아래: 회원은 "동호회 나가기", 클럽장은 "동호회 없애기"
class _LeaveRow extends ConsumerWidget {
  const _LeaveRow({required this.club});

  final ClubDetail club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leader = club.status == ClubStatus.leader;
    return Center(
      child: Pressable(
        onPressed: () async {
          final ok = await showConfirmSheet(
            context,
            title: leader ? '동호회를 없앨까요?' : '동호회를 나갈까요?',
            message: leader
                ? '회원·공지·일정이 모두 사라지고 되돌릴 수 없어요. '
                      '클럽을 남기고 나가려면 회원 목록에서 클럽장을 먼저 넘겨 주세요.'
                : '나가기 전에 한 완등은 이 동호회 실적에 그대로 남아요. '
                      '다시 들어오려면 가입 신청을 해야 해요.',
            confirmLabel: leader ? '없애기' : '나가기',
            cancelLabel: '취소',
          );
          if (ok != true || !context.mounted) return;
          final remote = ref.read(clubRemoteProvider);
          final done = await runClubAction(
            context,
            leader ? () => remote.disbandClub(club.id) : remote.leaveClub,
            done: leader ? '동호회를 없앴어요' : '동호회를 나왔어요',
          );
          refreshClub(ref, club.id);
          if (done && context.mounted && context.canPop()) context.pop();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            leader ? '동호회 없애기' : '동호회 나가기',
            style: AppTypography.body.copyWith(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: AppTypography.body.copyWith(color: AppColors.textTertiary),
    ),
  );
}
