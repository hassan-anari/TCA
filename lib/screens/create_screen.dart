import 'dart:io';

import 'package:flutter/material.dart'
    show TextField, InputDecoration, InputBorder, TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/formatting.dart';
import '../data/models.dart';
import '../design/components/atmospheric_background.dart';
import '../design/components/celestial_button.dart';
import '../design/components/glass_surface.dart';
import '../design/components/organic_bottom_sheet.dart';
import '../design/components/pressable.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_providers.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 04 - Create Memory Capsule (local prototype data only).
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key, this.year});
  final int? year;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

enum _UnlockPreset { month, halfYear, year, custom }

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  late DateTime _memoryDate;
  late DateTime _unlockAt;
  _UnlockPreset _preset = _UnlockPreset.year;
  MemoryKind _kind = MemoryKind.personal;
  String? _photo;
  bool _sealing = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(memoriaProvider).now();
    final y = widget.year ?? now.year.clamp(2024, 2026);
    _memoryDate = y == now.year
        ? DateTime(now.year, now.month, now.day)
        : DateTime(y, 6, 1);
    _unlockAt = _presetDate(_UnlockPreset.year, now);
    _title.addListener(() => setState(() {}));
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(sceneControllerProvider).setActive(false),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  DateTime _presetDate(_UnlockPreset p, DateTime now) => switch (p) {
    _UnlockPreset.month => DateTime(now.year, now.month + 1, now.day, 9),
    _UnlockPreset.halfYear => DateTime(now.year, now.month + 6, now.day, 9),
    _UnlockPreset.year ||
    _UnlockPreset.custom => DateTime(now.year + 1, now.month, now.day, 9),
  };

  bool get _valid =>
      _text.text.trim().isNotEmpty &&
      _unlockAt.isAfter(ref.read(memoriaProvider).now());

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (f != null) setState(() => _photo = f.path);
    } catch (_) {
      // Picker unavailable (e.g. no gallery app on an emulator) - attachment stays optional.
    }
  }

  Future<void> _pickDate({required bool unlock}) async {
    final now = ref.read(memoriaProvider).now();
    final initial = unlock ? _unlockAt : _memoryDate;
    final first = unlock
        ? now.add(const Duration(days: 1))
        : DateTime(2024, 1, 1);
    final last = unlock
        ? DateTime(now.year + 10, 12, 31)
        : DateTime(2026, 12, 31);
    final picked = await showDateWheel(
      context,
      initial: initial,
      first: first,
      last: last,
      title: unlock ? 'Unlock date' : 'Memory date',
    );
    if (picked == null) return;
    setState(() {
      if (unlock) {
        _unlockAt = DateTime(picked.year, picked.month, picked.day, 9);
        _preset = _UnlockPreset.custom;
      } else {
        _memoryDate = picked;
      }
    });
  }

  Future<void> _seal() async {
    if (!_valid || _sealing) return;
    setState(() => _sealing = true);
    final m = await ref
        .read(memoriaProvider.notifier)
        .sealCapsule(
          title: _title.text,
          text: _text.text,
          memoryDate: _memoryDate,
          unlockAt: _unlockAt,
          kind: _kind,
          photoPath: _photo,
        );
    if (mounted) context.go('/capsule/${m.id}');
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final now = ref.watch(memoriaProvider).now();
    return ScreenFrame(
      parent: widget.year == null ? '/' : '/galaxy/${widget.year}',
      child: Stack(
        children: [
          Positioned.fill(
            child: AtmosphericBackground(warmth: 0.55, animate: !reduced),
          ),
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                MemoriaSpacing.screenH,
                0,
                MemoriaSpacing.screenH,
                140,
              ),
              children: [
                TitleBar(
                  onBack: () => context.go(
                    widget.year == null ? '/' : '/galaxy/${widget.year}',
                  ),
                ),
                const SizedBox(height: MemoriaSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a memory',
                            style: MemoriaType.displayL(context),
                          ),
                          const SizedBox(height: MemoriaSpacing.xs),
                          Text(
                            'CAPTURE THE MOMENT',
                            style: MemoriaType.eyebrow(context),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Icon(
                        LucideIcons.feather,
                        size: 30,
                        color: MemoriaColors.blush,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MemoriaSpacing.xl),
                GlassSurface(
                  radius: MemoriaRadii.md,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: TextField(
                    key: const ValueKey('memory-title'),
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    style: MemoriaType.headingM(context).copyWith(fontSize: 22),
                    cursorColor: MemoriaColors.memoryGlow,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Memory title',
                      hintStyle: MemoriaType.headingM(context).copyWith(
                        fontSize: 22,
                        color: MemoriaColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MemoriaSpacing.md),
                GlassSurface(
                  radius: MemoriaRadii.lg,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    key: const ValueKey('memory-text'),
                    controller: _text,
                    minLines: 5,
                    maxLines: 10,
                    textCapitalization: TextCapitalization.sentences,
                    style: MemoriaType.body(context),
                    cursorColor: MemoriaColors.memoryGlow,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What happened?',
                      hintStyle: MemoriaType.body(
                        context,
                      ).copyWith(color: MemoriaColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: MemoriaSpacing.lg),
                _FieldRow(
                  key: const ValueKey('memory-date'),
                  icon: LucideIcons.calendar,
                  label: 'Memory date',
                  value: formatDate(_memoryDate),
                  onTap: () => _pickDate(unlock: false),
                ),
                const SizedBox(height: MemoriaSpacing.sm),
                _FieldRow(
                  key: const ValueKey('unlock-date'),
                  icon: LucideIcons.lock,
                  label: 'Unlock date',
                  value: formatDate(_unlockAt),
                  onTap: () => _pickDate(unlock: true),
                ),
                const SizedBox(height: MemoriaSpacing.sm),
                Wrap(
                  spacing: MemoriaSpacing.xs,
                  runSpacing: MemoriaSpacing.xs,
                  children: [
                    for (final (p, l) in const [
                      (_UnlockPreset.month, 'In 1 month'),
                      (_UnlockPreset.halfYear, 'In 6 months'),
                      (_UnlockPreset.year, 'In 1 year'),
                    ])
                      _Pill(
                        label: l,
                        selected: _preset == p,
                        onTap: () => setState(() {
                          _preset = p;
                          _unlockAt = _presetDate(p, now);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: MemoriaSpacing.lg),
                _KindToggle(
                  kind: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                ),
                const SizedBox(height: MemoriaSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Add photo',
                      style: MemoriaType.label(context).copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    Text('Optional', style: MemoriaType.meta(context)),
                  ],
                ),
                const SizedBox(height: MemoriaSpacing.sm),
                Row(
                  children: [
                    Pressable(
                      onPressed: _pickPhoto,
                      child: Semantics(
                        button: true,
                        label: 'Attach a photo from this device',
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: GlassSurface(
                            radius: MemoriaRadii.md,
                            child: const Center(
                              child: Icon(
                                LucideIcons.plus,
                                size: 26,
                                color: MemoriaColors.warmIvory,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_photo != null) ...[
                      const SizedBox(width: MemoriaSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MemoriaRadii.md),
                        child: Image.file(
                          File(_photo!),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: MemoriaSpacing.screenH,
            right: MemoriaSpacing.screenH,
            bottom: MemoriaSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_valid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MemoriaSpacing.sm),
                    child: Text(
                      'Write a few words to seal this capsule.',
                      style: MemoriaType.meta(context),
                    ),
                  ),
                CelestialButton(
                  key: const ValueKey('seal-capsule'),
                  label: _sealing ? 'Sealing...' : 'Seal Capsule',
                  icon: LucideIcons.lock,
                  onPressed: _valid && !_sealing ? _seal : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Pressable(
        onPressed: onTap,
        child: GlassSurface(
          radius: MemoriaRadii.md,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: MemoriaColors.softSage),
              const SizedBox(width: MemoriaSpacing.sm),
              Text(label, style: MemoriaType.label(context)),
              const SizedBox(width: MemoriaSpacing.sm),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: MemoriaType.meta(
                    context,
                  ).copyWith(color: MemoriaColors.memoryGlow),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: MemoriaColors.celestialMist,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: MemoriaDurations.medium,
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemoriaRadii.pill),
            color: selected
                ? MemoriaColors.memoryGlow.withValues(alpha: 0.18)
                : MemoriaColors.warmIvory.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? MemoriaColors.memoryGlow.withValues(alpha: 0.6)
                  : MemoriaColors.warmIvory.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: MemoriaType.meta(
              context,
            ).copyWith(color: MemoriaColors.warmIvory),
          ),
        ),
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});
  final MemoryKind kind;
  final ValueChanged<MemoryKind> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(MemoryKind k, IconData icon, String title, String sub) {
      final sel = kind == k;
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          label: '$title, $sub',
          excludeSemantics: true,
          child: Pressable(
            onPressed: () => onChanged(k),
            child: AnimatedContainer(
              key: ValueKey('kind-${k.name}'),
              duration: MemoriaDurations.medium,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MemoriaRadii.md),
                color: sel
                    ? MemoriaColors.warmIvory.withValues(alpha: 0.13)
                    : const Color(0x00000000),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: sel
                        ? MemoriaColors.memoryGlow
                        : MemoriaColors.softSage,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MemoriaType.headingM(
                            context,
                          ).copyWith(fontSize: 20),
                        ),
                        Text(
                          sub,
                          style: MemoriaType.meta(
                            context,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GlassSurface(
      radius: MemoriaRadii.lg,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          seg(
            MemoryKind.personal,
            LucideIcons.user,
            'Personal',
            'Only for you',
          ),
          const SizedBox(width: 6),
          seg(
            MemoryKind.shared,
            LucideIcons.users,
            'Shared',
            'With your people',
          ),
        ],
      ),
    );
  }
}

/// Custom date picker: three wheels in an organic glass sheet (no stock
/// Material/Cupertino picker visuals).
Future<DateTime?> showDateWheel(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required String title,
}) {
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x99050F12),
    transitionDuration: MemoriaDurations.medium,
    pageBuilder: (context, _, _) =>
        _DateWheel(initial: initial, first: first, last: last, title: title),
    transitionBuilder: (context, a, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: MemoriaCurves.gentle)),
      child: child,
    ),
  );
}

class _DateWheel extends StatefulWidget {
  const _DateWheel({
    required this.initial,
    required this.first,
    required this.last,
    required this.title,
  });
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_DateWheel> createState() => _DateWheelState();
}

class _DateWheelState extends State<_DateWheel> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  late int _y, _m, _d;

  @override
  void initState() {
    super.initState();
    final i = widget.initial.isBefore(widget.first)
        ? widget.first
        : (widget.initial.isAfter(widget.last) ? widget.last : widget.initial);
    _y = i.year;
    _m = i.month;
    _d = i.day;
  }

  int get _daysInMonth => DateTime(_y, _m + 1, 0).day;

  DateTime get _value {
    final v = DateTime(_y, _m, _d.clamp(1, _daysInMonth));
    if (v.isBefore(widget.first)) {
      return DateTime(widget.first.year, widget.first.month, widget.first.day);
    }
    if (v.isAfter(widget.last)) {
      return DateTime(widget.last.year, widget.last.month, widget.last.day);
    }
    return v;
  }

  Widget _wheel(
    List<String> items,
    int index,
    ValueChanged<int> onChanged, {
    double width = 80,
  }) {
    return SizedBox(
      width: width,
      height: 180,
      child: ListWheelScrollView.useDelegate(
        controller: FixedExtentScrollController(initialItem: index),
        itemExtent: 40,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, i) => Center(
            child: Text(
              items[i],
              style: MemoriaType.headingM(context).copyWith(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = widget.first.year; y <= widget.last.year; y++) y,
    ];
    return Align(
      alignment: Alignment.bottomCenter,
      child: OrganicBottomSheet(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: MemoriaType.headingM(context)),
              const SizedBox(height: MemoriaSpacing.md),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MemoriaRadii.sm),
                      color: MemoriaColors.warmIvory.withValues(alpha: 0.07),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _wheel(
                        _months,
                        _m - 1,
                        (i) => setState(() => _m = i + 1),
                      ),
                      _wheel(
                        [for (var d = 1; d <= 31; d++) '$d'],
                        _d - 1,
                        (i) => setState(() => _d = i + 1),
                        width: 60,
                      ),
                      _wheel(
                        [for (final y in years) '$y'],
                        years.indexOf(_y).clamp(0, years.length - 1),
                        (i) => setState(() => _y = years[i]),
                        width: 90,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: MemoriaSpacing.lg),
              CelestialButton(
                label: 'Set ${formatShortDate(_value)}',
                icon: LucideIcons.check,
                onPressed: () => Navigator.of(context).pop(_value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
