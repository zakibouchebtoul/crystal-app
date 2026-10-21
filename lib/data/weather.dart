/// Sample 5-day forecast for Doha until a weather service is connected.
enum Sky { dust, hazy, clear }

class DayForecast {
  const DayForecast(this.dayOffset, this.sky, this.high);

  /// 0 = today.
  final int dayOffset;
  final Sky sky;

  /// Daytime high in °C.
  final int high;
}

const forecast = [
  DayForecast(0, Sky.dust, 34),
  DayForecast(1, Sky.dust, 35),
  DayForecast(2, Sky.hazy, 33),
  DayForecast(3, Sky.clear, 31),
  DayForecast(4, Sky.clear, 32),
];

/// First clear day ahead (best for outdoor services).
DayForecast? get firstClearDay {
  for (final d in forecast) {
    if (d.sky == Sky.clear) return d;
  }
  return null;
}
