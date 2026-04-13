"""Render the Orbital Cadence teaser for super-ralph."""
from PIL import Image, ImageDraw, ImageFont
import math
import os

W, H = 1280, 640
CX, CY = 640, 360

PAPER = (244, 241, 234)
INK = (14, 26, 43)
ACCENT = (200, 85, 61)

FONT_DIR = (
    "/Users/junhua/.claude/plugins/cache/anthropic-agent-skills/"
    "document-skills/12ab35c2eb56/skills/canvas-design/canvas-fonts"
)
DISPLAY = os.path.join(FONT_DIR, "BigShoulders-Bold.ttf")
MONO = os.path.join(FONT_DIR, "IBMPlexMono-Regular.ttf")
MONO_BOLD = os.path.join(FONT_DIR, "IBMPlexMono-Bold.ttf")

PHASES = [
    "DESIGN", "PLAN", "BUILD", "REVIEW",
    "VERIFY", "FINALISE", "RELEASE", "REPAIR",
]
PHASE_COUNT = len(PHASES)

RING_INNER = 72
RING_PHASE = 128
RING_TICK = 182
RING_OUTER = 232


def phase_angle(i: int) -> float:
    return -math.pi / 2 + i * (2 * math.pi / PHASE_COUNT)


def polar(r: float, a: float) -> tuple[float, float]:
    return CX + r * math.cos(a), CY + r * math.sin(a)


def draw_circle(draw: ImageDraw.ImageDraw, r: float, width: int = 1) -> None:
    draw.ellipse([CX - r, CY - r, CX + r, CY + r], outline=INK, width=width)


def draw_tick_ring(draw: ImageDraw.ImageDraw) -> None:
    ticks = 48
    for i in range(ticks):
        a = -math.pi / 2 + i * (2 * math.pi / ticks)
        major = (i % 6 == 0)
        r2 = RING_OUTER if major else (RING_TICK + 14)
        x1, y1 = polar(RING_TICK, a)
        x2, y2 = polar(r2, a)
        draw.line([x1, y1, x2, y2], fill=INK, width=2 if major else 1)


def paste_rotated_text(
    base: Image.Image,
    text: str,
    font: ImageFont.FreeTypeFont,
    cx: float, cy: float,
    rotation_deg: float,
    color: tuple = INK,
) -> None:
    tmp_draw = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = tmp_draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = 12
    layer = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(layer)
    ldraw.text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=color + (255,))
    rotated = layer.rotate(-rotation_deg, expand=True, resample=Image.BICUBIC)
    px = int(cx - rotated.width / 2)
    py = int(cy - rotated.height / 2)
    base.paste(rotated, (px, py), rotated)


def draw_phase_labels(base: Image.Image) -> None:
    font = ImageFont.truetype(MONO_BOLD, 14)
    for i, phase in enumerate(PHASES):
        a = phase_angle(i)
        x, y = polar(RING_PHASE, a)
        tangent = math.degrees(a) + 90
        while tangent > 90:
            tangent -= 180
        while tangent < -90:
            tangent += 180
        paste_rotated_text(base, phase, font, x, y, tangent)


def draw_phase_markers(draw: ImageDraw.ImageDraw) -> None:
    for i in range(PHASE_COUNT):
        a = phase_angle(i)
        x, y = polar(RING_PHASE, a)
        draw.ellipse([x - 18, y - 12, x + 18, y + 12], fill=PAPER)


def draw_accent(draw: ImageDraw.ImageDraw) -> None:
    a = phase_angle(2)
    x1, y1 = polar(RING_TICK, a)
    x2, y2 = polar(RING_OUTER + 14, a)
    draw.line([x1, y1, x2, y2], fill=ACCENT, width=2)
    mx, my = polar(RING_OUTER + 22, a)
    draw.ellipse([mx - 5, my - 5, mx + 5, my + 5], fill=ACCENT)


def draw_corner_plate(base: Image.Image) -> None:
    d = ImageDraw.Draw(base)
    mono = ImageFont.truetype(MONO, 11)
    mono_bold = ImageFont.truetype(MONO_BOLD, 10)
    d.line([60, 52, 170, 52], fill=INK, width=1)
    d.text((60, 30), "JUNHUA / PLUGINS", font=mono_bold, fill=INK)
    d.text((60, 58), "instrument  no. I", font=mono, fill=INK)
    d.text((60, 74), "cadence  v.0.6.0", font=mono, fill=INK)

    right_label = "OBSERVED  MID-REVOLUTION"
    bbox = d.textbbox((0, 0), right_label, font=mono_bold)
    rw = bbox[2] - bbox[0]
    d.text((W - 60 - rw, 40), right_label, font=mono_bold, fill=INK)
    d.line([W - 60 - rw, 62, W - 60, 62], fill=INK, width=1)


def draw_display_word(base: Image.Image) -> None:
    d = ImageDraw.Draw(base)
    font = ImageFont.truetype(DISPLAY, 54)
    text = "SUPER · RALPH"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (W - tw) / 2
    ty = H - 112

    pad_x, pad_y = 28, 14
    well = [
        tx - pad_x, ty - pad_y,
        tx + tw + pad_x, ty + th + pad_y,
    ]
    d.rectangle(well, fill=PAPER)
    d.line([well[0], well[1], well[2], well[1]], fill=INK, width=1)
    d.line([well[0], well[3], well[2], well[3]], fill=INK, width=1)

    d.text((tx - bbox[0], ty - bbox[1]), text, font=font, fill=INK)

    sub_font = ImageFont.truetype(MONO, 12)
    subtitle = "ORBITAL   CADENCE   ·   AUTONOMOUS   FIRE-AND-FORGET"
    sb = d.textbbox((0, 0), subtitle, font=sub_font)
    sw = sb[2] - sb[0]
    d.text(((W - sw) / 2, H - 36), subtitle, font=sub_font, fill=INK)


def draw_hairlines(draw: ImageDraw.ImageDraw) -> None:
    draw.line([60, 14, W - 60, 14], fill=INK, width=1)
    draw.line([60, H - 14, W - 60, H - 14], fill=INK, width=1)


def render() -> None:
    img = Image.new("RGB", (W, H), PAPER)
    draw = ImageDraw.Draw(img)

    draw_hairlines(draw)
    draw_circle(draw, RING_INNER)
    draw_circle(draw, RING_PHASE)
    draw_circle(draw, RING_TICK)
    draw_circle(draw, RING_OUTER, width=2)

    draw_tick_ring(draw)
    draw_phase_markers(draw)
    draw_accent(draw)

    draw_phase_labels(img)

    draw_corner_plate(img)
    draw_display_word(img)

    out = "/Users/junhua/.claude/plugins/super-ralph/assets/teaser.png"
    img.save(out, "PNG", optimize=True)
    print(f"wrote {out} ({W}x{H})")


if __name__ == "__main__":
    render()
