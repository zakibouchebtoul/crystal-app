/// Content for each service's detail screen. Sample data until the backend
/// provides real packages, prices and providers.
///
/// Images live in `assets/images/services/`; until a file is added, the
/// screen shows a placeholder naming the file to upload.
library;

const _img = 'assets/images/services';

class ServicePackage {
  const ServicePackage({
    required this.name,
    required this.minutes,
    required this.price,
    required this.includes,
    this.mostBooked = false,
  });

  final String name;
  final int minutes;

  /// Price in QAR.
  final int price;
  final List<String> includes;
  final bool mostBooked;
}

sealed class OptionGroup {
  const OptionGroup(this.title);
  final String title;
}

/// Pick one; each choice may add to the price.
class ChoiceGroup extends OptionGroup {
  const ChoiceGroup(super.title, this.choices);
  final List<(String label, int extra)> choices;
}

/// A count, e.g. rooms; each unit above [included] adds [pricePerExtra].
class CounterGroup extends OptionGroup {
  const CounterGroup(
    super.title, {
    required this.unit,
    this.min = 1,
    this.max = 10,
    this.initial = 1,
    this.included = 1,
    this.pricePerExtra = 0,
  });
  final String unit;
  final int min;
  final int max;
  final int initial;
  final int included;
  final int pricePerExtra;
}

/// Optional extras, any number.
class AddOnGroup extends OptionGroup {
  const AddOnGroup(super.title, this.addOns);
  final List<(String label, int price)> addOns;
}

/// A company offering one or more services.
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.area,
    this.tags = const [],
    this.verified = true,
  });

  final String id;
  final String name;
  final double rating;

  /// e.g. "2.1k".
  final String reviewCount;

  /// e.g. "2.4 km".
  final String distance;
  final String area;
  final List<String> tags;
  final bool verified;

  String get logo => '$_img/company_${id}_logo.jpg';
  String get cover => '$_img/company_${id}_cover.jpg';

  /// For sorting by distance.
  double get km => double.tryParse(distance.split(' ').first) ?? 99;
}

/// What a company offers in one category: the category's services at its
/// own prices ([priceFactor]), minus any it doesn't do ([skip]).
class CompanyOffer {
  const CompanyOffer(
    this.company, {
    required this.base,
    this.priceFactor = 1,
    this.skip = const [],
    this.reviews = const [],
  });

  final Company company;
  final List<ServicePackage> base;
  final double priceFactor;
  final List<int> skip;
  final List<ServiceReview> reviews;

  List<ServicePackage> get packages => [
    for (final (i, p) in base.indexed)
      if (!skip.contains(i))
        ServicePackage(
          name: p.name,
          minutes: p.minutes,
          price: (p.price * priceFactor).round(),
          includes: p.includes,
          mostBooked: p.mostBooked,
        ),
  ];

  int get priceFrom =>
      packages.map((p) => p.price).reduce((a, b) => a < b ? a : b);
}

class ServiceReview {
  const ServiceReview(
    this.name,
    this.rating,
    this.text,
    this.when, {
    this.likes = 0,
  });
  final String name;
  final double rating;
  final String text;
  final String when;

  /// People who found it helpful.
  final int likes;
}

class ServiceDetail {
  const ServiceDetail({
    required this.id,
    required this.title,
    required this.tileImage,
    required this.promise,
    required this.rating,
    required this.bookings,
    required this.packages,
    required this.options,
    required this.companies,
    required this.faqs,
    this.weatherSensitive = false,
  });

  final String id;
  final String title;

  /// The 3D icon from the home grid.
  final String tileImage;
  final String promise;
  final double rating;
  final String bookings;
  final bool weatherSensitive;
  final List<ServicePackage> packages;
  final List<OptionGroup> options;

  /// Companies offering this service, each with its own prices.
  final List<CompanyOffer> companies;
  final List<(String question, String answer)> faqs;

  /// Photo behind the companies list header.
  String get headerImage => '$_img/${id}_header.jpg';
  String get beforeImage => '$_img/${id}_before.jpg';
  String get afterImage => '$_img/${id}_after.jpg';
}

Company _c(
  String id,
  String name,
  double rating,
  String reviews,
  String km,
  String area,
  List<String> tags,
) => Company(
  id: id,
  name: name,
  rating: rating,
  reviewCount: reviews,
  distance: km,
  area: area,
  tags: tags,
);

final _qatarWash = _c(
  'qatar_wash',
  'Qatar wash',
  4.9,
  '2.1k',
  '2.4 km',
  'West Bay',
  ['At your door', 'Waterless'],
);
final _shineAuto = _c(
  'shine_auto',
  'Shine Auto Spa',
  4.7,
  '980',
  '4.1 km',
  'Al Sadd',
  ['Premium wax', 'Ceramic coating'],
);
final _dohaCarCare = _c(
  'doha_car_care',
  'Doha Car Care',
  4.5,
  '640',
  '1.8 km',
  'Bin Mahmoud',
  ['Budget friendly'],
);
final _sparkle = _c(
  'sparkle_homes',
  'Sparkle Homes',
  4.8,
  '1.9k',
  '3.0 km',
  'The Pearl',
  ['Supplies included', 'Female staff'],
);
final _maidPro = _c(
  'maid_pro',
  'Maid Pro QA',
  4.6,
  '1.2k',
  '5.2 km',
  'Al Waab',
  ['Same-day'],
);
final _freshNest = _c(
  'fresh_nest',
  'Fresh Nest',
  4.7,
  '730',
  '2.2 km',
  'Lusail',
  ['Eco products'],
);
final _carpetCare = _c(
  'carpet_care',
  'Carpet Care QA',
  4.6,
  '540',
  '6.0 km',
  'Industrial Area',
  ['Pick-up available'],
);
final _majlisMasters = _c(
  'majlis_masters',
  'Majlis Masters',
  4.8,
  '410',
  '3.6 km',
  'Al Gharrafa',
  ['Majlis specialists'],
);
final _freshFold = _c(
  'fresh_fold',
  'Fresh Fold',
  4.7,
  '860',
  '1.5 km',
  'Msheireb',
  ['Next-day return'],
);
final _pressGo = _c(
  'press_go',
  'Press & Go',
  4.5,
  '520',
  '2.9 km',
  'Al Muntazah',
  ['Express 6h'],
);
final _happyPaws = _c(
  'happy_paws',
  'Happy Paws',
  4.8,
  '1.2k',
  '3.3 km',
  'West Bay',
  ['Mobile van', 'Cat friendly'],
);
final _pawsBubbles = _c(
  'paws_bubbles',
  'Paws & Bubbles',
  4.6,
  '390',
  '5.5 km',
  'Al Rayyan',
  ['Organic shampoo'],
);
final _clearView = _c(
  'clear_view',
  'Clear View',
  4.7,
  '930',
  '2.7 km',
  'Lusail',
  ['High-rise certified'],
);
final _skylineGlass = _c(
  'skyline_glass',
  'Skyline Glass',
  4.9,
  '350',
  '4.8 km',
  'West Bay',
  ['Facades', 'Rope access'],
);

const _generalFaqs = [
  (
    'Do I need to be home?',
    'Only to let the team in. For car wash and window cleaning you can '
        'leave access instructions instead.',
  ),
  (
    'When do I pay?',
    'After the service is done — by card or cash. You will get a receipt '
        'in the app.',
  ),
  (
    'Can I reschedule?',
    'Yes, for free up to 2 hours before the booking from the Calendar.',
  ),
];

const _carWashPackages = [
  ServicePackage(
    name: 'Exterior wash',
    minutes: 45,
    price: 49,
    includes: ['Hand wash & dry', 'Rims & tyres', 'Windows outside'],
  ),
  ServicePackage(
    name: 'Full interior deep clean',
    minutes: 60,
    price: 79,
    includes: [
      'Vacuum & seat shampoo',
      'Dashboard & panels',
      'Windows inside',
      'Air freshener',
    ],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Full detail',
    minutes: 120,
    price: 149,
    includes: [
      'Everything in exterior + interior',
      'Clay bar & wax',
      'Engine bay wipe',
    ],
  ),
];

const _houseCleanPackages = [
  ServicePackage(
    name: 'Standard clean',
    minutes: 120,
    price: 120,
    includes: ['Dusting & mopping', 'Kitchen surfaces', 'Bathrooms'],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Deep clean',
    minutes: 240,
    price: 260,
    includes: [
      'Everything in standard',
      'Inside cupboards & oven',
      'Behind furniture',
      'Windows inside',
    ],
  ),
  ServicePackage(
    name: 'Move in / move out',
    minutes: 360,
    price: 420,
    includes: ['Full deep clean', 'Walls & skirting', 'Balcony'],
  ),
];

const _carpetPackages = [
  ServicePackage(
    name: 'At-home shampoo',
    minutes: 120,
    price: 59,
    includes: ['Vacuum', 'Shampoo & extraction', 'Quick-dry'],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Pick-up & factory wash',
    minutes: 30,
    price: 99,
    includes: ['Pick-up and delivery', 'Machine wash', 'Ready in 3 days'],
  ),
];

const _laundryPackages = [
  ServicePackage(
    name: 'Wash & fold',
    minutes: 30,
    price: 30,
    includes: ['Per bag (up to 6 kg)', 'Folded & packed'],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Wash & iron',
    minutes: 30,
    price: 45,
    includes: ['Per bag', 'Ironed on hangers'],
  ),
  ServicePackage(
    name: 'School uniforms',
    minutes: 30,
    price: 25,
    includes: ['Per 5 items', 'Washed & pressed', 'School Offers price'],
  ),
];

const _petGroomingPackages = [
  ServicePackage(
    name: 'Bath & brush',
    minutes: 60,
    price: 90,
    includes: ['Shampoo & dry', 'Brushing', 'Ear cleaning'],
  ),
  ServicePackage(
    name: 'Full groom',
    minutes: 90,
    price: 150,
    includes: ['Bath & brush', 'Haircut & styling', 'Nail trim'],
    mostBooked: true,
  ),
];

const _appliancePackages = [
  ServicePackage(
    name: 'Oven & hob',
    minutes: 90,
    price: 99,
    includes: ['Degreasing', 'Racks & trays', 'Glass door'],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Fridge',
    minutes: 60,
    price: 79,
    includes: ['Shelves & drawers', 'Seals', 'Odour removal'],
  ),
  ServicePackage(
    name: 'AC unit',
    minutes: 60,
    price: 89,
    includes: ['Filter wash', 'Coil cleaning', 'Drain check'],
  ),
];

const _glassCleaningPackages = [
  ServicePackage(
    name: 'Windows inside',
    minutes: 60,
    price: 69,
    includes: ['Glass & frames', 'Tracks & sills'],
  ),
  ServicePackage(
    name: 'Inside & outside',
    minutes: 120,
    price: 129,
    includes: ['Both sides', 'Balcony glass', 'Mirrors'],
    mostBooked: true,
  ),
];

const _eventCleanPackages = [
  ServicePackage(
    name: 'Post-party clean',
    minutes: 180,
    price: 350,
    includes: ['Rubbish removal', 'Floors & surfaces', 'Kitchen reset'],
    mostBooked: true,
  ),
  ServicePackage(
    name: 'Pre-event prep',
    minutes: 180,
    price: 300,
    includes: ['Deep clean of hosting areas', 'Majlis setup help'],
  ),
];

final serviceCatalog = <String, ServiceDetail>{
  'Car wash': ServiceDetail(
    id: 'car_wash',
    title: 'Car wash',
    tileImage: 'assets/images/home/services/car_wash.jpg',
    promise: 'At your door, no water hose needed',
    rating: 4.9,
    bookings: '3.2k bookings',
    weatherSensitive: true,
    packages: _carWashPackages,
    options: [
      ChoiceGroup('Car size', [('Sedan', 0), ('SUV', 15), ('7-seater', 25)]),
      AddOnGroup('Add-ons', [
        ('Hand wax', 30),
        ('Headlight restore', 40),
        ('Pet hair removal', 20),
      ]),
    ],
    companies: [
      CompanyOffer(
        _qatarWash,
        base: _carWashPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Mariam A.',
            5,
            'Came on time and the seats look brand new.',
            '2 days ago',
            likes: 24,
          ),
          ServiceReview(
            'Yousef K.',
            4.5,
            'Great job on the interior, will book again.',
            '1 week ago',
            likes: 9,
          ),
        ],
      ),
      CompanyOffer(
        _shineAuto,
        base: _carWashPackages,
        priceFactor: 1.15,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Faisal N.',
            4.5,
            'The wax finish is excellent.',
            '3 days ago',
          ),
        ],
      ),
      CompanyOffer(
        _dohaCarCare,
        base: _carWashPackages,
        priceFactor: 0.85,
        skip: const [2],
        reviews: const [
          ServiceReview(
            'Ali R.',
            4,
            'Good value for a quick wash.',
            '1 week ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'House clean': ServiceDetail(
    id: 'house_clean',
    title: 'House clean',
    tileImage: 'assets/images/home/services/house_clean.jpg',
    promise: 'Trained, verified cleaners — supplies included',
    rating: 4.8,
    bookings: '5.4k bookings',
    packages: _houseCleanPackages,
    options: [
      CounterGroup(
        'Bedrooms',
        unit: 'room',
        initial: 2,
        included: 2,
        pricePerExtra: 35,
      ),
      CounterGroup(
        'Bathrooms',
        unit: 'bath',
        initial: 1,
        included: 1,
        pricePerExtra: 25,
      ),
      ChoiceGroup('Cleaning supplies', [
        ('We bring them', 0),
        ('I have them', -10),
      ]),
    ],
    companies: [
      CompanyOffer(
        _sparkle,
        base: _houseCleanPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Sara M.',
            5,
            'Spotless! They even folded the towels.',
            '3 days ago',
          ),
          ServiceReview(
            'Omar H.',
            4.5,
            'Very professional team of two.',
            '2 weeks ago',
          ),
        ],
      ),
      CompanyOffer(
        _maidPro,
        base: _houseCleanPackages,
        priceFactor: 0.92,
        skip: const [2],
        reviews: const [
          ServiceReview(
            'Huda S.',
            4.5,
            'Came the same day I booked.',
            '4 days ago',
          ),
        ],
      ),
      CompanyOffer(
        _freshNest,
        base: _houseCleanPackages,
        priceFactor: 1.08,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Jana K.',
            5,
            'Love that they use eco products.',
            '2 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Carpet': ServiceDetail(
    id: 'carpet',
    title: 'Carpet cleaning',
    tileImage: 'assets/images/home/services/carpet.jpg',
    promise: 'Deep shampoo for rugs and majlis carpets',
    rating: 4.6,
    bookings: '1.1k bookings',
    packages: _carpetPackages,
    options: [
      CounterGroup(
        'Number of carpets',
        unit: 'carpet',
        initial: 1,
        included: 1,
        pricePerExtra: 40,
      ),
      ChoiceGroup('Size', [
        ('Small', 0),
        ('Medium', 20),
        ('Large / majlis', 45),
      ]),
    ],
    companies: [
      CompanyOffer(
        _carpetCare,
        base: _carpetPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Hessa R.',
            4.5,
            'Our majlis carpet looks new again.',
            '5 days ago',
          ),
        ],
      ),
      CompanyOffer(
        _majlisMasters,
        base: _carpetPackages,
        priceFactor: 1.2,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Saad M.',
            5,
            'Best majlis carpet cleaning in Doha.',
            '1 week ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Laundry care': ServiceDetail(
    id: 'laundry',
    title: 'Laundry care',
    tileImage: 'assets/images/home/services/laundry.jpg',
    promise: 'Pick-up today, back fresh tomorrow',
    rating: 4.7,
    bookings: '2.6k bookings',
    packages: _laundryPackages,
    options: [
      CounterGroup(
        'Bags',
        unit: 'bag',
        initial: 1,
        included: 1,
        pricePerExtra: 30,
      ),
      AddOnGroup('Extras', [
        ('Express (same day)', 20),
        ('Fabric softener', 5),
      ]),
    ],
    companies: [
      CompanyOffer(
        _freshFold,
        base: _laundryPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Noor S.',
            5,
            'Uniforms came back perfectly pressed.',
            '1 day ago',
          ),
        ],
      ),
      CompanyOffer(
        _pressGo,
        base: _laundryPackages,
        priceFactor: 0.9,
        skip: const [2],
        reviews: const [
          ServiceReview(
            'Rana D.',
            4.5,
            'Express service saved my week.',
            '5 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Pet grooming': ServiceDetail(
    id: 'pet_grooming',
    title: 'Pet grooming',
    tileImage: 'assets/images/home/services/pet_grooming.jpg',
    promise: 'Gentle groomers who come to you',
    rating: 4.8,
    bookings: '1.4k bookings',
    packages: _petGroomingPackages,
    options: [
      ChoiceGroup('Pet', [('Dog', 0), ('Cat', 0)]),
      ChoiceGroup('Size', [('Small', 0), ('Medium', 20), ('Large', 40)]),
      AddOnGroup('Extras', [('Teeth cleaning', 25), ('Flea treatment', 35)]),
    ],
    companies: [
      CompanyOffer(
        _happyPaws,
        base: _petGroomingPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Lina F.',
            5,
            'Our golden retriever loved the groomer!',
            '4 days ago',
          ),
        ],
      ),
      CompanyOffer(
        _pawsBubbles,
        base: _petGroomingPackages,
        priceFactor: 1.1,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Dana L.',
            4.5,
            'Gentle with our nervous cat.',
            '6 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Appliance': ServiceDetail(
    id: 'appliance',
    title: 'Appliance cleaning',
    tileImage: 'assets/images/home/services/appliance.jpg',
    promise: 'Ovens, fridges and ACs cleaned like new',
    rating: 4.8,
    bookings: '980 bookings',
    packages: _appliancePackages,
    options: [
      CounterGroup(
        'Units',
        unit: 'unit',
        initial: 1,
        included: 1,
        pricePerExtra: 60,
      ),
    ],
    companies: [
      CompanyOffer(
        _sparkle,
        base: _appliancePackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Khalid B.',
            4.5,
            'Oven was black — now it shines.',
            '1 week ago',
          ),
        ],
      ),
      CompanyOffer(
        _freshNest,
        base: _appliancePackages,
        priceFactor: 0.95,
        skip: const [2],
        reviews: const [
          ServiceReview(
            'Jana K.',
            5,
            'Love that they use eco products.',
            '2 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Glass cleaning': ServiceDetail(
    id: 'glass_cleaning',
    title: 'Glass cleaning',
    tileImage: 'assets/images/home/services/glass_cleaning.jpg',
    promise: 'Streak-free windows, balconies and facades',
    rating: 4.7,
    bookings: '1.3k bookings',
    weatherSensitive: true,
    packages: _glassCleaningPackages,
    options: [
      CounterGroup(
        'Windows',
        unit: 'window',
        initial: 4,
        included: 4,
        pricePerExtra: 10,
      ),
      AddOnGroup('Extras', [('Balcony floor', 30), ('Mesh screens', 15)]),
    ],
    companies: [
      CompanyOffer(
        _clearView,
        base: _glassCleaningPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Abdulla M.',
            5,
            'Booked on a clear day like the app said — perfect.',
            '6 days ago',
          ),
        ],
      ),
      CompanyOffer(
        _skylineGlass,
        base: _glassCleaningPackages,
        priceFactor: 1.2,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Majed A.',
            5,
            'Our tower windows have never been this clear.',
            '3 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
  'Event clean': ServiceDetail(
    id: 'event_clean',
    title: 'Event clean',
    tileImage: 'assets/images/home/services/event_clean.jpg',
    promise: 'Before and after parties, weddings and gatherings',
    rating: 4.8,
    bookings: '640 bookings',
    packages: _eventCleanPackages,
    options: [
      ChoiceGroup('Guests', [('Up to 30', 0), ('30–80', 120), ('80+', 250)]),
      CounterGroup(
        'Cleaners',
        unit: 'cleaner',
        initial: 2,
        min: 2,
        included: 2,
        pricePerExtra: 80,
      ),
    ],
    companies: [
      CompanyOffer(
        _sparkle,
        base: _eventCleanPackages,
        priceFactor: 1.0,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Reem T.',
            5,
            'House was spotless the morning after our wedding.',
            '2 weeks ago',
          ),
        ],
      ),
      CompanyOffer(
        _maidPro,
        base: _eventCleanPackages,
        priceFactor: 0.9,
        skip: const [],
        reviews: const [
          ServiceReview(
            'Huda S.',
            4.5,
            'Came the same day I booked.',
            '4 days ago',
          ),
        ],
      ),
    ],
    faqs: _generalFaqs,
  ),
};

/// The service with this [ServiceDetail.id], if any.
ServiceDetail? serviceById(String id) {
  for (final s in serviceCatalog.values) {
    if (s.id == id) return s;
  }
  return null;
}

/// [package] as [offer] sells it (at its price), or null if it doesn't.
ServicePackage? packageIn(CompanyOffer offer, String package) {
  for (final p in offer.packages) {
    if (p.name == package) return p;
  }
  return null;
}

/// Companies in [service] that offer [package], best rated first.
List<CompanyOffer> offersWithPackage(ServiceDetail service, String package) => [
  for (final o in service.companies)
    if (packageIn(o, package) != null) o,
]..sort((a, b) => b.company.rating.compareTo(a.company.rating));

/// Cheapest price for [package] across companies, or null if none sells it.
int? lowestPrice(ServiceDetail service, String package) {
  int? best;
  for (final o in service.companies) {
    final p = packageIn(o, package);
    if (p != null && (best == null || p.price < best)) best = p.price;
  }
  return best;
}

/// The company with this [Company.id], if any.
Company? companyById(String id) {
  for (final s in serviceCatalog.values) {
    for (final o in s.companies) {
      if (o.company.id == id) return o.company;
    }
  }
  return null;
}
