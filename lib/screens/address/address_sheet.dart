import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/addresses.dart';
import '../messages/messages_effects.dart' show StaggerIn;

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _border = Color(0xFFF1F2F4);
const _tint = Color(0xFFEFF5FE);

/// Opens the address picker: saved addresses to choose from, and a way to
/// add a new one.
Future<void> showAddressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddressSheet(),
  );
}

IconData _iconFor(AddressKind kind) => switch (kind) {
  AddressKind.home => Icons.home_rounded,
  AddressKind.work => Icons.work_rounded,
  AddressKind.other => Icons.place_rounded,
};

class _AddressSheet extends StatelessWidget {
  const _AddressSheet();

  Future<void> _pick(BuildContext context, SavedAddress a) async {
    HapticFeedback.selectionClick();
    addressBook.select(a.id);
    // Let the check land before closing.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _add(BuildContext context) async {
    final added = await Navigator.of(
      context,
    ).push<bool>(AddAddressScreen.route());
    if (added == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: addressBook,
      builder: (context, _) {
        final all = addressBook.all;
        final selected = addressBook.selected.id;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            10,
            24,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E3E7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Where should we come?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your pro comes to the address you choose',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 16),
                for (final (i, a) in all.indexed)
                  StaggerIn(
                    delay: Duration(milliseconds: 60 * i),
                    builder: (t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AddressRow(
                        address: a,
                        selected: a.id == selected,
                        onTap: () => _pick(context, a),
                      ),
                    ),
                  ),
                StaggerIn(
                  delay: Duration(milliseconds: 60 * all.length),
                  builder: (t, child) =>
                      Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  child: _AddRow(onTap: () => _add(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F9FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : _tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconFor(a.kind),
                size: 22,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  Text(
                    [a.area, if (a.unit != null) a.unit!].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFDDE1E5),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD9E6F7), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _tint,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a new address',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// New address form. A blue Qatar address plate at the top fills in live
/// as zone, street and building are typed.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  static Route<bool> route() => PageRouteBuilder<bool>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const AddAddressScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  AddressKind _kind = AddressKind.home;
  final _name = TextEditingController();
  final _zone = TextEditingController();
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _area = TextEditingController();
  final _unit = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_zone, _street, _building, _area, _name]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _zone, _street, _building, _area, _unit, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _zone.text.trim().isNotEmpty &&
      _street.text.trim().isNotEmpty &&
      _building.text.trim().isNotEmpty &&
      _area.text.trim().isNotEmpty;

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _save() {
    HapticFeedback.mediumImpact();
    addressBook.add(
      SavedAddress(
        id: 'a${DateTime.now().microsecondsSinceEpoch}',
        kind: _kind,
        name: _kind == AddressKind.other ? _opt(_name) : null,
        zone: _zone.text.trim(),
        street: _street.text.trim(),
        building: _building.text.trim(),
        area: _area.text.trim(),
        unit: _opt(_unit),
        note: _opt(_note),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 24, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'New address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _Plate(
                    zone: _zone.text.trim(),
                    street: _street.text.trim(),
                    building: _building.text.trim(),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Find these numbers on the blue plate by your door',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _Label('Save as'),
                  Row(
                    children: [
                      for (final k in AddressKind.values) ...[
                        _KindChip(
                          kind: k,
                          selected: k == _kind,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _kind = k);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _kind == AddressKind.other
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _Field(
                              controller: _name,
                              hint: "Name it, e.g. Mum's house",
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 18),
                  const _Label('Address plate'),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _zone,
                          hint: 'Zone',
                          number: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Field(
                          controller: _street,
                          hint: 'Street',
                          number: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Field(
                          controller: _building,
                          hint: 'Building',
                          number: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _Label('Area'),
                  _Field(controller: _area, hint: 'e.g. West Bay, Lusail'),
                  const SizedBox(height: 18),
                  const _Label('Flat, floor or villa (optional)'),
                  _Field(controller: _unit, hint: 'e.g. Flat 12, 3rd floor'),
                  const SizedBox(height: 18),
                  const _Label('Directions for the pro (optional)'),
                  _Field(
                    controller: _note,
                    hint: 'e.g. Gate code 1234, park by the mosque',
                    lines: 3,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _valid ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFB9D6FC),
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Save address'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qatar's blue address plate; each number rolls in as it's typed.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.zone,
    required this.street,
    required this.building,
  });

  final String zone;
  final String street;
  final String building;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: FittedBox(
                key: ValueKey(value),
                fit: BoxFit.scaleDown,
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Widget divider() => Container(
      width: 1,
      height: 54,
      color: Colors.white.withValues(alpha: 0.25),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565D8), Color(0xFF0B3E8F)],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3E8F).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          cell('ZONE', zone),
          divider(),
          cell('STREET', street),
          divider(),
          cell('BUILDING', building),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ]
          : null,
      textAlign: number ? TextAlign.center : TextAlign.start,
      style: const TextStyle(fontSize: 14, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB3BCC3)),
        filled: true,
        fillColor: const Color(0xFFF7F8F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AddressKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      AddressKind.home => 'Home',
      AddressKind.work => 'Work',
      AddressKind.other => 'Other',
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE6E8EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(kind),
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
