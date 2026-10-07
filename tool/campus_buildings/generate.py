#!/usr/bin/env python3
"""Generates lib/models/uniandes_buildings.dart from OpenStreetMap.

Each Uniandes building is an OSM way whose outline is downloaded from the
public OSM API. The app uses the outline to tell which building the student
is in, so the coordinates must come from the map and not be typed by hand.

Run from the Flutter project root:
    python3 tool/campus_buildings/generate.py

Map data (c) OpenStreetMap contributors, available under the ODbL.
"""

import math
import pathlib
import time
import urllib.request
import xml.etree.ElementTree as ET

OSM_API = "https://api.openstreetmap.org/api/0.6/way/{}/full"
USER_AGENT = "CampusFind-ISIS3510/1.0 (Uniandes course project)"
OUTPUT = pathlib.Path("lib/models/uniandes_buildings.dart")

# (code, OSM way id, display name or None). The code is the official
# "bloque" letter (None when the university gives the building no letter).
# Names were checked against the university's own building pages
# (campusinfo.uniandes.edu.co/es/recursos/edificios, archived 2019-2025 at
# web.archive.org), the "Edificios" section of the Spanish Wikipedia article
# and the OSM tags. Unnamed buildings show "Bloque X".
BUILDINGS = [
    ("A", 175953469, None),
    ("Au", 175953467, "Aulas"),
    ("B", 175531487, None),
    ("C", 175950954, "Facultad de Arquitectura y Diseño"),
    ("Ca", 1047152901, None),
    ("Cc", 1047152902, None),
    ("Ch", 175534795, None),
    (None, 175953474, "Centro del Japón"),
    ("E", 667553819, None),
    ("F", 175951534, None),
    ("G", 175531126, None),
    ("Ga", 175956826, "Centro Deportivo"),
    ("H", 175531482, None),
    ("I", 175953470, None),
    ("Ip", 175953472, "Departamento de Física"),
    ("J", 175531483, None),
    ("K", 175951230, "Departamento de Arquitectura"),
    ("K2", 175951229, None),
    ("L", 175953468, None),
    ("LL", 666563755, "Alberto Lleras Camargo"),
    ("M", 175531484, None),
    ("M1", 666563756, None),
    ("Mj", 192119030, None),
    ("ML", 517588980, "Mario Laserna"),
    ("N", 175531485, None),
    ("Ñf", 175953471, None),
    ("Ñl", 192115771, None),
    ("O", 175531128, "Henri Yerly"),
    ("P", 175952377, None),
    ("P1", 175952374, None),
    ("Q", 175531130, None),
    ("R", 175950953, None),
    ("Rga", 175953465, None),
    ("Rgb", 175953473, "Pedro Navas"),
    ("Rgc", 175534784, None),
    ("Rgd", 680633704, "Centro Cívico"),
    ("S", 666563753, None),
    ("S1", 175951851, None),
    ("SD", 406122390, "Julio Mario Santo Domingo"),
    ("T", 666563748, None),
    ("Tm", 666563749, None),
    ("Tr", 666563750, None),
    ("Tx", 175951852, None),
    ("U", 175950951, "Biblioteca El Campito"),
    ("V", 175950955, None),
    ("W", 517588978, "Carlos Pacheco Devia"),
    ("X", 175951532, "Villa Paulina"),
    ("Y", 175534787, None),
    ("Z", 175534798, None),
]


def fetch_outline(way_id):
    request = urllib.request.Request(
        OSM_API.format(way_id), headers={"User-Agent": USER_AGENT}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        root = ET.fromstring(response.read())
    nodes = {
        n.get("id"): (float(n.get("lat")), float(n.get("lon")))
        for n in root.iter("node")
    }
    way = root.find("way")
    points = [nodes[nd.get("ref")] for nd in way.iter("nd")]
    if points[0] != points[-1]:
        raise ValueError(f"way {way_id} is not a closed outline")
    return points[:-1]


def area_centroid(points):
    """Area-weighted centroid on a local plane; exact enough for one block."""
    lat0 = sum(p[0] for p in points) / len(points)
    lon0 = sum(p[1] for p in points) / len(points)
    ky = 111320.0
    kx = ky * math.cos(math.radians(lat0))
    xy = [((lon - lon0) * kx, (lat - lat0) * ky) for lat, lon in points]
    area = cx = cy = 0.0
    for (x1, y1), (x2, y2) in zip(xy, xy[1:] + xy[:1]):
        cross = x1 * y2 - x2 * y1
        area += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    area /= 2
    return lat0 + cy / (6 * area) / ky, lon0 + cx / (6 * area) / kx


def dart_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main():
    entries = []
    for code, way_id, name in BUILDINGS:
        outline = fetch_outline(way_id)
        lat, lon = area_centroid(outline)
        if code is None:
            label, code = name, f"osm-{way_id}"
        else:
            label = f"{name} ({code})" if name else f"Bloque {code}"
        points = ",\n".join(
            f"      ({p_lat:.7f}, {p_lon:.7f})" for p_lat, p_lon in outline
        )
        entries.append(
            "  CampusLocation(\n"
            f"    id: {dart_string(code)},\n"
            f"    name: {dart_string(label)},\n"
            f"    latitude: {lat:.7f},\n"
            f"    longitude: {lon:.7f},\n"
            f"    osmWayId: {way_id},\n"
            "    outline: [\n"
            f"{points},\n"
            "    ],\n"
            "  ),"
        )
        time.sleep(0.5)  # keep the public OSM API happy

    OUTPUT.write_text(
        "// GENERATED by tool/campus_buildings/generate.py. Do not edit by hand.\n"
        "// Building outlines (c) OpenStreetMap contributors, ODbL.\n"
        "// https://www.openstreetmap.org/copyright\n\n"
        "import 'campus_locations.dart';\n\n"
        "const List<CampusLocation> uniandesBuildings = [\n"
        + "\n".join(entries)
        + "\n];\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(entries)} buildings to {OUTPUT}")


if __name__ == "__main__":
    main()
