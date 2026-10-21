/// Messages and a scripted assistant for the AI Concierge.
///
/// [ConciergeEngine] is a stand-in that answers from a few keyword scripts
/// with sample weather; replace it with the real AI + weather backend.
library;

sealed class ConciergeMessage {
  const ConciergeMessage();
}

class UserMessage extends ConciergeMessage {
  const UserMessage(this.text);
  final String text;
}

/// Assistant text, optionally starting with a bold lead ("I'd wait.").
class AssistantText extends ConciergeMessage {
  const AssistantText(this.text, {this.lead});
  final String? lead;
  final String text;
}

enum WeatherKind { sand, dustSun, sunny }

class WeatherDay {
  const WeatherDay(
    this.label,
    this.kind,
    this.temperature, {
    this.best = false,
  });
  final String label;
  final WeatherKind kind;
  final int temperature;

  /// Highlighted as the best day.
  final bool best;
}

class WeatherReport extends ConciergeMessage {
  const WeatherReport({
    required this.title,
    required this.alert,
    required this.days,
  });
  final String title;
  final String alert;
  final List<WeatherDay> days;
}

class ServiceOffer {
  const ServiceOffer({
    required this.title,
    required this.category,
    required this.minutes,
    required this.image,
    required this.provider,
    required this.price,
    required this.rating,
    required this.reviews,
  });
  final String title;
  final String category;
  final int minutes;
  final String image;
  final String provider;

  /// Price in QAR.
  final int price;
  final double rating;
  final String reviews;
}

class ServiceOffers extends ConciergeMessage {
  const ServiceOffers(this.offers);
  final List<ServiceOffer> offers;
}

const _img = 'assets/images/home/services';

const _carWash = [
  ServiceOffer(
    title: 'Full interior deep clean',
    category: 'Car wash',
    minutes: 60,
    image: '$_img/car_wash.jpg',
    provider: 'Qatar wash',
    price: 79,
    rating: 4.9,
    reviews: '2.1k',
  ),
  ServiceOffer(
    title: 'Exterior wash & wax',
    category: 'Car wash',
    minutes: 45,
    image: '$_img/car_wash.jpg',
    provider: 'Qatar wash',
    price: 95,
    rating: 4.9,
    reviews: '2.1k',
  ),
];

const _carpet = ServiceOffer(
  title: 'Majlis carpet shampoo',
  category: 'Carpet',
  minutes: 120,
  image: '$_img/carpet.jpg',
  provider: 'Carpet Care QA',
  price: 180,
  rating: 4.6,
  reviews: '540',
);

const _byKeyword = <String, ServiceOffer>{
  'pet': ServiceOffer(
    title: 'Full groom & bath',
    category: 'Pet grooming',
    minutes: 90,
    image: '$_img/pet_grooming.jpg',
    provider: 'Happy Paws',
    price: 150,
    rating: 4.8,
    reviews: '1.2k',
  ),
  'glass': ServiceOffer(
    title: 'Windows & glass clean',
    category: 'Glass cleaning',
    minutes: 90,
    image: '$_img/glass_cleaning.jpg',
    provider: 'Clear View',
    price: 120,
    rating: 4.7,
    reviews: '930',
  ),
  'event': ServiceOffer(
    title: 'After-party clean up',
    category: 'Event clean',
    minutes: 180,
    image: '$_img/event_clean.jpg',
    provider: 'Sparkle Homes',
    price: 350,
    rating: 4.8,
    reviews: '1.9k',
  ),
  'deep': ServiceOffer(
    title: '2BR Apartment deep clean',
    category: 'House clean',
    minutes: 180,
    image: '$_img/house_clean.jpg',
    provider: 'Sparkle Homes',
    price: 260,
    rating: 4.8,
    reviews: '1.9k',
  ),
  'laundry': ServiceOffer(
    title: 'Wash & fold — 2 bags',
    category: 'Laundry care',
    minutes: 45,
    image: '$_img/laundry.jpg',
    provider: 'Fresh Fold',
    price: 60,
    rating: 4.7,
    reviews: '860',
  ),
  'appliance': ServiceOffer(
    title: 'Oven & fridge deep clean',
    category: 'Appliance',
    minutes: 90,
    image: '$_img/appliance.jpg',
    provider: 'Sparkle Homes',
    price: 140,
    rating: 4.8,
    reviews: '1.9k',
  ),
};

/// Sample forecast until a weather service is connected.
const _dohaForecast = WeatherReport(
  title: 'DOHA · NEXT 3 DAYS',
  alert: '80% sand today',
  days: [
    WeatherDay('Today', WeatherKind.sand, 18),
    WeatherDay('Wed', WeatherKind.dustSun, 20),
    WeatherDay('Thu', WeatherKind.sunny, 26, best: true),
  ],
);

class ConciergeEngine {
  const ConciergeEngine();

  /// Scripted reply to [text].
  List<ConciergeMessage> replyTo(String text) {
    final q = text.toLowerCase();
    bool has(String word) => q.contains(word);

    if (has('skip') || (has('thursday') && has('carpet'))) {
      return const [
        AssistantText(
          'Your car wash is moved to Thursday morning, and a carpet team '
          'can come today at 2pm.',
          lead: 'Done.',
        ),
        ServiceOffers([_carpet]),
      ];
    }
    if (has('car') || has('wash')) {
      return const [
        _dohaForecast,
        AssistantText(
          'Heavy dust / sand blowing in from 4pm — the wash won\'t hold. '
          'Thursday is clear and sunny, best day this week. I can hold a '
          'Thursday slot and use today for indoor work instead.',
          lead: 'I\'d wait.',
        ),
        ServiceOffers(_carWash),
      ];
    }
    if (has('weather')) {
      return const [
        _dohaForecast,
        AssistantText(
          'Sandy today and a bit dusty tomorrow. Thursday is the clear day '
          '— best for anything outdoors.',
        ),
      ];
    }
    if (has('carpet')) {
      return const [
        AssistantText('A carpet team is available today at 2pm.'),
        ServiceOffers([_carpet]),
      ];
    }
    for (final entry in _byKeyword.entries) {
      if (has(entry.key)) {
        return [
          AssistantText(
            'Here\'s what I\'d book for ${entry.value.category.toLowerCase()}:',
          ),
          ServiceOffers([entry.value]),
        ];
      }
    }
    return const [
      AssistantText(
        'I can help with car washes, home and deep cleaning, carpets, '
        'laundry, glass, pets and events — and I\'ll check the weather '
        'before booking anything outdoors. What needs cleaning?',
      ),
    ];
  }
}

/// Shown in the listening demo until speech recognition is connected.
const sampleVoiceRequest =
    'Skip the car wash today - book it Thursday and send someone for the '
    'carpet instead';

const quickSuggestions = [
  ['Pet grooming', 'Glass cleaning', 'Event clean'],
  ['Wash my car today', 'Deep Cleaning', 'Laundry'],
];
