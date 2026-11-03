# Didaktik M — emulátor (ZX Spectrum 48K) v prehliadači

Statická stránka okolo [JSSpeccy 3](https://github.com/gasman/jsspeccy3) (GPL-3.0). Emulátor sa **zbuilduje zo zdroja
priamo v Docker builde** z pinnutej verzie (3.2.0, overená SHA-512 + lockfile), výsledok beží v `nginx-unprivileged`.
Žiadne tajomstvá, žiadna databáza, žiadne uploady na server (súbory hier sa čítajú len v prehliadači).

> Didaktik M je programovo kompatibilný so ZX Spectrom 48K. Vlastné ROM a diskový systém Didaktiku tu **nie sú** emulované.
> Žiadne hry nie sú súčasťou projektu (autorské práva).

## Štruktúra
```
Dockerfile                 build JSSpeccy (node) -> nginx-unprivileged (uid 101, port 8080)
docker-compose.yml         hardening: read_only, cap_drop ALL, no-new-privileges, pids/mem limit, healthcheck
nginx/default.conf         CSP, security hlavičky, len GET/HEAD, /healthz, rate limit
site/                      index.html, style.css, app.js (bez inline skriptov a štýlov, bez externých fontov)
jsspeccy-build/            package-lock.json pre reprodukovateľný build emulátora
test/smoke.py              Playwright: načítanie pod CSP, boot ROM, písanie na klávesnici
```

## Nasadenie cez Coolify (kocka)
1. Repo `systemfifteen/didaktik-m`. Je bez tajomstiev, takže **public repo** je najjednoduchšie (funguje s existujúcou
   „Public GitHub" appkou, netreba deploy key). Ak chceš private: deploy key pridať **iba cez web GitHubu**, read-only.
2. Coolify -> nový resource -> **Docker Compose** (Compose Location `/docker-compose.yml`, vetva `main`).
3. Doména pre službu `didaktik`: `https://didaktik.system15.win`, port 8080 (nginx v kontajneri) sa zadáva zvlášť (Ports Exposes).
   DNS záznam už máš. Traefik + Let's Encrypt zariadi Coolify.
4. Žiadne env premenné ani storage nepridávať. Deploy.

### Overenie po nasadení
```bash
curl -sI https://didaktik.system15.win/ | egrep -i 'HTTP|content-security|strict-transport'
C=$(docker ps --filter name=didaktik -q | head -1)
docker inspect -f 'ro={{.HostConfig.ReadonlyRootfs}} user={{.Config.User}} capdrop={{.HostConfig.CapDrop}} sec={{.HostConfig.SecurityOpt}} health={{.State.Health.Status}}' $C
docker exec $C id        # čakáme uid=101, nie root
python3 test/smoke.py https://didaktik.system15.win ./out   # voliteľne z PC
```

### Rollback
Coolify -> Deployments -> redeploy predchádzajúceho commitu, alebo resource zastaviť. Nič perzistentné sa nemení.

## Aktualizácia emulátora
V `Dockerfile` zmeň `JSSPECCY_VERSION` + `JSSPECCY_SHA512` (`npm view jsspeccy@X dist.integrity` alebo `sha512sum` tarballu),
regeneruj `jsspeccy-build/package-lock.json` (rozbaľ balík, `npm install --package-lock-only --ignore-scripts`, skopíruj lock) a spusti `test/smoke.py`.

## Poznámky k bezpečnosti
- CSP: `default-src 'none'`, skripty/štýly len z vlastného originu, `'wasm-unsafe-eval'` kvôli WebAssembly jadru emulátora; bez externých požiadaviek.
- Nepoužívať v `server{}` vlastný blok `types {}` – prepíše všetky MIME typy (JS/CSS by išli ako `octet-stream` a `nosniff` ich zablokuje).
- Základné obrazy sú pinnuté na tag (`node:22-alpine`, `nginx-unprivileged:1.27-alpine`), nie na digest. Pre prísnejší supply-chain pinning doplniť digesty.
- Verejná stránka bez prihlásenia (obsah je neškodný). Ak chceš SSO, pridať tinyauth middleware v Coolify rovnako ako pri ostatných `*.system15.win`.
