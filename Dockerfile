# syntax=docker/dockerfile:1

# ---------- 1) build JSSpeccy 3 zo zdroja (pinnuté, overené hashom) ----------
FROM node:22-alpine AS build
ARG JSSPECCY_VERSION=3.2.0
ARG JSSPECCY_SHA512=bfc1c98a6aeec034dfc468dc36d232e42cf0ce91113552cdf80711b6885408363d30b11980f0b196b9b3df791f19577edc4f5c3b523c74937e45c0c80e54899c
WORKDIR /work
RUN npm pack "jsspeccy@${JSSPECCY_VERSION}" --silent \
 && echo "${JSSPECCY_SHA512}  jsspeccy-${JSSPECCY_VERSION}.tgz" | sha512sum -c - \
 && mkdir src \
 && tar xzf "jsspeccy-${JSSPECCY_VERSION}.tgz" -C src --strip-components=1
# lockfile pripne aj build závislosti (webpack, assemblyscript...)
COPY jsspeccy-build/package-lock.json src/package-lock.json
WORKDIR /work/src
# npm-watch (len "npm run watch" pri vývoji) ťahá nodemon/minimatch/semver so známymi advisories;
# na build netreba -> vyhodiť z package.json (lockfile je vygenerovaný bez neho)
RUN npm pkg delete devDependencies.npm-watch
RUN npm ci --ignore-scripts --no-audit --no-fund \
 && mkdir -p build dist \
 && npm run build:release \
 && rm -f dist/jsspeccy/*.map

# ---------- 2) runtime: nginx bez root práv ----------
# Oficiálny nginx:stable-alpine (nginxinc/nginx-unprivileged sa od 10/2026 neprestavuje a ostal na zraniteľnej 1.30.6).
# Beh bez root práv nastavíme rovnako ako nginx-unprivileged: bez `user`, pid a temp súbory v /tmp (kontajner je read_only + tmpfs /tmp).
FROM nginx:stable-alpine
RUN apk upgrade --no-cache \
 && rm -f /etc/nginx/conf.d/default.conf \
 && sed -i '/^user /d' /etc/nginx/nginx.conf \
 && sed -i 's,/run/nginx.pid,/tmp/nginx.pid,; s,/var/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
 && sed -i '/^http {/a \    proxy_temp_path /tmp/proxy_temp;\n    client_body_temp_path /tmp/client_temp;\n    fastcgi_temp_path /tmp/fastcgi_temp;\n    uwsgi_temp_path /tmp/uwsgi_temp;\n    scgi_temp_path /tmp/scgi_temp;' /etc/nginx/nginx.conf \
 && chown -R 101:0 /var/cache/nginx && chmod -R g+w /var/cache/nginx
USER 101
# bez application/wasm v mime.types by sa emulátor nespustil -> radšej zlyhať pri builde
RUN grep -q 'application/wasm' /etc/nginx/mime.types
COPY --chown=0:0 nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --chown=0:0 site/ /usr/share/nginx/html/
COPY --from=build --chown=0:0 /work/src/dist/jsspeccy/ /usr/share/nginx/html/jsspeccy/
# GPL-3.0: licencia + odkaz na zdroj sú súčasťou obrazu
COPY --from=build --chown=0:0 /work/src/COPYING /usr/share/nginx/html/licence/COPYING.txt
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
