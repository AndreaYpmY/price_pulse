import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_gemini/flutter_gemini.dart';

class ScannedProductResult {
  final String productName;
  final double price;

  ScannedProductResult({
    required this.productName,
    required this.price,
  });
}

class GeminiService {
  // Analizzo i byte dell'immagine
  Future<ScannedProductResult?> analyzePriceTag(Uint8List imageBytes) async {
    const promptText = '''
        Analizza questa immagine di un cartellino del prezzo da supermercato o scontrino.
        Estrai il nome del prodotto e il prezzo finale in euro.
        Regole obbligatorie:
          1. Normalizza il nome seguendo lo schema: [Tipo prodotto] [Marca] [Formato/Peso] (es. "Pasta Barilla 500g", "Latte Granarolo 1L").
          2. Rimuovi parole promozionali come "Offerta", "Sconto", "Nuova ricetta", "Formato convenienza". Mantieni massimo 4-5 parole chiave.
          3. Rispondi ESCLUSIVAMENTE con un oggetto JSON valido, senza markdown né testo aggiuntivo, in questo formato esatto:
             {"productName": "Nome Prodotto", "price": 1.29}
    ''';

    try {
      final response = await Gemini.instance.prompt(
        parts: [
          Part.text(promptText),
          Part.uint8List(imageBytes),
        ],
      );

      final rawOutput = response?.output;
      if (rawOutput == null || rawOutput.isEmpty) return null;

      // Pulisco eventuali ```json ... ``` aggiunti dal modello
      final cleanedJson = rawOutput
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(cleanedJson);

      final String name = (data['productName'] ?? '').toString().trim();
      final double price = (data['price'] is num)
          ? (data['price'] as num).toDouble()
          : double.tryParse(data['price'].toString().replaceAll(',', '.')) ?? 0.0;

      if (name.isEmpty) return null;

      return ScannedProductResult(productName: name, price: price);
    } catch (e) {
      // In caso di errore di rete o JSON non valido, ritorno null
      // così UI può permettere l'inserimento manuale senza crashare
      return null;
    }
  }
}