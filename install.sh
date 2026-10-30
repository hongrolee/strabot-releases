#!/usr/bin/env bash
# StraBot 리눅스 서버 설치 · 업데이트 (우분투 22.04+ · 데비안 12+, x86_64) — 한 줄로:
#   curl -fsSL https://strabot.mayai.kr/install.sh | sudo bash
# 하는 일: 최신 실행 파일 묶음 받기(GitHub strabot-releases) → 확인값(sha256) 검사 → /opt/strabot 에 놓기 → 전용 사용자 strabot →
#          대시보드 비밀번호 → systemd 서비스(꺼져도 · 재부팅해도 다시 켜짐) → `strabot` 명령 → 접속 주소 안내
# 이미 설치돼 있으면 프로그램만 새것으로 바꾸고 설정 · 기록(/var/lib/strabot)은 그대로 둡니다 (`strabot update` 가 이것을 씀).
# 2026-10-29: 소스(git clone) 대신 빌드된 실행 파일을 받습니다 — 파이썬 · git 이 필요 없어요.
# 바꿀 수 있는 값(환경 변수로): STRABOT_PORT(기본 5001) · STRABOT_DASHBOARD_PASSWORD(묻지 않고 이 값으로) · STRABOT_DOWNLOAD(받는 곳)
set -euo pipefail

DOWNLOAD="${STRABOT_DOWNLOAD:-https://github.com/hongrolee/strabot-releases/releases/latest/download}"
PKG=strabot-linux-x86_64.tar.gz
PORT="${STRABOT_PORT:-5001}"
APP_DIR=/opt/strabot
DATA_DIR=/var/lib/strabot
SVC_USER=strabot
ENV_FILE=/etc/strabot.env
UNIT=/etc/systemd/system/strabot.service

say()  { printf '\033[1;36m[StraBot]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[StraBot] %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "root 권한이 필요해요. 이렇게 실행해 주세요:  curl -fsSL https://strabot.mayai.kr/install.sh | sudo bash"
command -v systemctl >/dev/null || fail "systemd 가 있는 리눅스(우분투 · 데비안 등)에서만 설치할 수 있어요."
[ "$(uname -m)" = "x86_64" ] || fail "지금은 x86_64(인텔 · AMD) 서버만 지원해요. 이 서버는 $(uname -m) 이에요."

# ── 1. 패키지 (받기 · 풀기 · 확인에 쓰는 것만) ──
need=""
for c in curl tar sha256sum sudo; do command -v "$c" >/dev/null || need="$need $c"; done
if [ -n "$need" ]; then
    say "필요한 패키지를 설치해요:$need"
    export DEBIAN_FRONTEND=noninteractive
    if command -v apt-get >/dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl tar coreutils sudo ca-certificates >/dev/null
    elif command -v dnf >/dev/null; then
        dnf install -y -q curl tar coreutils sudo
    else
        fail "apt(우분투 · 데비안) 또는 dnf(페도라 계열)만 지원해요."
    fi
fi

# ── 2. 최신 프로그램 받기 · 확인 ──
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
say "최신 프로그램을 받아요"
curl -fsSL "$DOWNLOAD/$PKG" -o "$TMP/$PKG" || fail "프로그램을 받지 못했어요: $DOWNLOAD/$PKG"
curl -fsSL "$DOWNLOAD/$PKG.sha256" -o "$TMP/$PKG.sha256" || fail "확인값 파일을 받지 못했어요: $DOWNLOAD/$PKG.sha256"
(cd "$TMP" && sha256sum -c --status "$PKG.sha256") || fail "받은 파일이 확인값과 달라요. 설치하지 않았어요. 잠시 뒤 다시 해 주세요."
mkdir "$TMP/x"
tar -xzf "$TMP/$PKG" -C "$TMP/x"
[ -x "$TMP/x/StraBot/StraBot" ] || fail "받은 묶음 안에 실행 파일이 없어요."
VERSION=$(cat "$TMP/x/StraBot/VERSION" 2>/dev/null || echo "?")

# ── 3. 전용 사용자 · 폴더 ──
if ! id -u "$SVC_USER" >/dev/null 2>&1; then
    say "전용 사용자 '$SVC_USER' 를 만들어요 (로그인 불가, 봇은 이 사용자로 돌아요)"
    useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin "$SVC_USER"
fi
mkdir -p "$DATA_DIR"
chown "$SVC_USER:$SVC_USER" "$DATA_DIR"
chmod 700 "$DATA_DIR"
as_svc() { sudo -H -u "$SVC_USER" "$@"; }     # 봇 · 데이터는 전용 사용자 권한으로 (프로그램 파일은 root 소유 · 읽기 전용)

# ── 4. 프로그램 바꿔 끼우기 (돌고 있으면 끄고 바꾼 뒤 다시 켬) ──
WAS_RUNNING=0
systemctl is-active -q strabot 2>/dev/null && WAS_RUNNING=1
[ "$WAS_RUNNING" = 1 ] && { say "돌고 있는 StraBot 을 잠시 꺼요"; systemctl stop strabot; }
rm -rf "$APP_DIR.old"
[ -e "$APP_DIR" ] && mv "$APP_DIR" "$APP_DIR.old"
mv "$TMP/x/StraBot" "$APP_DIR"
chown -R root:root "$APP_DIR"
chmod -R a+rX,go-w "$APP_DIR"
rm -rf "$APP_DIR.old"
say "프로그램을 놓았어요: $APP_DIR (버전 $VERSION)"

# ── 5. 대시보드 비밀번호 (바깥에서 접속할 때 쓰는 것 · 거래소 키와는 다름) ──
if [ ! -f "$DATA_DIR/data/dashboard_auth.json" ]; then
    PW="${STRABOT_DASHBOARD_PASSWORD:-}"
    if [ -z "$PW" ]; then
        if [ -r /dev/tty ]; then
            while :; do
                printf '\n대시보드 비밀번호를 정해 주세요 (8자 이상, 브라우저로 접속할 때 씀): '
                read -r -s PW </dev/tty; echo
                printf '한 번 더: '
                read -r -s PW2 </dev/tty; echo
                [ "$PW" = "$PW2" ] && [ "${#PW}" -ge 8 ] && break
                echo "두 번이 다르거나 8자보다 짧아요. 다시 해 주세요."
            done
        else
            fail "비밀번호를 물어볼 수 없어요. STRABOT_DASHBOARD_PASSWORD='원하는비밀번호' 를 앞에 붙여 다시 실행해 주세요."
        fi
    fi
    (cd "$DATA_DIR" && as_svc env STRABOT_DATA_DIR="$DATA_DIR" STRABOT_DASHBOARD_PASSWORD="$PW" "$APP_DIR/StraBot" --set-password >/dev/null)
    unset PW PW2
    say "대시보드 비밀번호를 저장했어요"
else
    say "대시보드 비밀번호는 이미 있어요 (바꾸려면: strabot password)"
fi

# ── 6. 서비스 ──
if [ ! -f "$ENV_FILE" ]; then
    cat >"$ENV_FILE" <<EOF
# StraBot 서버 설정 (바꾼 뒤: systemctl restart strabot)
STRABOT_PORT=$PORT
STRABOT_HOST=0.0.0.0
EOF
    chmod 600 "$ENV_FILE"
fi
cat >"$UNIT" <<EOF
[Unit]
Description=StraBot (server mode) — 내가 정한 규칙대로 사고파는 자동매매
After=network-online.target
Wants=network-online.target

[Service]
User=$SVC_USER
Group=$SVC_USER
WorkingDirectory=$DATA_DIR
EnvironmentFile=$ENV_FILE
Environment=STRABOT_SERVER_MODE=1
Environment=STRABOT_DATA_DIR=$DATA_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$APP_DIR/StraBot --server
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=90

[Install]
WantedBy=multi-user.target
EOF
install -m 755 "$APP_DIR/strabot-cli" /usr/local/bin/strabot
systemctl daemon-reload
systemctl enable -q strabot
systemctl restart strabot

# ── 7. 방화벽 (ufw 를 쓰고 있으면 포트를 열어 줌) ──
# shellcheck source=/dev/null
PORT_NOW=$(. "$ENV_FILE"; echo "${STRABOT_PORT:-5001}")
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "$PORT_NOW/tcp" >/dev/null && say "방화벽(ufw)에서 $PORT_NOW 포트를 열었어요"
fi

# ── 8. 확인 · 안내 ──
for _ in $(seq 1 30); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$PORT_NOW/login" 2>/dev/null; then break; fi
    sleep 1
done
IP=$(curl -fsS -m 5 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
echo
say "설치가 끝났어요 (버전 $VERSION)."
echo "  접속 주소:  http://${IP:-서버IP}:$PORT_NOW   (브라우저에서 열고 정한 비밀번호로 로그인)"
echo "  상태 보기:  strabot status      로그: strabot logs"
echo "  업데이트:   strabot update      비밀번호 바꾸기: strabot password"
echo "  끄기/켜기:  strabot stop · strabot start · strabot restart"
echo
echo "  ※ 클라우드(Vultr · AWS 등)는 콘솔의 방화벽에서도 $PORT_NOW 포트를 열어야 해요."
echo "  ※ 업비트 API 키의 허용 IP 에 이 서버의 IP(${IP:-서버IP})를 넣어야 실제 주문이 나가요."
echo "  ※ https 로 쓰려면 Caddy 같은 프록시를 앞에 두세요 (안내: https://strabot.mayai.kr/linux)."
