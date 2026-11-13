class Store {
  final String id;
  final String name;
  final double lat;
  final double lng;

  Store({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng
  });

  // Per Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng
    };
  }

  // Da Firebase
  factory Store.fromMap(Map<String, dynamic> map, String documentId){
    return Store(
      id: documentId,
      name: map['name'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble()
    );
  }


}