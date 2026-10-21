import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/service_catalog.dart';
import '../../widgets/image_slot.dart';
import '../messages/messages_effects.dart' show StaggerIn;
import '../service/company_screen.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _border = Color(0xFFF1F2F4);

/// A package as it appears across companies.
class _Entry {
  _Entry(this.service, this.package, this.index);

  final ServiceDetail service;
  final ServicePackage package;

  /// Position in the service's packages (for its photo).
  final int index;

  late final List<CompanyOffer> offers = offersWithPackage(
    service,
    package.name,
  );
  late final int? price = lowestPrice(service, package.name);
  double get rating => offers.isEmpty ? 0 : offers.first.company.rating;
}

/// Every package people book, across all services: most booked first,
/// then the best rated. Chips at the top narrow it to one service.
class PopularScreen extends StatefulWidget {
  const PopularScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const PopularScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<PopularScreen> createState() => _PopularScreenState();
}

class _PopularScreenState extends State<PopularScreen> {
  /// Selected service id; null = all.
  String? _filter;

  late final List<_Entry> _all =
      [
        for (final s in serviceCatalog.values)
          for (final (i, p) in s.packages.indexed)
            if (offersWithPackage(s, p.name).isNotEmpty) _Entry(s, p, i),
      ]..sort((a, b) {
        if (a.package.mostBooked != b.package.mostBooked) {
          return a.package.mostBooked ? -1 : 1;
        }
        return b.rating.compareTo(a.rating);
      });

  List<_Entry> get _shown => _filter == null
      ? _all
      : _all.where((e) => e.service.id == _filter).toList();

  void _open(_Entry e) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      CompanyServiceScreen.compareRoute(
        e.service,
        e.offers.first,
        e.package.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Popular services',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'What people in Doha book the most',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final s in serviceCatalog.values)
                    _FilterChip(
                      label: s.title,
                      image: s.tileImage,
                      selected: _filter == s.id,
                      onTap: () => setState(() => _filter = s.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: ListView.builder(
                  key: ValueKey(_filter),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    4,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => StaggerIn(
                    delay: Duration(milliseconds: 40 * i.clamp(0, 10)),
                    builder: (t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PackageRow(
                        entry: shown[i],
                        onTap: () => _open(shown[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.image,
  });

  final String label;
  final String? image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.fromLTRB(image == null ? 16 : 5, 5, 14, 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE6E8EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null) ...[
                ClipOval(
                  child: Image.asset(
                    image!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
      ),
    );
  }
}

class _PackageRow extends StatefulWidget {
  const _PackageRow({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  State<_PackageRow> createState() => _PackageRowState();
}

class _PackageRowState extends State<_PackageRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final p = e.package;
    final minutes = p.minutes;
    final duration = minutes < 60
        ? '$minutes min'
        : minutes % 60 == 0
        ? '${minutes ~/ 60} h'
        : '${minutes ~/ 60} h ${minutes % 60} min';
    final companies = e.offers.length;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 200),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: ImageSlot(
                    asset:
                        'assets/images/services/${e.service.id}_pkg_${e.index + 1}.jpg',
                    label: '',
                    fallback: Image.asset(
                      e.service.tileImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.mostBooked) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔥 Most booked',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDeep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.service.title} · $duration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFFB020),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${e.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' · $companies '
                            '${companies == 1 ? 'company' : 'companies'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'from',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                  Text(
                    '${e.price}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'QAR',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
