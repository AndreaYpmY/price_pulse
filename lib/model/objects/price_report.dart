class PriceReport {
  final String id;
  final String productName;
  final double price;
  final String storeId;
  final String storeName;
  final double lat;
  final double lng;
  final DateTime createdAt;

  PriceReport({
    required this.id,
    required this.productName,
    required this.price,
    required this.storeId,
    required this.storeName,
    required this.lat,
    required this.lng,
    required this.createdAt
  });

  // Per Firebase
  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'price': price,
      'storeId': storeId,
      'storeName': storeName,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Da Firebase
  factory PriceReport.fromMap(Map<String, dynamic> map, String documentId) {
    return PriceReport(
      id: documentId,
      productName: map['productName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      storeId: map['storeId'] ?? '',
      storeName: map['storeName'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}