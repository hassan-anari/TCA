#!/usr/bin/env python3
"""Procedural texture + environment generator for the Memoria Phase 00 prototype.

Deterministic (fixed seeds). Produces:
  build/nebula_equirect.hdr   -> input for Filament cmgen (skybox + IBL KTX)
  textures/veil_*.png         -> soft nebula veil sprites used by Blender models
  textures/glow.png           -> radial glow sprite

Only numpy + Pillow are required. No external/proprietary imagery is used.
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "textures")
BUILD = os.path.join(HERE, "build")
os.makedirs(TEX, exist_ok=True)
os.makedirs(BUILD, exist_ok=True)


def hex_lin(h):
    h = h.lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


class Noise3:
    """Seeded 3D value noise with smooth interpolation (vectorised)."""

    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        self.perm = rng.permutation(256).astype(np.int64)
        self.perm = np.concatenate([self.perm, self.perm])
        self.vals = rng.random(256)

    def _h(self, x, y, z):
        p = self.perm
        return self.vals[p[p[p[x & 255] + (y & 255)] + (z & 255)]]

    def __call__(self, pts):
        x, y, z = pts[..., 0], pts[..., 1], pts[..., 2]
        xi, yi, zi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
        xf, yf, zf = x - xi, y - yi, z - zi
        u, v, w = [t * t * (3 - 2 * t) for t in (xf, yf, zf)]
        acc = 0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    wgt = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                    acc = acc + wgt * self._h(xi + dx, yi + dy, zi + dz)
        return acc * 2 - 1

    def fbm(self, pts, octaves=6, lac=2.0, gain=0.5):
        s, a, f, norm = 0, 0.5, 1.0, 0
        for i in range(octaves):
            s = s + a * self(pts * f + i * 17.31)
            norm += a
            a *= gain
            f *= lac
        return s / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def write_hdr(path, img):
    """Write float32 RGB image as Radiance RGBE (.hdr), uncompressed scanlines."""
    h, w, _ = img.shape
    img = np.maximum(img, 0).astype(np.float64)
    m = img.max(axis=2)
    e = np.zeros_like(m, dtype=np.int64)
    mant = np.zeros_like(m)
    nz = m > 1e-32
    mant[nz], e[nz] = np.frexp(m[nz])
    scale = np.zeros_like(m)
    scale[nz] = mant[nz] * 256.0 / m[nz]
    rgbe = np.zeros((h, w, 4), dtype=np.uint8)
    rgbe[..., :3] = np.clip(img * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(nz, e + 128, 0).astype(np.uint8)
    with open(path, "wb") as f:
        f.write(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n")
        f.write(f"-Y {h} +X {w}\n".encode())
        f.write(rgbe.tobytes())


def nebula_equirect(w=1024, h=512, seed=7):
    n1, n2, n3 = Noise3(seed), Noise3(seed + 1), Noise3(seed + 2)
    v, u = np.meshgrid((np.arange(h) + 0.5) / h, (np.arange(w) + 0.5) / w, indexing="ij")
    phi = (u - 0.5) * 2 * np.pi
    theta = v * np.pi
    d = np.stack([np.sin(theta) * np.sin(phi), np.cos(theta), np.sin(theta) * np.cos(phi)], -1)
    deep = hex_lin("#071417")
    teal = hex_lin("#10282B")
    mist = hex_lin("#547779")
    sage = hex_lin("#8FA8A6")
    glow = hex_lin("#E5C5AE")
    blush = hex_lin("#D6A39F")
    # Base vertical gradient: slightly lighter toward a diagonal band (galactic plane feel)
    band_axis = np.array([0.35, 0.85, -0.2]); band_axis /= np.linalg.norm(band_axis)
    band = 1 - np.abs(d @ band_axis)
    base = deep[None, None] * (1 - band[..., None]) + teal[None, None] * band[..., None]
    # Domain-warped fbm gives wispy, layered nebula structure instead of blobs.
    warp = np.stack([n3.fbm(d * 1.7 + 3.1, 4), n3.fbm(d * 1.7 + 7.7, 4), n3.fbm(d * 1.7 + 1.3, 4)], -1)
    dw = d * 1.8 + warp * 1.2
    c1 = smoothstep(-0.25, 0.65, n1.fbm(dw, 6)) ** 1.6  # broad cool clouds
    c2 = smoothstep(-0.1, 0.7, n2.fbm(dw * 1.4 + 4.0, 6)) ** 1.8 * smoothstep(0.2, 0.95, band)  # warm veil near band
    c3 = 0.5 + 0.5 * n3.fbm(d * 7.0 + warp * 2.0, 5)  # fine wisps / texture
    img = base
    img = img + (mist * 0.38)[None, None] * (c1 * (0.6 + 0.6 * c3))[..., None]
    img = img + (sage * 0.12)[None, None] * (c1 * c3 * c3)[..., None]
    img = img + (glow * 0.55)[None, None] * (c2 * (0.5 + 0.7 * c3))[..., None]
    img = img + (blush * 0.35)[None, None] * (c2 * c3)[..., None]
    # Broad, soft warm key region (no visible disc) gives the IBL a warm direction.
    sun = np.array([0.6, 0.35, 0.7]); sun /= np.linalg.norm(sun)
    s = np.clip(d @ sun, 0, 1)
    img = img + (glow * 0.35)[None, None] * (s ** 4)[..., None] + (glow * 1.2)[None, None] * (s ** 40)[..., None]
    return (img * 0.9).astype(np.float32)


def veil(seed, color_a, color_b, size=512):
    n = Noise3(seed)
    y, x = np.meshgrid(np.linspace(-1, 1, size), np.linspace(-1, 1, size), indexing="ij")
    pts = np.stack([x * 2.0, y * 2.0, np.full_like(x, seed * 0.37)], -1)
    f = n.fbm(pts, 6)
    f2 = n.fbm(pts * 2.3 + 9.0, 5)
    r = np.sqrt(x * x + y * y)
    fall = smoothstep(1.0, 0.25, r)
    dens = smoothstep(-0.05, 0.55, f) * fall
    a = np.clip(dens * (0.6 + 0.4 * f2), 0, 1)
    ca, cb = np.array(color_a), np.array(color_b)
    mix = smoothstep(-0.3, 0.5, f2)[..., None]
    rgb = ca * (1 - mix) + cb * mix
    out = np.concatenate([rgb, a[..., None]], -1)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def glow(size=128):
    y, x = np.meshgrid(np.linspace(-1, 1, size), np.linspace(-1, 1, size), indexing="ij")
    r = np.sqrt(x * x + y * y)
    a = np.clip(1 - r, 0, 1) ** 2.2
    out = np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def srgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def sample_photos(out_dir, w=640, h=480):
    """Procedural stand-ins for user photo attachments (no stock imagery)."""
    os.makedirs(out_dir, exist_ok=True)
    y, x = np.meshgrid(np.linspace(0, 1, h), np.linspace(0, 1, w), indexing="ij")
    n = Noise3(99)
    # 1. sunset over calm water
    t = np.clip(y / 0.56, 0, 1)[..., None]
    sky = np.array([0.42, 0.50, 0.55]) * (1 - t) + np.array([0.96, 0.78, 0.62]) * t
    sky = np.clip(sky, 0, 1)
    sun = np.exp(-(((x - 0.55) ** 2) / 0.004 + ((y - 0.52) ** 2) / 0.004))[..., None]
    horizon = 0.56
    water = y > horizon
    img = sky * (1 - 0.0) + sun * np.array([1.0, 0.9, 0.7])
    ripple = 0.5 + 0.5 * np.sin((y - horizon) * 260 + n(np.stack([x * 8, y * 40, np.zeros_like(x)], -1)) * 4)
    wcol = np.stack([0.55 + 0.25 * ripple * (1 - (y - horizon) * 2), 0.42 + 0.15 * ripple, 0.45 + 0.1 * ripple], -1)
    refl = np.exp(-((x - 0.55) ** 2) / 0.003)[..., None] * (ripple[..., None] * 0.6)
    img = np.where(water[..., None], np.clip(wcol + refl * np.array([1, 0.85, 0.6]), 0, 1), img)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, "sample_sunset.jpg"), quality=86)
    # 2. misty layered mountains
    img = np.stack([0.80 + 0.1 * y, 0.84 + 0.06 * y, 0.84 + 0.02 * y], -1)
    for k, (base, amp, col) in enumerate([(0.45, 0.12, (0.62, 0.70, 0.72)), (0.58, 0.1, (0.45, 0.55, 0.58)),
                                          (0.72, 0.08, (0.30, 0.40, 0.42))]):
        ridge = base - amp * (0.5 + 0.5 * n(np.stack([x * (3 + k), np.full_like(x, k * 3.3), np.zeros_like(x)], -1)))
        mask = (y > ridge)[..., None]
        img = np.where(mask, np.array(col), img)
        mist = np.exp(-((y - ridge - 0.05) ** 2) / 0.004)[..., None] * 0.14
        img = np.clip(img + mist, 0, 1)
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(out_dir, "sample_mountains.jpg"), quality=86)
    # 3. blossom bokeh
    rng = np.random.default_rng(5)
    img = np.stack([0.30 + 0.3 * y, 0.38 + 0.2 * y, 0.36 + 0.1 * y], -1)
    for i in range(70):
        cx, cy, r = rng.random(), rng.random(), rng.uniform(0.02, 0.09)
        col = np.array([rng.uniform(0.9, 1.0), rng.uniform(0.65, 0.8), rng.uniform(0.72, 0.85)])
        d = np.sqrt((x - cx) ** 2 * (w / h) ** 2 + (y - cy) ** 2)
        a = smoothstep(r, r * 0.8, d)[..., None] * rng.uniform(0.25, 0.6)
        img = img * (1 - a) + col * a
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out_dir, "sample_blossom.jpg"), quality=86)


if __name__ == "__main__":
    write_hdr(os.path.join(BUILD, "nebula_equirect.hdr"), nebula_equirect())
    veil(11, srgb("#547779"), srgb("#C4D0C9")).save(os.path.join(TEX, "veil_teal.png"), optimize=True)
    veil(23, srgb("#E5C5AE"), srgb("#D6A39F")).save(os.path.join(TEX, "veil_amber.png"), optimize=True)
    veil(37, srgb("#D6A39F"), srgb("#8FA8A6")).save(os.path.join(TEX, "veil_rose.png"), optimize=True)
    glow().save(os.path.join(TEX, "glow.png"), optimize=True)
    # Preview of the equirect (tone-mapped) for documentation
    img = nebula_equirect(512, 256)
    tm = img / (1 + img)
    tm = np.where(tm <= 0.0031308, tm * 12.92, 1.055 * tm ** (1 / 2.4) - 0.055)
    Image.fromarray((np.clip(tm, 0, 1) * 255).astype(np.uint8)).save(os.path.join(BUILD, "nebula_preview.png"))
    sample_photos(os.path.join(HERE, "..", "..", "assets", "images"))
    print("textures ok")
