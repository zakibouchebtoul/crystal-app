import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A kind of service, with the icon and calendar-dot color used for it.
enum ServiceType {
  carWash('Car wash', 'car_wash', Color(0xFF5EFFC9)),
  houseClean('House clean', 'house_clean', Color(0xFF04E6FF)),
  laundry('Laundry care', 'laundry', Color(0xFFCB13F4)),
  carpet('Carpet', 'carpet', Color(0xFFF4DE13)),
  petGrooming('Pet grooming', 'pet_grooming', Color(0xFFFF8A5B)),
  appliance('Appliance', 'appliance', Color(0xFF7B8CFF)),
  glass('Glass cleaning', 'glass_cleaning', Color(0xFF3FA9F5)),
  event('Event clean', 'event_clean', Color(0xFFFF5FA2));

  const ServiceType(this.label, this._image, this.color);

  final String label;
  final String _image;

  /// Dot color under calendar days that have this service.
  final Color color;

  String get image => 'assets/images/home/services/$_image.jpg';

  /// The type for a catalog service id (e.g. "car_wash").
  static ServiceType forServiceId(String id) => ServiceType.values.firstWhere(
    (t) => t._image == id,
    orElse: () => ServiceType.houseClean,
  );
}

class Booking {
  const Booking({
    required this.title,
    required this.type,
    required this.start,
    required this.duration,
    required this.provider,
    required this.price,
    required this.rating,
    required this.reviews,
    this.serviceId,
    this.companyId,
    this.package,
    this.image,
  });

  final String title;

  /// Where it was booked, so it can be booked again: the catalog service,
  /// the company and the package name.
  final String? serviceId;
  final String? companyId;
  final String? package;

  /// Photo for this booking's card; the company's cover otherwise.
  final String? image;
  final ServiceType type;
  final DateTime start;
  final Duration duration;
  final String provider;

  /// Price in QAR.
  final int price;
  final double rating;
  final String reviews;

  DateTime get end => start.add(duration);

  /// The same booking at another time.
  Booking movedTo(DateTime newStart) => Booking(
    title: title,
    type: type,
    start: newStart,
    duration: duration,
    provider: provider,
    price: price,
    rating: rating,
    reviews: reviews,
    serviceId: serviceId,
    companyId: companyId,
    package: package,
    image: image,
  );

  /// Finished once its end time has passed.
  bool isCompleted(DateTime now) => end.isBefore(now);

  /// Can be booked again in one tap.
  bool get rebookable =>
      serviceId != null && companyId != null && package != null;
}

/// Sample bookings around today until the backend provides real ones.
List<Booking> sampleBookings(DateTime now) {
  DateTime at(int dayOffset, int hour) =>
      DateTime(now.year, now.month, now.day + dayOffset, hour);

  return [
    Booking(
      title: 'Full interior deep clean',
      type: ServiceType.carWash,
      start: at(0, 11),
      duration: const Duration(minutes: 60),
      provider: 'Qatar wash',
      price: 79,
      rating: 4.9,
      reviews: '2.1k',
      serviceId: 'car_wash',
      companyId: 'qatar_wash',
      package: 'Full interior deep clean',
    ),
    Booking(
      title: '2BR Apartment Standard Clean',
      type: ServiceType.houseClean,
      start: at(0, 15),
      duration: const Duration(minutes: 120),
      provider: 'Sparkle Homes',
      price: 200,
      rating: 4.8,
      reviews: '1.9k',
      serviceId: 'house_clean',
      companyId: 'sparkle_homes',
      package: 'Standard clean',
    ),
    Booking(
      title: 'Wash & fold — 2 bags',
      type: ServiceType.laundry,
      start: at(0, 18),
      duration: const Duration(minutes: 45),
      provider: 'Fresh Fold',
      price: 60,
      rating: 4.7,
      reviews: '860',
      serviceId: 'laundry',
      companyId: 'fresh_fold',
      package: 'Wash & fold',
    ),
    Booking(
      title: 'Exterior wash & wax',
      type: ServiceType.carWash,
      start: at(-3, 10),
      duration: const Duration(minutes: 60),
      provider: 'Qatar wash',
      price: 95,
      rating: 4.9,
      reviews: '2.1k',
      serviceId: 'car_wash',
      companyId: 'qatar_wash',
      package: 'Exterior wash',
    ),
    Booking(
      title: 'Wash & iron — work shirts',
      type: ServiceType.laundry,
      start: at(-6, 17),
      duration: const Duration(minutes: 30),
      provider: 'Fresh Fold',
      price: 45,
      rating: 4.7,
      reviews: '860',
      serviceId: 'laundry',
      companyId: 'fresh_fold',
      package: 'Wash & iron',
    ),
    Booking(
      title: 'Bath & brush',
      type: ServiceType.petGrooming,
      start: at(-12, 10),
      duration: const Duration(minutes: 60),
      provider: 'Happy Paws',
      price: 90,
      rating: 4.8,
      reviews: '1.2k',
      serviceId: 'pet_grooming',
      companyId: 'happy_paws',
      package: 'Bath & brush',
    ),
    Booking(
      title: 'Living room deep clean',
      type: ServiceType.houseClean,
      start: at(10, 9),
      duration: const Duration(minutes: 90),
      provider: 'Sparkle Homes',
      price: 150,
      rating: 4.8,
      reviews: '1.9k',
      serviceId: 'house_clean',
      companyId: 'sparkle_homes',
      package: 'Deep clean',
      image: 'assets/images/services/booking_living_room_deep_clean.jpg',
    ),
    Booking(
      title: 'Majlis carpet shampoo',
      type: ServiceType.carpet,
      start: at(10, 14),
      duration: const Duration(minutes: 120),
      provider: 'Carpet Care QA',
      price: 180,
      rating: 4.6,
      reviews: '540',
      serviceId: 'carpet',
      companyId: 'carpet_care',
      package: 'At-home shampoo',
    ),
    Booking(
      title: 'Persian rug cleaning',
      type: ServiceType.carpet,
      start: at(25, 16),
      duration: const Duration(minutes: 90),
      provider: 'Carpet Care QA',
      price: 220,
      rating: 4.6,
      reviews: '540',
      serviceId: 'carpet',
      companyId: 'carpet_care',
      package: 'Pick-up & factory wash',
      image: 'assets/images/services/booking_persian_rug.jpg',
    ),
  ];
}

/// All bookings, shared by the home tab, the calendar and the booking
/// flow. Starts with the samples; new bookings are added on confirm.
class BookingStore extends ChangeNotifier {
  BookingStore() : _all = sampleBookings(DateTime.now());

  final List<Booking> _all;

  List<Booking> get all => List.unmodifiable(_all);

  /// Asks everything showing bookings to redraw (pull to refresh).
  /// TODO: fetch from the backend here.
  void refresh() => notifyListeners();

  void add(Booking booking) {
    _all.add(booking);
    notifyListeners();
  }

  /// Moves [booking] to [start]; returns the updated booking.
  Booking reschedule(Booking booking, DateTime start) {
    final moved = booking.movedTo(start);
    final i = _all.indexOf(booking);
    if (i >= 0) _all[i] = moved;
    notifyListeners();
    return moved;
  }

  void cancel(Booking booking) {
    _all.remove(booking);
    _rated.remove(booking);
    notifyListeners();
  }

  /// Stars given to finished bookings.
  final Map<Booking, int> _rated = {};

  int? ratingOf(Booking booking) => _rated[booking];

  void rate(Booking booking, int stars) {
    _rated[booking] = stars;
    notifyListeners();
  }

  /// The most recent finished booking not rated yet (for the home card).
  Booking? toRate(DateTime now) {
    final done = _all.where((b) => b.isCompleted(now)).toList()
      ..sort((a, b) => b.end.compareTo(a.end));
    for (final b in done) {
      if (!_rated.containsKey(b)) return b;
    }
    return null;
  }

  /// Bookings that haven't finished yet (one in progress counts),
  /// soonest first.
  List<Booking> upcoming(DateTime now) =>
      _all.where((b) => !b.isCompleted(now)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// The next booking that hasn't finished yet.
  Booking? nextUpcoming(DateTime now) {
    final open = upcoming(now);
    return open.isEmpty ? null : open.first;
  }

  /// Finished bookings that can be repeated, newest first, one per
  /// company and package.
  List<Booking> bookAgain(DateTime now) {
    final done = _all.where((b) => b.isCompleted(now) && b.rebookable).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final seen = <String>{};
    return [
      for (final b in done)
        if (seen.add('${b.companyId}/${b.package}')) b,
    ];
  }
}

final bookingStore = BookingStore();
