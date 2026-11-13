import 'package:cloud_firestore/cloud_firestore.dart';
import '../objects/price_report.dart';
import '../objects/store.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Legge tutti i supermercati (lettura continua)
  Stream<List<Store>> getStoresStream() {
    return _db.collection('stores').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Store.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Legge segnalazioni prezzi, dalla più recente (lettura continua)
  Stream<List<PriceReport>> getReportsStream() {
    return _db
        .collection('price_reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PriceReport.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 3. Salva nuova segnalazione su Firestore
  Future<void> addPriceReport(PriceReport report) async {
    await _db.collection('price_reports').add(report.toMap());
  }
}