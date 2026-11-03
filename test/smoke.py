"""Smoke test: python3 test/smoke.py http://127.0.0.1:8080 out_dir
Overí: stránka sa načíta pod CSP, bez chýb v konzole, emulátor nabootuje ROM a reaguje na klávesnicu."""
import sys, pathlib
from playwright.sync_api import sync_playwright

base = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080"
out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "out"); out.mkdir(exist_ok=True)
problems = []

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1100, "height": 1000})
    pg.on("console", lambda m: problems.append(f"console.{m.type}: {m.text}") if m.type in ("error", "warning") else None)
    pg.on("pageerror", lambda e: problems.append(f"pageerror: {e}"))
    pg.on("requestfailed", lambda r: problems.append(f"requestfailed: {r.url} {r.failure}"))
    ext = []
    pg.on("request", lambda r: ext.append(r.url) if not r.url.startswith(base) and not r.url.startswith(("data:", "blob:")) else None)
    pg.add_init_script("document.addEventListener('securitypolicyviolation', e => console.error('CSP VIOLATION: ' + e.violatedDirective + ' ' + e.blockedURI));")
    resp = pg.goto(base + "/")
    print("status", resp.status)
    pg.wait_for_timeout(2500)
    pg.screenshot(path=str(out / "1-loaded.png"))
    print("status text:", pg.inner_text("#status"))
    # veľké tlačidlo play uprostred obrazovky (prehliadač povolí zvuk až po klik)
    box = pg.locator("#screen").bounding_box()
    pg.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
    pg.wait_for_timeout(3500)
    pg.screenshot(path=str(out / "2-booted.png"))
    # BASIC: PRINT "AHOJ"   (klávesy držíme ~80 ms, emulácia číta klávesnicu po snímkoch)
    def tap(k, ctrl=False):
        if ctrl: pg.keyboard.down("Control"); pg.wait_for_timeout(60)
        pg.keyboard.down(k); pg.wait_for_timeout(90); pg.keyboard.up(k)
        if ctrl: pg.wait_for_timeout(40); pg.keyboard.up("Control")
        pg.wait_for_timeout(120)
    pg.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
    pg.wait_for_timeout(300)
    tap("p")                     # PRINT
    tap("p", ctrl=True)          # "
    for k in "ahoj": tap(k)
    tap("p", ctrl=True)          # "
    tap("Enter"); pg.wait_for_timeout(600)
    pg.screenshot(path=str(out / "3-typed.png"))
    print("external requests:", ext)
    b.close()

print("PROBLEMS:", *(problems or ["žiadne"]), sep="\n  ")
