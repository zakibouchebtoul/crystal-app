import 'package:flutter/foundation.dart';

/// A saved package: which service and which package in it.
typedef Favourite = ({String serviceId, String package});

/// Packages the customer hearted. Kept in memory until accounts sync.
class FavouritesStore extends ChangeNotifier {
  final List<Favourite> _items = [];

  List<Favourite> get all => List.unmodifiable(_items);

  bool contains(Favourite f) => _items.contains(f);

  /// Adds or removes [f]; returns whether it's now saved.
  bool toggle(Favourite f) {
    final added = !_items.remove(f);
    if (added) _items.insert(0, f);
    notifyListeners();
    return added;
  }
}

final favourites = FavouritesStore();
