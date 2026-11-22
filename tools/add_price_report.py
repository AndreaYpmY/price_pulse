#!/usr/bin/env python3
"""
===============================================================================
GUIDA RAPIDA ALL'USO — tools/add_price_report.py
===============================================================================
Inserisce una o più segnalazioni di prezzo nella collezione `price_reports`
su Cloud Firestore tramite API REST, leggendo il projectId da
`lib/firebase_options.dart` (oppure da `--project-id`).

COMPORTAMENTO AUTOMATICO:
- `createdAt`: se omesso, vuoto o nullo, viene generato automaticamente con il
  timestamp attuale in millisecondi (`int(time.time() * 1000)`). Se passi un
  timestamp a 10 cifre (secondi), viene convertito in millisecondi.
- `reporterId`: se omesso, vuoto o nullo, viene impostato automaticamente su
  `default_test_user` (utile per simulare segnalazioni di altri utenti ed
  evitare auto-notifiche dal proprio dispositivo).
- Dati supermercato: se passi solo `--store-id` (o `storeId` nel JSON), lo
  script prova a recuperare in automatico `storeName`, `lat` e `lng` dalla
  collezione `stores` su Firestore.

-------------------------------------------------------------------------------
1. MODALITÀ GUIDATA INTERATTIVA (dal terminale)
-------------------------------------------------------------------------------
Utile quando vuoi scegliere il supermercato da elenco e digitare i valori a mano:

  python3 tools/add_price_report.py
  # oppure esplicitamente:
  python3 tools/add_price_report.py -i
  python3 tools/add_price_report.py --interactive

-------------------------------------------------------------------------------
2. INSERIMENTO DIRETTO DA SHELL (con flag)
-------------------------------------------------------------------------------
Inserisce un singolo prodotto passando i parametri direttamente da comando:

  python3 tools/add_price_report.py \
    --product "Pasta Barilla Spaghetti n.5 500g" \
    --price 1.09 \
    --store-id "osm_node_123456789"

Con `reporterId` e `createdAt` personalizzati:

  python3 tools/add_price_report.py \
    --product "Latte Granarolo 1L" \
    --price 1.35 \
    --store-id "osm_node_123456789" \
    --reporter-id "utente_test_2" \
    --created-at 1795285860000

Anche senza `store-id` su Firestore, indicando nome e coordinate a mano:

  python3 tools/add_price_report.py \
    --product "Olio Extra Vergine 1L" \
    --price 6.90 \
    --store-name "Conad Via Roma" \
    --lat 39.36 \
    --lng 16.22

-------------------------------------------------------------------------------
3. INSERIMENTO DA FILE JSON
-------------------------------------------------------------------------------
Accetta una lista di oggetti `[ {...}, {...} ]`, un singolo oggetto `{...}`,
oppure un oggetto con chiave `"reports"` o `"products"`:

  python3 tools/add_price_report.py --json tools/sample_reports.json

Esempio di struttura JSON (i campi `createdAt` e `reporterId` sono opzionali):
[
  {
    "productName": "Pasta Barilla Spaghetti n.5 500g",
    "price": 1.09,
    "storeId": "osm_node_123456789"
  },
  {
    "productName": "Caffè Lavazza 250g",
    "price": 3.49,
    "storeId": "osm_node_123456789",
    "reporterId": "altro_utente",
    "createdAt": 1795285860000
  }
]

-------------------------------------------------------------------------------
4. OPZIONI AGGIUNTIVE UTILI
-------------------------------------------------------------------------------
- Anteprima senza scrivere su Firestore (`--dry-run`):
    python3 tools/add_price_report.py --json tools/sample_reports.json --dry-run

- Specificare manualmente il progetto Firebase (`--project-id`):
    python3 tools/add_price_report.py --product "Acqua 1.5L" --price 0.35 --store-name "Lidl" --project-id "mio-progetto"
===============================================================================
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_REPORTER_ID = "default_test_user"


def detect_project_id(explicit_project_id: str | None = None) -> str:
    if explicit_project_id:
        return explicit_project_id.strip()

    options_path = Path("lib/firebase_options.dart")
    if not options_path.exists():
        raise FileNotFoundError(
            "File lib/firebase_options.dart non trovato e --project-id non specificato."
        )

    content = options_path.read_text(encoding="utf-8")
    match = re.search(r'''projectId:\s*['"]([^'"]+)['"]''', content)
    if not match:
        raise ValueError("Impossibile estrarre projectId da lib/firebase_options.dart.")
    return match.group(1)


def _parse_fs_field(field: dict[str, Any]) -> Any:
    if "stringValue" in field:
        return field["stringValue"]
    if "doubleValue" in field:
        return float(field["doubleValue"])
    if "integerValue" in field:
        return int(field["integerValue"])
    if "booleanValue" in field:
        return bool(field["booleanValue"])
    return None


def fetch_stores(project_id: str) -> dict[str, dict[str, Any]]:
    url = (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        "/databases/(default)/documents/stores?pageSize=200"
    )
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    stores_by_id: dict[str, dict[str, Any]] = {}
    for doc in data.get("documents", []):
        doc_id = doc.get("name", "").split("/")[-1]
        raw_fields = doc.get("fields", {})
        parsed = {k: _parse_fs_field(v) for k, v in raw_fields.items()}
        parsed["id"] = doc_id
        stores_by_id[doc_id] = parsed
    return stores_by_id


def _normalize_timestamp_ms(value: Any) -> int:
    if value is None or value == "":
        return int(time.time() * 1000)
    if isinstance(value, bool):
        raise ValueError("Il campo createdAt non può essere un booleano.")
    if isinstance(value, (int, float)):
        ts = int(value)
        return ts * 1000 if ts < 10**11 else ts
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return int(time.time() * 1000)
        if re.fullmatch(r"-?\d+", stripped):
            ts = int(stripped)
            return ts * 1000 if ts < 10**11 else ts
    raise ValueError(f"Formato createdAt non valido: {value!r}")


def build_report_document(
    item: dict[str, Any],
    stores_by_id: dict[str, dict[str, Any]],
    default_reporter: str,
) -> dict[str, Any]:
    product_name = str(item.get("productName") or item.get("product_name") or "").strip()
    if not product_name:
        raise ValueError("Campo 'productName' mancante o vuoto.")

    raw_price = item.get("price")
    if raw_price is None or str(raw_price).strip() == "":
        raise ValueError(f"Campo 'price' mancante per il prodotto '{product_name}'.")
    price = float(str(raw_price).strip().replace(",", "."))

    store_id = str(item.get("storeId") or item.get("store_id") or "").strip()
    store_info = stores_by_id.get(store_id, {})

    store_name = str(
        item.get("storeName")
        or item.get("store_name")
        or store_info.get("name")
        or ""
    ).strip()
    if not store_name and not store_id:
        raise ValueError(
            f"Specificare almeno 'storeId' o 'storeName' per '{product_name}'."
        )
    if not store_name:
        store_name = store_id

    raw_lat = item.get("lat") if item.get("lat") is not None else store_info.get("lat")
    raw_lng = item.get("lng") if item.get("lng") is not None else store_info.get("lng")
    lat = float(raw_lat) if raw_lat is not None and str(raw_lat).strip() != "" else 0.0
    lng = float(raw_lng) if raw_lng is not None and str(raw_lng).strip() != "" else 0.0

    created_at_ms = _normalize_timestamp_ms(
        item.get("createdAt") if "createdAt" in item else item.get("created_at")
    )

    raw_reporter = (
        item.get("reporterId") if "reporterId" in item else item.get("reporter_id")
    )
    reporter_id = (
        str(raw_reporter).strip()
        if raw_reporter is not None and str(raw_reporter).strip() != ""
        else default_reporter
    )

    return {
        "productName": product_name,
        "price": price,
        "storeId": store_id,
        "storeName": store_name,
        "lat": lat,
        "lng": lng,
        "createdAt": created_at_ms,
        "reporterId": reporter_id,
    }


def post_price_report(project_id: str, doc: dict[str, Any]) -> str:
    url = (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        "/databases/(default)/documents/price_reports"
    )
    payload = {
        "fields": {
            "productName": {"stringValue": doc["productName"]},
            "price": {"doubleValue": float(doc["price"])},
            "storeId": {"stringValue": doc["storeId"]},
            "storeName": {"stringValue": doc["storeName"]},
            "lat": {"doubleValue": float(doc["lat"])},
            "lng": {"doubleValue": float(doc["lng"])},
            "createdAt": {"integerValue": str(doc["createdAt"])},
            "reporterId": {"stringValue": doc["reporterId"]},
        }
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        created = json.loads(resp.read().decode("utf-8"))
    return created.get("name", "").split("/")[-1]


def load_items_from_json(json_path: str) -> list[dict[str, Any]]:
    path = Path(json_path)
    if not path.exists():
        raise FileNotFoundError(f"File JSON non trovato: {json_path}")

    parsed = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(parsed, list):
        return parsed
    if isinstance(parsed, dict):
        if isinstance(parsed.get("reports"), list):
            return parsed["reports"]
        if isinstance(parsed.get("products"), list):
            return parsed["products"]
        return [parsed]
    raise ValueError("Il file JSON deve contenere un oggetto o una lista di oggetti.")


def _select_store_interactive(stores_by_id: dict[str, dict[str, Any]]) -> dict[str, Any]:
    ordered = sorted(stores_by_id.values(), key=lambda s: str(s.get("name", "")))
    if not ordered:
        return {"id": "", "name": "", "lat": 0.0, "lng": 0.0}

    print("\nSupermercati disponibili su Firestore:")
    for idx, store in enumerate(ordered, start=1):
        print(f"  {idx}) {store.get('name')}  [id: {store.get('id')}]")

    while True:
        choice = input("Seleziona numero supermercato (invio per il primo): ").strip()
        if choice == "":
            return ordered[0]
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(ordered):
                return ordered[idx]
        print("Scelta non valida, riprova.")


def run_interactive(
    project_id: str,
    stores_by_id: dict[str, dict[str, Any]],
    default_reporter: str,
    dry_run: bool,
) -> list[dict[str, Any]]:
    print("\n=== Inserimento rapido segnalazione prezzo ===")
    store = _select_store_interactive(stores_by_id)

    product_name = ""
    while not product_name:
        product_name = input("Nome prodotto: ").strip()

    while True:
        raw_price = input("Prezzo (€): ").strip().replace(",", ".")
        try:
            price = float(raw_price)
            break
        except ValueError:
            print("Inserisci un numero valido (es. 1.29).")

    reporter_in = input(
        f"ID utente [invio = {default_reporter}]: "
    ).strip()
    created_in = input(
        "Timestamp createdAt in ms [invio = adesso automatico]: "
    ).strip()

    item: dict[str, Any] = {
        "productName": product_name,
        "price": price,
        "storeId": store.get("id", ""),
        "storeName": store.get("name", ""),
        "lat": store.get("lat", 0.0),
        "lng": store.get("lng", 0.0),
        "reporterId": reporter_in or default_reporter,
    }
    if created_in:
        item["createdAt"] = int(created_in)

    doc = build_report_document(item, stores_by_id, default_reporter)
    if not dry_run:
        doc_id = post_price_report(project_id, doc)
        doc["id"] = doc_id
    return [doc]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inserisce prodotti/segnalazioni in price_reports su Firestore da CLI o file JSON."
    )
    parser.add_argument(
        "--json",
        dest="json_file",
        help='Percorso a un file JSON (singolo oggetto, lista o {"reports": [...]})',
    )
    parser.add_argument("--product", help="Nome del prodotto (inserimento diretto da shell)")
    parser.add_argument("--price", type=float, help="Prezzo del prodotto (es. 1.29)")
    parser.add_argument("--store-id", help="ID documento del supermercato in `stores`")
    parser.add_argument("--store-name", help="Nome del supermercato (opzionale se noto da store-id)")
    parser.add_argument("--lat", type=float, help="Latitudine supermercato")
    parser.add_argument("--lng", type=float, help="Longitudine supermercato")
    parser.add_argument(
        "--created-at",
        help="Timestamp createdAt in ms (se omesso viene generato ora)",
    )
    parser.add_argument(
        "--reporter-id",
        default=DEFAULT_REPORTER_ID,
        help=f"ID utente segnalatore (default: {DEFAULT_REPORTER_ID})",
    )
    parser.add_argument(
        "--project-id",
        help="Firebase projectId (se omesso viene letto da lib/firebase_options.dart)",
    )
    parser.add_argument(
        "--interactive",
        "-i",
        action="store_true",
        help="Modalità guidata interattiva da terminale",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostra i documenti pronti senza inviarli a Firestore",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        project_id = detect_project_id(args.project_id)
    except Exception as exc:
        print(f"[ERRORE] {exc}", file=sys.stderr)
        return 1

    try:
        stores_by_id = fetch_stores(project_id)
    except urllib.error.URLError as exc:
        print(f"[AVVISO] Impossibile leggere i supermercati da Firestore: {exc}", file=sys.stderr)
        stores_by_id = {}

    raw_items: list[dict[str, Any]] = []

    if args.json_file:
        try:
            raw_items.extend(load_items_from_json(args.json_file))
        except Exception as exc:
            print(f"[ERRORE] Lettura JSON fallita: {exc}", file=sys.stderr)
            return 1

    has_cli_product = args.product is not None or args.price is not None
    if has_cli_product:
        raw_items.append(
            {
                "productName": args.product,
                "price": args.price,
                "storeId": args.store_id or "",
                "storeName": args.store_name or "",
                "lat": args.lat,
                "lng": args.lng,
                "createdAt": args.created_at,
                "reporterId": args.reporter_id,
            }
        )

    if args.interactive or not raw_items:
        try:
            docs = run_interactive(
                project_id=project_id,
                stores_by_id=stores_by_id,
                default_reporter=args.reporter_id,
                dry_run=args.dry_run,
            )
            for doc in docs:
                suffix = f" (id: {doc['id']})" if "id" in doc else " [DRY-RUN]"
                print(
                    f"[OK] {doc['productName']} — € {doc['price']:.2f} "
                    f"@ {doc['storeName']} | reporter={doc['reporterId']} | "
                    f"createdAt={doc['createdAt']}{suffix}"
                )
            return 0
        except KeyboardInterrupt:
            print("\nOperazione annullata.")
            return 130
        except Exception as exc:
            print(f"[ERRORE] {exc}", file=sys.stderr)
            return 1

    inserted = 0
    for idx, raw in enumerate(raw_items, start=1):
        try:
            doc = build_report_document(raw, stores_by_id, args.reporter_id)
            if args.dry_run:
                print(
                    f"  [{idx}] [DRY-RUN] {doc['productName']} — € {doc['price']:.2f} "
                    f"@ {doc['storeName']} (storeId={doc['storeId']!r}, "
                    f"reporterId={doc['reporterId']!r}, createdAt={doc['createdAt']})"
                )
            else:
                doc_id = post_price_report(project_id, doc)
                print(
                    f"  [{idx}] [OK] {doc['productName']} — € {doc['price']:.2f} "
                    f"@ {doc['storeName']} | id={doc_id} | "
                    f"reporterId={doc['reporterId']} | createdAt={doc['createdAt']}"
                )
            inserted += 1
        except Exception as exc:
            print(f"  [{idx}] [ERRORE] {exc}", file=sys.stderr)

    print(f"\nCompletato: {inserted}/{len(raw_items)} segnalazioni elaborate.")
    return 0 if inserted == len(raw_items) else 1


if __name__ == "__main__":
    raise SystemExit(main())
