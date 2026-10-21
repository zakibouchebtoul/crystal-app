/// Content shown on the home tab. Static for now; replace with data from
/// the backend when it's available.
library;

class PromoBanner {
  const PromoBanner({required this.image, this.offerId});

  final String image;

  /// The offer it opens (see offers.dart).
  final String? offerId;
}

class ServiceCategory {
  const ServiceCategory({required this.name, required this.image, this.badge});

  final String name;
  final String image;

  /// Optional red tag on the tile, e.g. "School Offers".
  final String? badge;
}

class FeaturedService {
  const FeaturedService({
    required this.title,
    required this.rating,
    required this.reviews,
    this.image,
    this.duration,
    this.priceFrom,
    this.badge,
    this.category,
    this.package,
  });

  final String title;

  /// Where tapping leads: the [serviceCatalog] entry and the package in it.
  final String? category;
  final String? package;

  /// Photo; a placeholder is shown when null.
  final String? image;
  final double rating;

  /// Review count label, e.g. "2.1k".
  final String reviews;

  /// Duration label on the photo, e.g. "60 mins" or "1 hour".
  final String? duration;

  /// Starting price in QAR.
  final int? priceFrom;

  /// Optional red tag, e.g. "Most booked".
  final String? badge;
}

const promoBanners = [
  PromoBanner(image: 'assets/images/home/banner_pets.jpg', offerId: 'pets'),
  PromoBanner(image: 'assets/images/home/banner_school.jpg', offerId: 'school'),
  PromoBanner(
    image: 'assets/images/home/banner_carwash.jpg',
    offerId: 'carwash',
  ),
  PromoBanner(image: 'assets/images/home/banner_glass.jpg', offerId: 'glass'),
];

const _services = 'assets/images/home/services';

const serviceCategories = [
  ServiceCategory(name: 'Car wash', image: '$_services/car_wash.jpg'),
  ServiceCategory(name: 'House clean', image: '$_services/house_clean.jpg'),
  ServiceCategory(name: 'Carpet', image: '$_services/carpet.jpg'),
  ServiceCategory(
    name: 'Laundry care',
    image: '$_services/laundry.jpg',
    badge: 'School Offers',
  ),
  ServiceCategory(name: 'Pet grooming', image: '$_services/pet_grooming.jpg'),
  ServiceCategory(name: 'Appliance', image: '$_services/appliance.jpg'),
  ServiceCategory(
    name: 'Glass cleaning',
    image: '$_services/glass_cleaning.jpg',
  ),
  ServiceCategory(name: 'Event clean', image: '$_services/event_clean.jpg'),
];

const mostBookedServices = [
  FeaturedService(
    title: 'Full interior deep clean',
    image: 'assets/images/home/featured_interior.jpg',
    rating: 4.9,
    reviews: '2.1k',
    duration: '60 mins',
    priceFrom: 79,
    badge: 'Most booked',
    category: 'Car wash',
    package: 'Full interior deep clean',
  ),
  FeaturedService(
    title: '2BR Apartment Clean',
    image: 'assets/images/home/featured_apartment.jpg',
    rating: 4.8,
    reviews: '1.9k',
    duration: '1 hour',
    priceFrom: 200,
    category: 'House clean',
    package: 'Standard clean',
  ),
];
