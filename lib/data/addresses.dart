import 'package:flutter/foundation.dart';

/// What an address is for; sets its icon and default name.
enum AddressKind { home, work, other }

/// A Qatar address: zone, street and building number, as on the blue
/// building plates.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.kind,
    required this.zone,
    required this.street,
    required this.building,
    required this.area,
    this.name,
    this.unit,
    this.note,
  });

  final String id;
  final AddressKind kind;
  final String zone;
  final String street;
  final String building;

  /// District, e.g. "West Bay".
  final String area;

  /// Custom name for [AddressKind.other] (e.g. "Mum's house").
  final String? name;

  /// Flat, floor or villa number.
  final String? unit;

  /// Directions for the pro.
  final String? note;

  String get label => switch (kind) {
    AddressKind.home => 'Home',
    AddressKind.work => 'Work',
    AddressKind.other => name?.trim().isNotEmpty == true ? name! : 'Other',
  };

  /// "Building 7, Street 577, Zone 69".
  String get line => 'Building $building, Street $street, Zone $zone';

  /// [line] with the area, for the home header.
  String get full => '$line, $area';
}

/// Saved addresses and which one bookings go to. Sample data until
/// accounts are connected to the backend.
class AddressBook extends ChangeNotifier {
  final List<SavedAddress> _all = [
    const SavedAddress(
      id: 'home',
      kind: AddressKind.home,
      zone: '69',
      street: '577',
      building: '7',
      area: 'West Bay',
      unit: 'Flat 12, 3rd floor',
    ),
    const SavedAddress(
      id: 'work',
      kind: AddressKind.work,
      zone: '61',
      street: '850',
      building: '23',
      area: 'Lusail',
    ),
  ];
  String _selectedId = 'home';

  List<SavedAddress> get all => List.unmodifiable(_all);

  SavedAddress get selected =>
      _all.firstWhere((a) => a.id == _selectedId, orElse: () => _all.first);

  void select(String id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Adds [address] and makes it the selected one.
  void add(SavedAddress address) {
    _all.add(address);
    _selectedId = address.id;
    notifyListeners();
  }
}

final addressBook = AddressBook();
