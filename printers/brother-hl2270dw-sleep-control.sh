#!/usr/bin/env bash
#
# brother-hl2270dw-sleep-control.sh
#
# Query or change Brother printer sleep/power-save settings through PJL
# over TCP port 9100.
#
# Tested with a Brother HL-2270DW. It may work with other Brother laser
# printers that expose AUTOSLEEP and POWERSAVE through PJL.
#
# Requirements:
#   - bash
#   - python3
#   - Network access to the printer on TCP port 9100
#
# Usage:
#   ./brother-hl2270dw-sleep-control.sh status 192.168.1.50
#   ./brother-hl2270dw-sleep-control.sh disable 192.168.1.50
#   ./brother-hl2270dw-sleep-control.sh enable 192.168.1.50
#   ./brother-hl2270dw-sleep-control.sh timeout 192.168.1.50 210
#

set -euo pipefail

SCRIPT_NAME=${0##*/}
DEFAULT_PORT=9100

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME status  PRINTER_IP [PORT]
  $SCRIPT_NAME disable PRINTER_IP [PORT]
  $SCRIPT_NAME enable  PRINTER_IP [PORT]
  $SCRIPT_NAME timeout PRINTER_IP MINUTES [PORT]

Commands:
  status
      Show AUTOSLEEP, POWERSAVE, TIMEOUTSLEEP, and POWERSAVETIME.

  disable
      Persistently set:
        AUTOSLEEP=OFF
        POWERSAVE=OFF

  enable
      Persistently set:
        AUTOSLEEP=ON
        POWERSAVE=ON

  timeout
      Persistently set both sleep timers to MINUTES.
      The HL-2270DW reports a supported range of 0 through 210.
      Warning: on this model, 0 causes immediate sleep.

Examples:
  $SCRIPT_NAME status 192.168.6.17
  $SCRIPT_NAME disable 192.168.6.17
  $SCRIPT_NAME enable 192.168.6.17
  $SCRIPT_NAME timeout 192.168.6.17 210

Notes:
  - Changes are sent with PJL DEFAULT commands and should survive a power cycle.
  - The script does not print a page.
  - TCP port 9100 must be reachable.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || die "python3 is required."

[[ $# -ge 2 ]] || {
    usage
    exit 1
}

ACTION=$1
PRINTER_HOST=$2

case "$ACTION" in
    status|disable|enable)
        PORT=${3:-$DEFAULT_PORT}
        ;;
    timeout)
        [[ $# -ge 3 ]] || die "timeout requires a minute value."
        MINUTES=$3
        PORT=${4:-$DEFAULT_PORT}

        [[ "$MINUTES" =~ ^[0-9]+$ ]] ||
            die "Minutes must be a whole number."

        (( MINUTES >= 0 && MINUTES <= 210 )) ||
            die "Minutes must be between 0 and 210."

        if (( MINUTES == 0 )); then
            printf '%s\n' \
                'Warning: TIMEOUTSLEEP=0 causes immediate sleep on the HL-2270DW.' >&2
        fi
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        usage
        die "Unknown command: $ACTION"
        ;;
esac

[[ "$PORT" =~ ^[0-9]+$ ]] || die "Port must be numeric."
(( PORT >= 1 && PORT <= 65535 )) || die "Port must be between 1 and 65535."

export ACTION PRINTER_HOST PORT
export MINUTES=${MINUTES:-}

python3 <<'PY'
import os
import socket
import sys

host = os.environ["PRINTER_HOST"]
port = int(os.environ["PORT"])
action = os.environ["ACTION"]
minutes = os.environ.get("MINUTES", "")

UEL = b"\x1b%-12345X"

def transact(payload: bytes, expect_response: bool = False) -> bytes:
    try:
        with socket.create_connection((host, port), timeout=5) as sock:
            sock.settimeout(3)
            sock.sendall(payload)

            if not expect_response:
                return b""

            chunks = []
            while True:
                try:
                    chunk = sock.recv(65535)
                    if not chunk:
                        break
                    chunks.append(chunk)
                except socket.timeout:
                    break

            return b"".join(chunks)

    except OSError as exc:
        print(
            f"Unable to communicate with {host}:{port}: {exc}",
            file=sys.stderr,
        )
        raise SystemExit(1)

def query_status() -> dict[str, str]:
    response = transact(
        UEL + b"@PJL INFO VARIABLES\r\n" + UEL,
        expect_response=True,
    )

    text = response.decode("latin-1", errors="replace")
    wanted = {
        "AUTOSLEEP",
        "POWERSAVE",
        "TIMEOUTSLEEP",
        "POWERSAVETIME",
    }

    result: dict[str, str] = {}

    for line in text.splitlines():
        if "=" not in line:
            continue

        name, value = line.split("=", 1)
        name = name.strip()

        if name in wanted:
            result[name] = value.split("[", 1)[0].strip()

    return result

def send_defaults(commands: list[str]) -> None:
    body = bytearray(UEL)

    for command in commands:
        body.extend(f"@PJL DEFAULT {command}\r\n".encode("ascii"))

    body.extend(b"@PJL EOJ\r\n")
    body.extend(UEL)
    transact(bytes(body))

if action == "status":
    status = query_status()

    if not status:
        print(
            "The printer responded, but the expected PJL variables were not found.",
            file=sys.stderr,
        )
        raise SystemExit(2)

    for key in (
        "AUTOSLEEP",
        "TIMEOUTSLEEP",
        "POWERSAVE",
        "POWERSAVETIME",
    ):
        print(f"{key}={status.get(key, 'NOT REPORTED')}")

elif action == "disable":
    send_defaults([
        "AUTOSLEEP=OFF",
        "POWERSAVE=OFF",
    ])
    print("Sleep controls were disabled. Verifying...")
    status = query_status()

    for key in ("AUTOSLEEP", "POWERSAVE"):
        print(f"{key}={status.get(key, 'NOT REPORTED')}")

    if status.get("AUTOSLEEP") != "OFF" or status.get("POWERSAVE") != "OFF":
        print(
            "The printer did not confirm both settings as OFF.",
            file=sys.stderr,
        )
        raise SystemExit(3)

elif action == "enable":
    send_defaults([
        "AUTOSLEEP=ON",
        "POWERSAVE=ON",
    ])
    print("Sleep controls were enabled. Verifying...")
    status = query_status()

    for key in ("AUTOSLEEP", "POWERSAVE"):
        print(f"{key}={status.get(key, 'NOT REPORTED')}")

    if status.get("AUTOSLEEP") != "ON" or status.get("POWERSAVE") != "ON":
        print(
            "The printer did not confirm both settings as ON.",
            file=sys.stderr,
        )
        raise SystemExit(3)

elif action == "timeout":
    send_defaults([
        f"TIMEOUTSLEEP={minutes}",
        f"POWERSAVETIME={minutes}",
    ])
    print(f"Sleep timers were set to {minutes} minute(s). Verifying...")
    status = query_status()

    for key in ("TIMEOUTSLEEP", "POWERSAVETIME"):
        print(f"{key}={status.get(key, 'NOT REPORTED')}")

    if (
        status.get("TIMEOUTSLEEP") != minutes
        or status.get("POWERSAVETIME") != minutes
    ):
        print(
            "The printer did not confirm both timeout values.",
            file=sys.stderr,
        )
        raise SystemExit(3)
PY
