#!/usr/bin/env python3
"""Compose Italian Store artwork from actual simulator captures, without upload."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/screenshots/app-store-source"
OUTPUT = ROOT / "AppStore/Screenshots/it"
FONT = "/System/Library/Fonts/SFNS.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

SCENES = [
    ("fixture-map", "La A56,\na colpo d’occhio.", "Tratti e svincoli sulla mappa.", True),
    ("fixture-programmate", "Chiusure e orari,\nper direzione.", "La programmazione prima di partire.", True),
    ("fixture-dettaglio-rampa", "Quale rampa?\nControlla il dettaglio.", "Entrate, uscite e orari dell’avviso.", True),
    ("fixture-avvisi-mapkit-percorso", "Il tuo percorso,\nprima di partire.", "Indirizzi manuali e posizione facoltativa.", True),
]


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def render(source, headline, subtitle, fixture, size):
    width, height = size
    scale = width / 1320
    image = Image.new("RGB", size, "#f2f5f7")
    draw = ImageDraw.Draw(image)
    left = round(86 * scale)
    draw.rounded_rectangle((left, round(74 * scale), left + round(138 * scale), round(132 * scale)),
                           radius=round(14 * scale), fill="#00666b")
    draw.text((left + round(23 * scale), round(81 * scale)), "A56", font=font(round(38 * scale), True), fill="white")
    draw.text((left + round(159 * scale), round(87 * scale)), "NAPOLI", font=font(round(29 * scale), True), fill="#00666b")
    headline_size = 94
    while max(draw.textlength(line, font=font(round(headline_size * scale), True)) for line in headline.splitlines()) > width - left * 2:
        headline_size -= 1
    draw.multiline_text((left, round(170 * scale)), headline, font=font(round(headline_size * scale), True),
                        fill="#132f32", spacing=round(4 * scale))
    draw.text((left, round(401 * scale)), subtitle, font=font(round(36 * scale)), fill="#3e5b60")
    if fixture:
        draw.text((left, round(461 * scale)), "AVVISI DIMOSTRATIVI", font=font(round(23 * scale), True), fill="#526b70")

    capture = Image.open(source).convert("RGB")
    assert capture.width / capture.height < 0.6, f"Expected portrait iPhone capture: {source}"
    screen_width = round(1044 * scale)
    screen_height = round(capture.height / capture.width * screen_width)
    screen_x = (width - screen_width) // 2
    screen_y = round(531 * scale)
    assert screen_y + screen_height < height - 30 * scale, "Screen must remain fully visible"
    screen = capture.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
    border = round(13 * scale)
    radius = round(82 * scale)
    bounds = (screen_x - border, screen_y - border, screen_x + screen_width + border, screen_y + screen_height + border)
    shadow = Image.new("RGBA", size)
    ImageDraw.Draw(shadow).rounded_rectangle(tuple(int(v) for v in bounds), radius=radius + border, fill=(8, 35, 39, 55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(28 * scale)))
    image = Image.alpha_composite(image.convert("RGBA"), shadow)
    ImageDraw.Draw(image).rounded_rectangle(bounds, radius=radius + border, fill="#14272a")
    mask = Image.new("L", screen.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen_width, screen_height), radius=radius, fill=255)
    image.paste(screen, (screen_x, screen_y), mask)
    return image.convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, default=SOURCE)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for index, (name, headline, subtitle, fixture) in enumerate(SCENES, 1):
        source = args.sources / f"{name}.png"
        if not source.is_file():
            raise SystemExit(f"Missing actual app capture: {source}")
        for label, size in [("iPhone-6.9", (1320, 2868)), ("iPhone-6.3", (1206, 2622))]:
            destination = OUTPUT / f"{label}-{index}-{name}.png"
            render(source, headline, subtitle, fixture, size).save(destination, optimize=True)
            manifest.append({"file": str(destination.relative_to(ROOT)), "source": str(source.relative_to(ROOT)),
                             "dimensions": list(size), "demonstrationData": fixture,
                             "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
    (ROOT / "AppStore/ScreenshotManifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    thumbnails = []
    for record in manifest:
        if record["dimensions"][0] == 1320:
            thumb = Image.open(ROOT / record["file"])
            thumb.thumbnail((330, 717))
            thumbnails.append(thumb)
    preview = Image.new("RGB", (330 * len(thumbnails), 717), "white")
    for index, thumb in enumerate(thumbnails):
        preview.paste(thumb, (330 * index, 0))
    preview.save(ROOT / "AppStore/Preview-it.png")
    print(f"Rendered {len(manifest)} screenshots from {len(SCENES)} app captures; no upload.")


if __name__ == "__main__":
    main()
