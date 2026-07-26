# Brother HL-2270DW Sleep Control via PJL

This script controls hidden sleep and power-save settings on a Brother HL-2270DW printer by sending PJL commands directly to TCP port 9100.

Brother’s web interface exposes a hidden `AUTOSLEEP` control, but on this model the normal web form does not save it. The printer does, however, expose the same settings through PJL, and PJL changes made with `@PJL DEFAULT` persist across a power cycle.

## Script

```text
brother-hl2270dw-sleep-control.sh
```

## Tested Printer

- Brother HL-2270DW
- Network firmware observed during testing:

```text
Brother NC-8200h, Firmware Ver.1.11 (18.12.27), MID 84UC07
```

The script may also work with other Brother laser printers that expose the same PJL variables.

## Requirements

- Linux, macOS, WSL, or another environment with Bash
- Python 3
- Network access to the printer
- TCP port 9100 enabled and reachable

No Brother driver is required.

## Installation

Download the script, then make it executable:

```bash
chmod +x brother-hl2270dw-sleep-control.sh
```

Optionally install it system-wide:

```bash
install -m 0755 \
  brother-hl2270dw-sleep-control.sh \
  /usr/local/bin/brother-sleep-control
```

## Usage

### Show current settings

```bash
./brother-hl2270dw-sleep-control.sh status PRINTER_IP
```

Example:

```bash
./brother-hl2270dw-sleep-control.sh status 192.168.6.17
```

Expected output may resemble:

```text
AUTOSLEEP=OFF
TIMEOUTSLEEP=210
POWERSAVE=OFF
POWERSAVETIME=210
```

### Disable sleep and power save

```bash
./brother-hl2270dw-sleep-control.sh disable PRINTER_IP
```

Example:

```bash
./brother-hl2270dw-sleep-control.sh disable 192.168.6.17
```

This persistently sets:

```text
AUTOSLEEP=OFF
POWERSAVE=OFF
```

### Re-enable sleep and power save

```bash
./brother-hl2270dw-sleep-control.sh enable PRINTER_IP
```

Example:

```bash
./brother-hl2270dw-sleep-control.sh enable 192.168.6.17
```

This persistently sets:

```text
AUTOSLEEP=ON
POWERSAVE=ON
```

### Set the sleep timeout

```bash
./brother-hl2270dw-sleep-control.sh timeout PRINTER_IP MINUTES
```

Example:

```bash
./brother-hl2270dw-sleep-control.sh timeout 192.168.6.17 210
```

This sets both:

```text
TIMEOUTSLEEP=210
POWERSAVETIME=210
```

The HL-2270DW reports a supported range of `0` through `210` minutes.

## Important Warning About Zero

On the HL-2270DW:

```text
TIMEOUTSLEEP=0
```

means **sleep immediately**, not “disable sleep.”

Do not use `0` unless immediate sleep is actually desired.

## Custom Port

The default PJL port is TCP 9100.

A different port may be supplied as the final argument.

Examples:

```bash
./brother-hl2270dw-sleep-control.sh status 192.168.6.17 9100
```

```bash
./brother-hl2270dw-sleep-control.sh disable 192.168.6.17 9100
```

```bash
./brother-hl2270dw-sleep-control.sh timeout 192.168.6.17 210 9100
```

## Verify Port 9100

Use `nmap`:

```bash
nmap -Pn -sT -p 9100 PRINTER_IP
```

Expected result:

```text
9100/tcp open  jetdirect
```

Or use `nc`:

```bash
nc -vz -w 5 PRINTER_IP 9100
```

## Persistence Test

After disabling sleep:

```bash
./brother-hl2270dw-sleep-control.sh disable 192.168.6.17
```

Power the printer off, wait several seconds, and power it back on.

Then query it again:

```bash
./brother-hl2270dw-sleep-control.sh status 192.168.6.17
```

The settings should still report:

```text
AUTOSLEEP=OFF
POWERSAVE=OFF
```

## Hidden PJL Variables

The printer reports the following relevant PJL variables:

```text
AUTOSLEEP=ON|OFF
TIMEOUTSLEEP=0..210
POWERSAVE=ON|OFF
POWERSAVETIME=0..210
```

The script changes persistent defaults using commands equivalent to:

```text
@PJL DEFAULT AUTOSLEEP=OFF
@PJL DEFAULT POWERSAVE=OFF
```

## Why the Web Interface Does Not Work

The printer’s protected web interface contains this commented-out include:

```html
<!--CommentOut #exec cgi="/cgi/host/Powersave" -->
```

The hidden CGI endpoint returns:

```html
<INPUT TYPE="radio" NAME="AUTOSLEEP" VALUE="ON">On
<INPUT TYPE="radio" NAME="AUTOSLEEP" VALUE="OFF">Off
```

However, submitting `AUTOSLEEP=OFF` through the normal web form does not persist the setting on the HL-2270DW.

PJL does persist it.

In other words, the switch exists, the web interface knows about it, and Brother still decided you were not worthy. PJL disagrees.

## Safety

The script:

- Does not print a test page
- Does not reset the printer
- Does not change network settings
- Does not require administrator credentials
- Only sends PJL commands to TCP port 9100
- Verifies the reported values after changes

Avoid experimenting with undocumented startup button sequences unless you have the exact service procedure. Some Brother startup sequences reset network settings or other printer defaults.

## Troubleshooting

### Connection refused or timed out

Confirm the printer is online and port 9100 is open:

```bash
nc -vz -w 5 PRINTER_IP 9100
```

### Expected PJL variables are not reported

The printer may not support these Brother-specific PJL settings.

Run:

```bash
./brother-hl2270dw-sleep-control.sh status PRINTER_IP
```

If the script reports that the expected variables were not found, do not assume the model is compatible.

### Settings do not persist

Make sure the script reports successful verification after the change.

Then power-cycle the printer and run the `status` command again.

### Printer sleeps immediately

Check whether the timeout was set to zero:

```bash
./brother-hl2270dw-sleep-control.sh status PRINTER_IP
```

Restore the maximum documented timeout:

```bash
./brother-hl2270dw-sleep-control.sh timeout PRINTER_IP 210
```

Then disable sleep again:

```bash
./brother-hl2270dw-sleep-control.sh disable PRINTER_IP
```

## Disclaimer

This is an unofficial community workaround and is not provided or supported by Brother Industries.

Use it at your own risk, especially on models other than the HL-2270DW.
