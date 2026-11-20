#!/usr/bin/env python3
"""
PricePulse — Script Operatore per Sincronizzazione Anagrafica Supermercati
===========================================================================

Interroga OpenStreetMap tramite Overpass API (query Bounding Box ottimizzata)
con fallback automatico su Photon OSM API, e sincronizza in modo idempotente
la collezione `stores` su Cloud Firestore.
"""

import argparse
import json
import math
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://lz4.overpass-api.de/api/interpreter",
    "https://z.overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

PHOTON_API_URL = "https://photon.komoot.io/api/"

DEFAULT_LAT = 39.3350   # Area urbana Cosenza - Rende - UNICAL
DEFAULT_LNG = 16.2450
DEFAULT_RADIUS_M = 15000


def detect_firebase_project_id() -> str:
    """Estrae automaticamente il projectId da lib/firebase_options.dart."""
    candidates = [
        Path("lib/firebase_options.dart"),
        Path(__file__).resolve().parent.parent / "lib" / "firebase_options.dart",
    ]
    for path in candidates:
        if path.is_file():
            content = path.read_text(encoding="utf-8")
            match = re.search(r"projectId:\s*'([^']+)'", content)
            if match:
                return match.group(1)

    raise FileNotFoundError(
        "Impossibile trovare 'projectId' in lib/firebase_options.dart. "
        "Esegui lo script dalla radice del progetto oppure passa --project-id."
    )


def haversine_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calcola la distanza in metri tra due coordinate GPS."""
    r = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def compute_bounding_box(lat: float, lng: float, radius_m: int) -> tuple[float, float, float, float]:
    """Converte centro + raggio in (south, west, north, east) per query spaziali veloci."""
    lat_delta = radius_m / 111320.0
    lng_delta = radius_m / (111320.0 * max(math.cos(math.radians(lat)), 0.1))
    return (lat - lat_delta, lng - lng_delta, lat + lat_delta, lng + lng_delta)


def fetch_from_overpass(lat: float, lng: float, radius_m: int) -> list[dict]:
    """Interroga Overpass API usando un Bounding Box rapido su node e way."""
    south, west, north, east = compute_bounding_box(lat, lng, radius_m)
    overpass_query = (
        f"[out:json][timeout:15];"
        f"("
        f'node["shop"="supermarket"]({south:.5f},{west:.5f},{north:.5f},{east:.5f});'
        f'way["shop"="supermarket"]({south:.5f},{west:.5f},{north:.5f},{east:.5f});'
        f");"
        f"out center tags;"
    )
    encoded_data = urllib.parse.urlencode({"data": overpass_query}).encode("utf-8")

    raw_data = None
    for endpoint in OVERPASS_ENDPOINTS:
        print(f"  -> Overpass: {endpoint} ...")
        req = urllib.request.Request(
            endpoint,
            data=encoded_data,
            headers={
                "User-Agent": "PricePulse-StoreSync/1.2 (academic-project)",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw_data = json.loads(resp.read().decode("utf-8"))
                break
        except Exception as exc:
            print(f"     Non disponibile ({exc})")
            time.sleep(0.5)

    if raw_data is None:
        return []

    stores: list[dict] = []
    for element in raw_data.get("elements", []):
        tags = element.get("tags", {})
        base_name = (tags.get("name") or tags.get("brand") or "").strip()
        if not base_name:
            continue

        el_lat = element.get("lat") or element.get("center", {}).get("lat")
        el_lng = element.get("lon") or element.get("center", {}).get("lon")
        if el_lat is None or el_lng is None:
            continue

        if haversine_meters(lat, lng, float(el_lat), float(el_lng)) > radius_m:
            continue

        street = (tags.get("addr:street") or "").strip()
        display_name = (
            f"{base_name} - {street}"
            if street and street.lower() not in base_name.lower()
            else base_name
        )

        stores.append(
            {
                "id": f"osm_{element['type']}_{element['id']}",
                "name": display_name,
                "lat": float(el_lat),
                "lng": float(el_lng),
            }
        )

    return stores


def fetch_from_photon(lat: float, lng: float, radius_m: int) -> list[dict]:
    """Fallback veloce su Photon (indice OSM Komoot) se Overpass è congestionato."""
    print("  -> Fallback su Photon OpenStreetMap API ...")
    search_terms = [
        "supermarket",
        "Conad",
        "Lidl",
        "Eurospin",
        "MD",
        "Coop",
        "Carrefour",
        "Despar",
        "Crai",
        "Penny",
    ]
    seen_ids: set[str] = set()
    stores: list[dict] = []

    for term in search_terms:
        params = urllib.parse.urlencode(
            {
                "q": term,
                "lat": f"{lat:.5f}",
                "lon": f"{lng:.5f}",
                "limit": 30,
            }
        )
        req = urllib.request.Request(
            f"{PHOTON_API_URL}?{params}",
            headers={"User-Agent": "PricePulse-StoreSync/1.2 (academic-project)"},
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            print(f"     Errore Photon per '{term}': {exc}")
            continue

        for feature in data.get("features", []):
            props = feature.get("properties", {})
            coords = feature.get("geometry", {}).get("coordinates", [])
            if len(coords) < 2:
                continue

            if props.get("osm_value") != "supermarket":
                continue

            el_lng, el_lat = float(coords[0]), float(coords[1])
            if haversine_meters(lat, lng, el_lat, el_lng) > radius_m:
                continue

            osm_type_map = {"N": "node", "W": "way", "R": "relation"}
            osm_type = osm_type_map.get(props.get("osm_type", ""), "node")
            osm_id = props.get("osm_id")
            base_name = (props.get("name") or "").strip()
            if not osm_id or not base_name:
                continue

            doc_id = f"osm_{osm_type}_{osm_id}"
            if doc_id in seen_ids:
                continue
            seen_ids.add(doc_id)

            street = (props.get("street") or "").strip()
            display_name = (
                f"{base_name} - {street}"
                if street and street.lower() not in base_name.lower()
                else base_name
            )

            stores.append(
                {
                    "id": doc_id,
                    "name": display_name,
                    "lat": el_lat,
                    "lng": el_lng,
                }
            )

    return stores


def upsert_store_to_firestore(project_id: str, store: dict) -> None:
    """Crea o aggiorna (PATCH idempotente) un documento nella collezione `stores`."""
    url = (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/(default)/documents/stores/{store['id']}"
    )
    payload = json.dumps(
        {
            "fields": {
                "name": {"stringValue": store["name"]},
                "lat": {"doubleValue": store["lat"]},
                "lng": {"doubleValue": store["lng"]},
            }
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        url,
        data=payload,
        method="PATCH",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=15):
        pass


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sincronizza i supermercati reali da OpenStreetMap su Firebase Firestore."
    )
    parser.add_argument("--lat", type=float, default=DEFAULT_LAT, help="Latitudine centro ricerca")
    parser.add_argument("--lng", type=float, default=DEFAULT_LNG, help="Longitudine centro ricerca")
    parser.add_argument("--radius", type=int, default=DEFAULT_RADIUS_M, help="Raggio in metri (default: 15000)")
    parser.add_argument("--project-id", type=str, default=None, help="ID progetto Firebase (opzionale)")
    parser.add_argument("--dry-run", action="store_true", help="Mostra i risultati senza scrivere su Firestore")
    args = parser.parse_args()

    try:
        project_id = args.project_id or detect_firebase_project_id()
    except FileNotFoundError as exc:
        print(f"[ERRORE] {exc}", file=sys.stderr)
        return 1

    print(f"Progetto Firebase : {project_id}")
    print(f"Area di ricerca   : ({args.lat}, {args.lng}) — raggio {args.radius} m")
    print("Ricerca supermercati OpenStreetMap in corso...")

    stores = fetch_from_overpass(args.lat, args.lng, args.radius)
    if not stores:
        stores = fetch_from_photon(args.lat, args.lng, args.radius)

    if not stores:
        print("[ERRORE] Nessun supermercato recuperato.", file=sys.stderr)
        return 1

    print(f"\nTrovati {len(stores)} punti vendita. Sincronizzazione con Firestore:\n")

    synced = 0
    for store in stores:
        if args.dry_run:
            print(f"  [DRY-RUN] {store['id']} -> {store['name']} ({store['lat']:.5f}, {store['lng']:.5f})")
            synced += 1
            continue

        try:
            upsert_store_to_firestore(project_id, store)
            print(f"  [OK] {store['name']} ({store['lat']:.5f}, {store['lng']:.5f})")
            synced += 1
        except urllib.error.URLError as exc:
            print(f"  [ERRORE] {store['name']}: {exc}", file=sys.stderr)

    mode = "anteprima completata" if args.dry_run else "sincronizzati su Firestore"
    print(f"\nRiepilogo: {synced}/{len(stores)} supermercati {mode}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
