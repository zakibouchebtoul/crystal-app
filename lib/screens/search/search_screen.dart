import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/service_catalog.dart';
import '../../widgets/search_icon.dart';
import '../messages/messages_effects.dart' show StaggerIn;
import '../service/companies_screen.dart';
import '../service/company_screen.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _border = Color(0xFFF1F2F4);
const _fillColor = Color(0xFFF7F8F9);

/// Hero tag shared with the search box on home.
const searchHeroTag = 'home-search';

/// Recent searches for this session (kept on the device by the backend
/// later).
final _recent = <String>['Car wash', 'Deep clean'];

const _popular = [
  'Full interior deep clean',
  'Standard clean',
  'Wash & fold',
  'Hand wax',
  'Majlis',
];

/// Live search across services, packages and companies. Matching text is
/// highlighted; with an empty box it shows recent and popular searches.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const SearchScreen(),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _ServiceHit {
  const _ServiceHit(this.service, this.because);
  final ServiceDetail service;

  /// What matched besides the name, e.g. an add-on.
  final String? because;
}

class _PackageHit {
  const _PackageHit(this.service, this.package);
  final ServiceDetail service;
  final ServicePackage package;
}

class _CompanyHit {
  const _CompanyHit(this.service, this.offer);
  final ServiceDetail service;
  final CompanyOffer offer;
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _q => _controller.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _remember() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    _recent
      ..removeWhere((r) => r.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_recent.length > 6) _recent.removeLast();
  }

  void _go(Route<void> route) {
    HapticFeedback.selectionClick();
    _remember();
    _focus.unfocus();
    Navigator.of(context).push(route);
  }

  void _fill(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  List<_ServiceHit> get _services {
    final q = _q;
    return [
      for (final s in serviceCatalog.values)
        if (s.title.toLowerCase().contains(q))
          _ServiceHit(s, null)
        else if (_optionMatch(s, q) case final o?)
          _ServiceHit(s, o),
    ];
  }

  /// An option or add-on of [s] matching [q].
  String? _optionMatch(ServiceDetail s, String q) {
    for (final g in s.options) {
      final labels = switch (g) {
        ChoiceGroup(:final choices) => [for (final c in choices) c.$1],
        AddOnGroup(:final addOns) => [for (final a in addOns) a.$1],
        CounterGroup() => <String>[],
      };
      for (final l in labels) {
        if (l.toLowerCase().contains(q)) return l;
      }
    }
    return null;
  }

  List<_PackageHit> get _packages {
    final q = _q;
    return [
      for (final s in serviceCatalog.values)
        for (final p in s.packages)
          if ((p.name.toLowerCase().contains(q) ||
                  p.includes.any((i) => i.toLowerCase().contains(q))) &&
              offersWithPackage(s, p.name).isNotEmpty)
            _PackageHit(s, p),
    ];
  }

  List<_CompanyHit> get _companies {
    final q = _q;
    return [
      for (final s in serviceCatalog.values)
        for (final o in s.companies)
          if (o.company.name.toLowerCase().contains(q) ||
              o.company.area.toLowerCase().contains(q) ||
              o.company.tags.any((t) => t.toLowerCase().contains(q)))
            _CompanyHit(s, o),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                  ),
                  Expanded(
                    child: Hero(
                      tag: searchHeroTag,
                      // Only the box morphs; its contents fade in after.
                      flightShuttleBuilder: (_, _, _, _, _) => Material(
                        color: _fillColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: _fillColor,
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const SearchIcon(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focus,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => setState(_remember),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _ink,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Services, packages, companies',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFB3BCC3),
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (c, a) =>
                                    ScaleTransition(scale: a, child: c),
                                child: _q.isEmpty
                                    ? const SizedBox(width: 12)
                                    : IconButton(
                                        onPressed: _controller.clear,
                                        icon: const Icon(
                                          Icons.cancel_rounded,
                                          size: 20,
                                          color: Color(0xFFB3BCC3),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _q.isEmpty ? _suggestions() : _results(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestions() {
    return ListView(
      key: const ValueKey('suggestions'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_recent.isNotEmpty) ...[
          const _Heading('Recent'),
          for (final r in _recent)
            InkWell(
              onTap: () => _fill(r),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Color(0xFFB3BCC3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(fontSize: 14, color: _ink),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _recent.remove(r)),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFFB3BCC3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
        ],
        const _Heading('Popular right now'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, p) in _popular.indexed)
              StaggerIn(
                delay: Duration(milliseconds: 40 * i),
                builder: (t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                ),
                child: GestureDetector(
                  onTap: () => _fill(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF5FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            p,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const _Heading('Browse services'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (final s in serviceCatalog.values)
              GestureDetector(
                onTap: () => _go(CompaniesScreen.route(s)),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(s.tileImage, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _ink),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _results() {
    final services = _services;
    final packages = _packages;
    final companies = _companies;
    final total = services.length + packages.length + companies.length;
    if (total == 0) {
      return ListView(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Color(0xFFB3BCC3),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing found for "${_controller.text.trim()}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a service like "car wash" or "carpet"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      );
    }
    var row = 0;
    Widget enter(Widget child) {
      final i = row++;
      return StaggerIn(
        key: ValueKey('$_q/$i'),
        delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
        duration: const Duration(milliseconds: 320),
        builder: (t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        ),
        child: child,
      );
    }

    return ListView(
      key: const ValueKey('results'),
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '$total ${total == 1 ? 'result' : 'results'}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
        if (services.isNotEmpty) ...[
          const _Heading('Services'),
          for (final h in services)
            enter(
              _ResultRow(
                image: Image.asset(h.service.tileImage, fit: BoxFit.cover),
                title: h.service.title,
                subtitle: h.because != null
                    ? 'Has ${h.because}'
                    : '${h.service.companies.length} companies',
                query: _q,
                onTap: () => _go(CompaniesScreen.route(h.service)),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (packages.isNotEmpty) ...[
          const _Heading('Packages'),
          for (final h in packages)
            enter(
              _ResultRow(
                image: Image.asset(h.service.tileImage, fit: BoxFit.cover),
                title: h.package.name,
                subtitle: h.service.title,
                trailing: 'from ${lowestPrice(h.service, h.package.name)} QAR',
                query: _q,
                onTap: () => _go(
                  CompanyServiceScreen.compareRoute(
                    h.service,
                    offersWithPackage(h.service, h.package.name).first,
                    h.package.name,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (companies.isNotEmpty) ...[
          const _Heading('Companies'),
          for (final h in companies)
            enter(
              _ResultRow(
                image: Image.asset(
                  h.offer.company.logo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFEFF5FE),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                round: true,
                title: h.offer.company.name,
                subtitle:
                    '${h.service.title} · ★ ${h.offer.company.rating} · '
                    '${h.offer.company.distance}',
                query: _q,
                onTap: () =>
                    _go(CompanyServiceScreen.route(h.service, h.offer)),
              ),
            ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.onTap,
    this.trailing,
    this.round = false,
  });

  final Widget image;
  final String title;
  final String subtitle;
  final String query;
  final VoidCallback onTap;
  final String? trailing;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(round ? 24 : 14),
                  child: SizedBox(width: 48, height: 48, child: image),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Highlighted(text: title, query: query),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFB3BCC3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [text] with the part matching [query] in blue.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _ink,
    );
    final i = query.isEmpty ? -1 : text.toLowerCase().indexOf(query);
    if (i < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + query.length),
            style: const TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: text.substring(i + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}
