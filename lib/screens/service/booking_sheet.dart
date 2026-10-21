import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../data/addresses.dart';
import '../../data/bookings.dart';
import '../../data/offers.dart';
import '../../data/service_catalog.dart';
import '../address/address_sheet.dart';

const _ink = Color(0xFF0D0D12);
const _muted = Color(0xFF6A7B89);
const _card = Color(0xFFF7F8F9);

class BookingSummary {
  const BookingSummary({
    required this.service,
    required this.package,
    required this.options,
    required this.date,
    required this.time,
    required this.company,
    required this.total,
  });

  final ServiceDetail service;
  final ServicePackage package;
  final List<String> options;
  final DateTime date;
  final String time;
  final Company company;

  /// Before any offer.
  final int total;

  /// The offer the customer chose, if it applies to this service.
  Offer? get offer {
    final o = appliedOffer.value;
    return o != null && o.serviceId == service.id ? o : null;
  }

  int get discount =>
      offer == null ? 0 : (total * offer!.percent / 100).round();

  /// What the customer pays.
  int get payable => total - discount;

  /// [date] at [time] ("10:00 AM").
  DateTime get start {
    final m = RegExp(r'(\d+):(\d+)\s*([AP]M)').firstMatch(time);
    if (m == null) return date;
    var hour = int.parse(m[1]!) % 12;
    if (m[3] == 'PM') hour += 12;
    return DateTime(date.year, date.month, date.day, hour, int.parse(m[2]!));
  }
}

/// Slides up the booking summary; confirming shows a success state.
Future<void> showBookingSheet(BuildContext context, BookingSummary summary) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _BookingSheet(summary: summary),
  );
}

enum _Stage { review, confirming, payment, paying, done }

enum _PayMethod { online, cash }

/// How to pay online.
enum _Wallet { applePay, googlePay, card }

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.summary});

  final BookingSummary summary;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  _Stage _stage = _Stage.review;
  _PayMethod _method = _PayMethod.online;
  _Wallet? _wallet;

  /// Note for the pro when paying cash: bring change for this note
  /// (null = exact amount).
  int? _changeFor;

  /// Reserves the slot, then asks how to pay.
  Future<void> _confirm() async {
    setState(() => _stage = _Stage.confirming);
    // TODO: create the booking through the backend.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _stage = _Stage.payment);
  }

  Future<void> _pay() async {
    setState(() => _stage = _Stage.paying);
    // TODO: online → open the payment gateway checkout; cash → mark the
    // booking as cash on delivery.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final s = widget.summary;
    // TODO: save through the backend; for now it shows in the calendar
    // and on home.
    bookingStore.add(
      Booking(
        title: s.package.name,
        type: ServiceType.forServiceId(s.service.id),
        start: s.start,
        duration: Duration(minutes: s.package.minutes),
        provider: s.company.name,
        price: s.payable,
        rating: s.company.rating,
        reviews: s.company.reviewCount,
        serviceId: s.service.id,
        companyId: s.company.id,
        package: s.package.name,
      ),
    );
    // An offer is used once.
    if (s.offer != null) appliedOffer.value = null;
    HapticFeedback.heavyImpact();
    setState(() => _stage = _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 16 + bottom),
      // Scrolls on short screens instead of overflowing.
      child: SingleChildScrollView(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_stage) {
              _Stage.review || _Stage.confirming => _Review(
                summary: widget.summary,
                confirming: _stage == _Stage.confirming,
                onConfirm: _confirm,
              ),
              _Stage.payment || _Stage.paying => _Payment(
                total: widget.summary.payable,
                method: _method,
                // Apple Pay on iPhone, Google Pay on Android, by default.
                wallet:
                    _wallet ??
                    (Theme.of(context).platform == TargetPlatform.iOS
                        ? _Wallet.applePay
                        : _Wallet.googlePay),
                changeFor: _changeFor,
                paying: _stage == _Stage.paying,
                onMethod: (m) {
                  HapticFeedback.selectionClick();
                  setState(() => _method = m);
                },
                onWallet: (w) {
                  HapticFeedback.selectionClick();
                  setState(() => _wallet = w);
                },
                onChange: (c) {
                  HapticFeedback.selectionClick();
                  setState(() => _changeFor = c);
                },
                onPay: _pay,
              ),
              _Stage.done => _Success(
                summary: widget.summary,
                cash: _method == _PayMethod.cash,
                changeFor: _changeFor,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The booking at a glance: who and what at the top, a date tile with the
/// time and duration, the address on a little map, chosen options as
/// chips, and the price broken down. Blocks slide in one after another.
class _Review extends StatelessWidget {
  const _Review({
    required this.summary,
    required this.confirming,
    required this.onConfirm,
  });

  final BookingSummary summary;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final extras = s.total - s.package.price;
    final blocks = <Widget>[
      _ServiceBlock(summary: s),
      _WhenBlock(date: s.date, time: s.time, minutes: s.package.minutes),
      const _AddressBlock(),
      if (s.options.isNotEmpty) _OptionsBlock(options: s.options),
      _PriceBlock(
        package: s.package.name,
        packagePrice: s.package.price,
        extras: extras,
        offer: s.offer,
        discount: s.discount,
        total: s.payable,
      ),
    ];
    return Column(
      key: const ValueKey('review'),
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
          'Review your booking',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, block) in blocks.indexed)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 320 + i * 80),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: block,
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: confirming ? () {} : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: confirming
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm booking'),
          ),
        ),
      ],
    );
  }
}

/// White block with the app's soft border.
class _Block extends StatelessWidget {
  const _Block({required this.child, this.padding = 14});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F2F4)),
      ),
      child: child,
    );
  }
}

class _ServiceBlock extends StatelessWidget {
  const _ServiceBlock({required this.summary});

  final BookingSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = summary.company;
    return _Block(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              c.logo,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                color: const Color(0xFFEFF5FE),
                child: Text(
                  c.name.characters.first,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${c.name} · ${summary.service.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                    if (c.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  '${c.rating}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenBlock extends StatelessWidget {
  const _WhenBlock({
    required this.date,
    required this.time,
    required this.minutes,
  });

  final DateTime date;
  final String time;
  final int minutes;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final duration = minutes < 60
        ? '$minutes min'
        : minutes % 60 == 0
        ? '${minutes ~/ 60} h'
        : '${minutes ~/ 60} h ${minutes % 60} min';
    return _Block(
      child: Row(
        children: [
          // Calendar-page tile.
          Container(
            width: 46,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E8EB)),
            ),
            child: Column(
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  alignment: Alignment.center,
                  color: AppColors.primary,
                  child: Text(
                    _months[date.month - 1],
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _days[date.weekday - 1],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Arrives at $time',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The address the pro comes to; tap to pick another.
class _AddressBlock extends StatelessWidget {
  const _AddressBlock();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: addressBook,
      builder: (context, _) {
        final a = addressBook.selected;
        return GestureDetector(
          onTap: () => showAddressSheet(context),
          child: _Block(
            padding: 8,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 62,
                    height: 56,
                    child: CustomPaint(painter: _MiniMapPainter()),
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
                      const SizedBox(height: 3),
                      Text(
                        a.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A tiny street map with a pin, drawn in code.
class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF1F8),
    );
    // A park and a block.
    canvas
      ..drawRRect(
        RRect.fromLTRBR(4, 4, w * 0.38, h * 0.36, const Radius.circular(4)),
        Paint()..color = const Color(0xFFD6EED9),
      )
      ..drawRRect(
        RRect.fromLTRBR(
          w * 0.62,
          h * 0.6,
          w - 4,
          h - 4,
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFDDE5EE),
      );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(0, h * 0.48), Offset(w, h * 0.42), road)
      ..drawLine(Offset(w * 0.5, 0), Offset(w * 0.46, h), road)
      ..drawLine(
        Offset(w * 0.1, h),
        Offset(w, h * 0.78),
        road..strokeWidth = 3,
      );
    // Pin with a soft halo.
    final pin = Offset(w * 0.5, h * 0.45);
    canvas
      ..drawCircle(
        pin,
        11,
        Paint()..color = AppColors.primary.withValues(alpha: 0.18),
      )
      ..drawCircle(pin, 6, Paint()..color = Colors.white)
      ..drawCircle(pin, 4.2, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) => false;
}

class _OptionsBlock extends StatelessWidget {
  const _OptionsBlock({required this.options});

  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your options',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in options)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        o,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.package,
    required this.packagePrice,
    required this.extras,
    required this.offer,
    required this.discount,
    required this.total,
  });

  final String package;
  final int packagePrice;
  final int extras;
  final Offer? offer;
  final int discount;

  /// After the discount.
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 13, color: _ink)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          line(package, '$packagePrice QAR'),
          if (extras != 0)
            line('Options & add-ons', '${extras > 0 ? '+' : ''}$extras QAR'),
          if (offer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    size: 14,
                    color: Color(0xFF1F9E44),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${offer!.code} · ${offer!.percent}% off',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F9E44),
                      ),
                    ),
                  ),
                  Text(
                    '−$discount QAR',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F9E44),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 10),
            child: _DashedLine(),
          ),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  '${v.round()} QAR',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = (c.maxWidth / 8).floor();
        return Row(
          children: [
            for (var i = 0; i < n; i++)
              Container(
                width: 4,
                height: 1.2,
                margin: const EdgeInsets.only(right: 4),
                color: const Color(0xFFD5DAE0),
              ),
          ],
        );
      },
    );
  }
}

/// Pay online now (wallet or card), or cash to the pro when the job is
/// done. The chosen option unfolds to show its details.
class _Payment extends StatelessWidget {
  const _Payment({
    required this.total,
    required this.method,
    required this.wallet,
    required this.changeFor,
    required this.paying,
    required this.onMethod,
    required this.onWallet,
    required this.onChange,
    required this.onPay,
  });

  final int total;
  final _PayMethod method;
  final _Wallet wallet;
  final int? changeFor;
  final bool paying;
  final ValueChanged<_PayMethod> onMethod;
  final ValueChanged<_Wallet> onWallet;
  final ValueChanged<int?> onChange;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final online = method == _PayMethod.online;
    // Wallet buttons follow the wallet's own black style.
    final walletButton = online && wallet != _Wallet.card;
    return Column(
      key: const ValueKey('payment'),
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
        const _ReservedTag(),
        const SizedBox(height: 10),
        const Text(
          'How would you like to pay?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        _PayOption(
          icon: Icons.bolt_rounded,
          title: 'Pay online',
          subtitle: 'Fast and contactless',
          tag: 'Recommended',
          selected: online,
          onTap: () => onMethod(_PayMethod.online),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _WalletTile(
                      selected:
                          wallet ==
                          (ios ? _Wallet.applePay : _Wallet.googlePay),
                      onTap: () =>
                          onWallet(ios ? _Wallet.applePay : _Wallet.googlePay),
                      child: ios
                          ? const _ApplePayMark()
                          : const _GooglePayMark(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WalletTile(
                      selected: wallet == _Wallet.card,
                      onTap: () => onWallet(_Wallet.card),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card_rounded,
                            size: 18,
                            color: _ink,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Card',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  _VisaMark(),
                  SizedBox(width: 8),
                  _MastercardMark(),
                  SizedBox(width: 8),
                  _NapsMark(),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Debit & credit accepted',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PayOption(
          icon: Icons.payments_outlined,
          title: 'Cash on delivery',
          subtitle: 'Pay the pro when the job is done',
          selected: !online,
          onTap: () => onMethod(_PayMethod.cash),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need change?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ChangeChip(
                    label: 'Exact amount',
                    selected: changeFor == null,
                    onTap: () => onChange(null),
                  ),
                  for (final note in const [100, 200, 500])
                    if (note > total)
                      _ChangeChip(
                        label: '$note QAR',
                        selected: changeFor == note,
                        onTap: () => onChange(note),
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Total', style: TextStyle(fontSize: 15, color: _muted)),
            const Spacer(),
            Text(
              '$total QAR',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: paying ? () {} : onPay,
            style: FilledButton.styleFrom(
              backgroundColor: walletButton ? Colors.black : AppColors.primary,
              shape: const StadiumBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: paying
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: ValueKey((method, wallet)),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (walletButton) ...[
                          wallet == _Wallet.applePay
                              ? const _ApplePayMark(light: true)
                              : const _GooglePayMark(light: true),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            online ? 'Pay $total QAR' : 'Confirm cash payment',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              online ? Icons.lock_outline_rounded : Icons.verified_outlined,
              size: 13,
              color: _muted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                online
                    ? 'Secure, encrypted payment'
                    : 'Nothing to pay until the job is done',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Green "Slot reserved" tag; the check pops in.
class _ReservedTag extends StatelessWidget {
  const _ReservedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Slot reserved',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F9E44),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.child,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Details shown while selected.
  final Widget child;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF5F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFF1F2F4),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFEFF5FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                            ),
                            if (tag != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF5FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Radio(selected: selected),
                ],
              ),
            ),
          ),
          // Details unfold under the header.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selected
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, -6 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: child,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Radio dot whose centre springs in.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE6E8EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE6E8EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }
}

// Payment marks drawn in code (no image assets needed).

class _ApplePayMark extends StatelessWidget {
  const _ApplePayMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Colors.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.apple, size: 19, color: color),
        Text(
          'Pay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GooglePayMark extends StatelessWidget {
  const _GooglePayMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    const g = [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (r) => const SweepGradient(
            colors: [...g, Color(0xFF4285F4)],
          ).createShader(r),
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'Pay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: light ? Colors.white : const Color(0xFF5F6368),
          ),
        ),
      ],
    );
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISA',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.3,
        color: Color(0xFF1A1F71),
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 15,
      child: CustomPaint(painter: _MastercardPainter()),
    );
  }
}

class _MastercardPainter extends CustomPainter {
  const _MastercardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Offset(r, r);
    final right = Offset(size.width - r, r);
    canvas
      ..drawCircle(left, r, Paint()..color = const Color(0xFFEB001B))
      ..drawCircle(right, r, Paint()..color = const Color(0xFFF79E1B));
    // The orange overlap.
    final overlap = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: left, radius: r)),
      Path()..addOval(Rect.fromCircle(center: right, radius: r)),
    );
    canvas.drawPath(overlap, Paint()..color = const Color(0xFFFF5F00));
  }

  @override
  bool shouldRepaint(_MastercardPainter oldDelegate) => false;
}

class _NapsMark extends StatelessWidget {
  const _NapsMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF8A1538),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'NAPS',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({
    required this.summary,
    required this.cash,
    required this.changeFor,
  });

  final BookingSummary summary;

  /// Paying cash on delivery rather than online.
  final bool cash;

  /// Note the pro should bring change for (cash only).
  final int? changeFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('done'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        // Green check that springs in, with a ring spreading out.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, t, _) {
            final pop = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
            final ring = Curves.easeOut.transform(t);
            return SizedBox.square(
              dimension: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 70 + 50 * ring,
                    height: 70 + 50 * ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF34C759,
                      ).withValues(alpha: 0.25 * (1 - ring)),
                    ),
                  ),
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34C759),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Booking confirmed',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${summary.package.name} · ${_date(summary.date)}, ${summary.time}\n'
          '${!cash
              ? 'Paid ${summary.payable} QAR online. '
              : changeFor != null
              ? 'Pay ${summary.payable} QAR in cash, the pro brings change for $changeFor. '
              : 'Pay ${summary.payable} QAR in cash to the pro. '}'
          '${summary.company.name} will message you before arriving.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context)
                ..pop() // the sheet
                ..pop(); // the service screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

String _date(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}
