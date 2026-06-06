#!/usr/bin/env python3
"""File overview: Generate Little Swan app and menu bar logo assets from the Google Stitch reference image."""

from __future__ import annotations

import base64
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CANVAS = 1024
ROOT = Path(__file__).resolve().parent
REFERENCE = ROOT / "google-stitch-logo-reference.png"


def purple_mask(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    mask = Image.new("L", rgba.size, 0)
    pixels = rgba.load()
    mask_pixels = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            # Capture the Stitch purple facets while excluding the gray checkerboard,
            # text, and white card chrome in the screenshot.
            if b >= 145 and r >= 95 and g <= 150 and (b - g) >= 45 and (r - g) >= 20:
                mask_pixels[x, y] = 255
    return mask


def crop_reference_mark(reference: Image.Image) -> tuple[Image.Image, Image.Image]:
    mask = purple_mask(reference)
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("No purple logo mark found in Google Stitch reference")

    pad = 8
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(reference.width, x1 + pad)
    y1 = min(reference.height, y1 + pad)

    cropped = reference.convert("RGBA").crop((x0, y0, x1, y1))
    cropped_mask = mask.crop((x0, y0, x1, y1))

    # Include antialiased purple edges but keep the checkerboard transparent.
    alpha = cropped_mask.filter(ImageFilter.GaussianBlur(1.1))
    alpha = ImageChops.lighter(alpha, cropped_mask)
    extracted = Image.new("RGBA", cropped.size, (0, 0, 0, 0))
    extracted.alpha_composite(cropped)
    extracted.putalpha(alpha)
    return extracted, alpha


def centered_canvas(mark: Image.Image, target_width: int = 640) -> Image.Image:
    scale = target_width / mark.width
    resized = mark.resize(
        (round(mark.width * scale), round(mark.height * scale)),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - resized.width) // 2
    y = (CANVAS - resized.height) // 2 + 4
    canvas.alpha_composite(resized, (x, y))
    return canvas


def template_canvas(alpha_source: Image.Image, target_width: int = 920) -> Image.Image:
    # A menu bar template icon should be a monochrome alpha mask. Use a slightly
    # consolidated silhouette so the origami bird remains readable at 18 px.
    alpha = alpha_source.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(0.7))
    scale = target_width / alpha.width
    resized_alpha = alpha.resize(
        (round(alpha.width * scale), round(alpha.height * scale)),
        Image.Resampling.LANCZOS,
    )
    canvas_alpha = Image.new("L", (CANVAS, CANVAS), 0)
    x = (CANVAS - resized_alpha.width) // 2
    y = (CANVAS - resized_alpha.height) // 2 + 4
    canvas_alpha.paste(resized_alpha, (x, y))
    template = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
    template.putalpha(canvas_alpha)
    return template


def png_data_uri(image: Image.Image) -> str:
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def write_embedded_svg(path: Path, title: str, description: str, image: Image.Image) -> None:
    data_uri = png_data_uri(image)
    path.write_text(
        f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">
  <title id="title">{title}</title>
  <desc id="desc">{description}</desc>
  <image href="{data_uri}" width="1024" height="1024" />
</svg>
''',
        encoding="utf-8",
    )


def write_preview_sample(icon: Image.Image, template: Image.Image) -> None:
    preview_dir = ROOT / "generated-previews"
    preview_dir.mkdir(exist_ok=True)

    checker = Image.new("RGBA", (320, 320), (255, 255, 255, 255))
    draw = ImageDraw.Draw(checker)
    tile = 20
    for y in range(0, 320, tile):
        for x in range(0, 320, tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(214, 214, 214, 255))
    icon_sample = icon.resize((280, 280), Image.Resampling.LANCZOS)
    checker.alpha_composite(icon_sample, (10, 10))
    checker.save(preview_dir / "app-icon-on-checker.png")

    strip = Image.new("RGBA", (320, 72), (247, 247, 247, 255))
    small_alpha = template.getchannel("A").resize((18, 18), Image.Resampling.LANCZOS)
    small = Image.new("RGBA", (18, 18), (0, 0, 0, 255))
    small.putalpha(small_alpha)
    strip.alpha_composite(small, (151, 27))
    strip.save(preview_dir / "menubar-18px-template.png")


def main() -> None:
    if not REFERENCE.exists():
        raise RuntimeError(f"Missing Google Stitch reference image: {REFERENCE}")

    reference = Image.open(REFERENCE)
    mark, alpha = crop_reference_mark(reference)
    icon = centered_canvas(mark)
    template = template_canvas(alpha)

    icon.save(ROOT / "little-swan-icon.png")
    template.save(ROOT / "little-swan-menubar-template.png")
    icon.save(
        ROOT / "LittleSwan.icns",
        sizes=[
            (16, 16),
            (32, 32),
            (64, 64),
            (128, 128),
            (256, 256),
            (512, 512),
            (1024, 1024),
        ],
    )
    write_embedded_svg(
        ROOT / "little-swan-icon.svg",
        "Little Swan app logo",
        "A compact purple origami swan logo adapted from the Google Stitch reference.",
        icon,
    )
    write_embedded_svg(
        ROOT / "little-swan-menubar-template.svg",
        "Little Swan menu bar template icon",
        "A black transparent-mask origami swan for macOS menu bar template rendering.",
        template,
    )
    write_preview_sample(icon, template)

    for asset in [
        "little-swan-icon.svg",
        "little-swan-icon.png",
        "little-swan-menubar-template.svg",
        "little-swan-menubar-template.png",
        "LittleSwan.icns",
        "generated-previews/app-icon-on-checker.png",
        "generated-previews/menubar-18px-template.png",
    ]:
        path = ROOT / asset
        print(f"wrote {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
