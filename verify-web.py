"""Verifikasi web final v3: pakai screenshot PENUH + analisis piksel dari file
(clip screenshot terbukti stale di SwiftShader). Tunggu menu, klik MAIN,
drag B, drag P, cek overlay menang."""
import time
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent
CHROME = "/home/hatch/workspace/chrome-real/opt/google/chrome/chrome"
URL = "http://127.0.0.1:8931/index.html"
TMP = ROOT / "shots" / "_tmp.png"

def shot_pixel(page, x, y):
    page.screenshot(path=str(TMP))
    return Image.open(TMP).convert("RGB").getpixel((x, y))

def is_orange(px):
    r, g, b = px
    return r > 200 and 60 < g < 160 and b < 70

def drag(page, x0, y0, x1, y1, steps=6, pause=0.4):
    page.mouse.move(x0, y0)
    time.sleep(0.3)
    page.mouse.down()
    time.sleep(0.3)
    for i in range(1, steps + 1):
        page.mouse.move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
        time.sleep(pause)
    page.mouse.up()
    time.sleep(1.5)

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=CHROME, args=["--no-sandbox", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 720, "height": 1280}, has_touch=True)
    errs = []
    page.on("pageerror", lambda e: errs.append(str(e)))
    page.on("console", lambda m: errs.append(m.text) if m.type == "error" else None)
    page.goto(URL)
    page.wait_for_selector("canvas", timeout=30000)
    t0 = time.time()
    menu = False
    for i in range(12):
        time.sleep(8)
        px = shot_pixel(page, 150, 618)
        print(f"[{time.time()-t0:.0f}s] iter {i} pixel MAIN={px}", flush=True)
        if is_orange(px):
            menu = True
            break
    print("MENU:", menu, flush=True)
    page.screenshot(path=str(ROOT / "shots/web-menu.png"))
    if menu:
        page.mouse.move(360, 618)
        time.sleep(0.3)
        page.mouse.down()
        time.sleep(0.3)
        page.mouse.up()
        time.sleep(3)
        page.screenshot(path=str(ROOT / "shots/web-gameplay.png"))
        print("after MAIN pixel(400,400)=", shot_pixel(page, 400, 400), flush=True)
        drag(page, 510, 550, 510, 450)   # A motor biru ke atas 1 sel
        drag(page, 410, 550, 410, 750)   # C angkot hijau ke bawah 2 sel
        page.screenshot(path=str(ROOT / "shots/web-after-b.png"))
        print("after C drag pixel(410,550)=", shot_pixel(page, 410, 550), flush=True)
        drag(page, 160, 550, 719, 550)   # P mobil merah keluar
        time.sleep(2)
        page.screenshot(path=str(ROOT / "shots/web-win.png"))
        print("after P drag pixel(400,768)=", shot_pixel(page, 400, 768), "(oranye = BERIKUTNYA)", flush=True)
    print("ERRORS:", errs, flush=True)
    browser.close()
if TMP.exists():
    TMP.unlink()
print("DONE", flush=True)
