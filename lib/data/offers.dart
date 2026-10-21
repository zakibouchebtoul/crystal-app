import 'package:flutter/foundation.dart';

/// A promotion: its banner, what it gives and on which service.
class Offer {
  const Offer({
    required this.id,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.percent,
    required this.serviceId,
    required this.validDays,
    required this.terms,
  });

  final String id;

  /// Banner image (also shown in the home carousel).
  final String image;
  final String title;
  final String subtitle;

  /// Promo code shown to the customer.
  final String code;

  /// Discount in percent, applied to the booking total.
  final int percent;

  /// Catalog service it applies to.
  final String serviceId;

  /// Days left from today (sample until the backend sends real dates).
  final int validDays;
  final List<String> terms;
}

/// Sample offers until the backend provides them.
const offers = [
  Offer(
    id: 'pets',
    image: 'assets/images/home/banner_pets.jpg',
    title: 'First groom 20% off',
    subtitle: 'Bath, trim and styling for your pet, at your door',
    code: 'FIRSTGROOM',
    percent: 20,
    serviceId: 'pet_grooming',
    validDays: 12,
    terms: ['First pet grooming booking only', 'All pet grooming packages'],
  ),
  Offer(
    id: 'school',
    image: 'assets/images/home/banner_school.jpg',
    title: 'Back to school 15% off',
    subtitle: 'Spotless uniforms: wash, press and fold',
    code: 'SCHOOL15',
    percent: 15,
    serviceId: 'laundry',
    validDays: 20,
    terms: ['All laundry packages', 'One use per account'],
  ),
  Offer(
    id: 'carwash',
    image: 'assets/images/home/banner_carwash.jpg',
    title: 'Shine on every drive, 10% off',
    subtitle: 'Exterior, interior and polish, washed at your door',
    code: 'SHINE10',
    percent: 10,
    serviceId: 'car_wash',
    validDays: 7,
    terms: ['All car wash packages', 'Can be used every week'],
  ),
  Offer(
    id: 'glass',
    image: 'assets/images/home/banner_glass.jpg',
    title: 'After the dust, 15% off',
    subtitle: 'Windows, facades and balconies, crystal clear',
    code: 'CLEARDAY',
    percent: 15,
    serviceId: 'glass_cleaning',
    validDays: 5,
    terms: ['All glass cleaning packages', 'Book on a clear day'],
  ),
  Offer(
    id: 'bundle',
    image: 'assets/images/home/banner_3in1.jpg',
    title: 'House clean 25% off',
    subtitle: 'Clean spaces, better places',
    code: 'CLEAN25',
    percent: 25,
    serviceId: 'house_clean',
    validDays: 14,
    terms: ['All house cleaning packages', 'One use per account'],
  ),
];

Offer? offerById(String id) {
  for (final o in offers) {
    if (o.id == id) return o;
  }
  return null;
}

/// The offer the customer chose to use; applied in the booking sheet when
/// it matches the service being booked, then cleared.
final appliedOffer = ValueNotifier<Offer?>(null);
