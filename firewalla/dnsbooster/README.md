# Firewalla DNS Booster CLI

A command-line utility for controlling Firewalla DNS Booster without having to toggle DNS Booster individually for every device in the Firewalla app.

This was developed by examining Firewalla's internal Redis policy storage and policy event system, then testing the network-level behavior on a running Firewalla.

## Why This Exists

Firewalla normally exposes DNS Booster as a per-device checkbox in the app.

On a network with a lot of devices, disabling DNS Booster one device at a time gets old very quickly.

Firewalla also supports a DNS Booster policy at the **network level**, even though this is not exposed in the GUI in the same way.

This utility provides commands such as:

```text
dnsbooster status
dnsbooster net-off br0
dnsbooster net-on br0
dnsbooster devices-off
dnsbooster devices-on
dnsbooster gui-off
dnsbooster gui-on
dnsbooster all-off br0
dnsbooster all-on br0
```

The most useful command is:

```bash
dnsbooster all-off br0
```

This does two things:

1. Disables DNS Booster for the entire `br0` network.
2. Explicitly disables DNS Booster for every device Firewalla currently knows about.

The network-wide policy is the important part. It means **new devices also bypass DNS Booster automatically**, even if their individual DNS Booster checkbox initially appears checked in the Firewalla app.

---

# Tested Environment

Originally developed and tested on:

```text
Firewalla branch: beta_6_0
Commit:           db737fdf37b20a107ed03cd4aae76e9b592f873b
Version:          v1.965-16306-gdb737fdf3
```

Primary LAN during testing:

```text
Interface: br0
Network:   192.168.0.0/21
Gateway:   192.168.0.1
```

The utility does **not** hardcode the network UUID. It discovers the correct Firewalla network UUID from the interface name.

Last verified:

```text
2026-08-21
```

---

# Warning

This uses Firewalla's **internal Redis database and internal policy notification mechanism**.

This is not a documented Firewalla user-facing API.

Firewalla may change:

- Redis key names
- policy structure
- event channel names
- ipset names
- DNS Booster implementation

in future releases.

Always verify operation after a major Firewalla update.

The script intentionally uses Firewalla's persistent policy storage rather than simply modifying ipsets directly. The ipsets are treated as the resulting enforcement state rather than the source of truth.

---

# How Firewalla DNS Booster Works

Firewalla represents DNS Booster internally as part of a `dnsmasq` policy.

The effective property is:

```json
{
  "dnsCaching": true
}
```

or:

```json
{
  "dnsCaching": false
}
```

Despite the name `dnsCaching`, this property controls what the Firewalla GUI calls **DNS Booster**.

## Device-Level Policy

For an individual device, the policy is stored in Redis under:

```text
policy:mac:<MAC-ADDRESS>
```

For example:

```text
policy:mac:92:CE:94:96:87:71
```

The `dnsmasq` field may contain:

```json
{"dnsCaching":false}
```

When DNS Booster is disabled for that device, Firewalla adds the MAC address to:

```text
no_dns_caching_mac_set
```

The script publishes a policy-change message on:

```text
Host:PolicyChanged
```

so the running Firewalla policy engine applies the change normally.

---

# Network-Level Policy

Firewalla networks are stored under:

```text
network:uuid:<UUID>
```

Network policy is stored under:

```text
policy:network:<UUID>
```

For example, the tested `br0` network had:

```text
UUID:
d2d01b44-4309-4057-961a-25ce9358d917
```

The script discovers this automatically.

Setting:

```json
{"dnsCaching":false}
```

on the network causes Firewalla to add that network's IPv4 and IPv6 ipsets to:

```text
no_dns_caching_set
```

For the test network, Firewalla created these memberships:

```text
c_net_d2d01b44-4309_set
c_net_d2d01b44-4309_set6
c_net_ll6_d2d01b44-4309_set6
```

This was verified directly after applying the network policy.

The script publishes:

```text
Network:PolicyChanged
```

after updating Redis so Firewalla applies the policy through its normal policy engine.

---

# Network Policy vs. Device Checkbox

This distinction is important.

Assume the entire `br0` network has:

```json
{"dnsCaching":false}
```

but a newly discovered device has no individual DNS Booster policy.

The Firewalla app may display:

```text
DNS Booster: ☑
```

for that device.

However, DNS Booster is **still bypassed** because the entire network is already contained in Firewalla's `no_dns_caching_set`.

In other words:

```text
New device
    |
    +-- Individual setting defaults to ON / checked
    |
    +-- Device belongs to br0
                     |
                     +-- br0 DNS Booster policy = OFF
                                      |
                                      +-- DNS Booster bypassed
```

The device checkbox therefore does not override the network-level bypass.

Running:

```bash
dnsbooster devices-off
```

or:

```bash
dnsbooster gui-off
```

sets the individual policy to false as well, making all currently known devices appear unchecked.

A device discovered later may again appear checked, but it is still functionally bypassed by the network policy.

Rerun:

```bash
dnsbooster gui-off
```

whenever you want the GUI to match the network-wide configuration.

---

# Requirements

The following commands must be available on the Firewalla:

```text
redis-cli
jq
ipset
```

Check with:

```bash
command -v redis-cli
command -v jq
command -v ipset
```

On the system used during development they were already installed.

---

# Repository Layout

A suggested toolbox layout is:

```text
firewalla/
└── dnsbooster/
    ├── README.md
    ├── dnsbooster
    └── 10-dnsbooster-command.sh
```

The main script is:

```text
dnsbooster
```

The startup helper is:

```text
10-dnsbooster-command.sh
```

---

# Installation

SSH into the Firewalla.

For example:

```bash
ssh pi@firewalla
```

Become root:

```bash
sudo -i
```

Create the Firewalla persistent custom-script directory if necessary:

```bash
mkdir -p /home/pi/.firewalla/config/post_main.d
```

## Install the Main Command

Copy the repository's `dnsbooster` file to:

```bash
cp dnsbooster /home/pi/.firewalla/config/dnsbooster
```

Set permissions:

```bash
chmod 755 /home/pi/.firewalla/config/dnsbooster
```

Create the convenient system command:

```bash
ln -sf \
    /home/pi/.firewalla/config/dnsbooster \
    /usr/local/bin/dnsbooster
```

## Install the Persistence Helper

Copy:

```bash
cp 10-dnsbooster-command.sh \
    /home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh
```

Set permissions:

```bash
chmod 755 \
    /home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh
```

The persistent files should now be:

```text
/home/pi/.firewalla/config/dnsbooster

/home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh
```

The interactive command is:

```text
/usr/local/bin/dnsbooster
```

Verify:

```bash
command -v dnsbooster
```

Expected:

```text
/usr/local/bin/dnsbooster
```

---

# Initial Status

Before changing anything:

```bash
dnsbooster status
```

Or inspect only one network:

```bash
dnsbooster status br0
```

Example:

```text
br0  192.168.0.1/21
  UUID:                 d2d01b44-4309-4057-961a-25ce9358d917
  Stored policy:        OFF
  Network bypass IPset: YES

Devices

  Known:                       86
  Explicitly OFF / unchecked: 58
  Explicitly ON / checked:    0
  Unset (default ON):          28
  Invalid policy JSON:         0
  Currently in bypass IPset:   44
```

Do not expect:

```text
Currently in bypass IPset
```

to always equal:

```text
Explicitly OFF / unchecked
```

Firewalla may retain policy for offline or stale devices that do not currently have an active enforcement object.

Redis policy is the persistent state.

The ipset is the currently applied enforcement state.

---

# Recommended Setup

For a network where DNS Booster should never be used:

```bash
dnsbooster all-off br0
```

Wait several seconds and verify:

```bash
dnsbooster status br0
```

This creates two layers of protection:

```text
Network policy
    DNS Booster OFF
         |
         +---- Covers every current device
         |
         +---- Covers every future device

Device policies
    DNS Booster OFF
         |
         +---- Makes current device checkboxes unchecked
```

---

# Network-Only Disable

To disable DNS Booster for every device on a network:

```bash
dnsbooster net-off br0
```

This is enough to functionally disable DNS Booster.

Verify:

```bash
dnsbooster status br0
```

Expected:

```text
Stored policy:        OFF
Network bypass IPset: YES
```

A newly discovered device may still appear with its individual DNS Booster checkbox checked.

That does **not** mean DNS Booster is active for that device.

The network-wide bypass still applies.

---

# Make Every Device Unchecked

To explicitly turn DNS Booster off on every currently known Firewalla device:

```bash
dnsbooster devices-off
```

Equivalent alias:

```bash
dnsbooster gui-off
```

After several seconds:

```bash
dnsbooster status
```

The goal is:

```text
Explicitly OFF / unchecked: <all known devices>
Explicitly ON / checked:    0
Unset (default ON):          0
```

Refresh or reopen the Firewalla app if it still displays cached device state.

---

# Newly Discovered Devices

After:

```bash
dnsbooster net-off br0
```

a newly discovered device will generally have no explicit host-level DNS Booster policy.

Firewalla's default host policy is:

```json
{"dnsCaching":true}
```

The app can therefore show the device as checked.

However:

```text
device
  |
  +-- individual policy = default ON
  |
  +-- network = br0
          |
          +-- network policy = OFF
```

The network-level bypass wins functionally because the device's traffic belongs to a network contained in:

```text
no_dns_caching_set
```

Therefore the device bypasses DNS Booster.

If desired, periodically run:

```bash
dnsbooster gui-off
```

to make newly discovered device checkboxes match the network policy.

No automatic watcher is necessary for DNS behavior.

---

# Re-enable DNS Booster

Enable DNS Booster for the network:

```bash
dnsbooster net-on br0
```

This removes the network's ipsets from the DNS Booster bypass set.

However, devices explicitly configured OFF still remain individually bypassed.

To enable it everywhere:

```bash
dnsbooster all-on br0
```

This enables:

```text
network policy
+
every known device policy
```

---

# Useful Diagnostics

## Find Firewalla Networks

```bash
for key in $(redis-cli --scan --pattern 'network:uuid:*'); do
    echo
    echo "===== $key ====="
    redis-cli HMGET \
        "$key" \
        intf \
        ipv4Subnet \
        type \
        monitoring
done
```

---

## Inspect Network DNS Booster Policies

```bash
for key in $(redis-cli --scan --pattern 'policy:network:*'); do
    val=$(redis-cli --raw HGET "$key" dnsmasq)

    if [ -n "$val" ]; then
        uuid="${key#policy:network:}"

        intf=$(redis-cli --raw \
            HGET "network:uuid:$uuid" intf)

        subnet=$(redis-cli --raw \
            HGET "network:uuid:$uuid" ipv4Subnet)

        echo
        echo "$intf  $subnet"
        echo "UUID:    $uuid"
        echo "dnsmasq: $val"
    fi
done
```

---

## Inspect Device DNS Booster Policies

```bash
for key in $(redis-cli --scan --pattern 'policy:mac:*'); do
    val=$(redis-cli --raw HGET "$key" dnsmasq)

    if [ -n "$val" ]; then
        mac="${key#policy:mac:}"

        echo "$mac  $val"
    fi
done
```

---

## Inspect Network DNS Booster Bypass

```bash
ipset list no_dns_caching_set
```

Example network entries:

```text
c_net_d2d01b44-4309_set
c_net_d2d01b44-4309_set6
c_net_ll6_d2d01b44-4309_set6
```

---

## Inspect Device DNS Booster Bypass

```bash
ipset list no_dns_caching_mac_set
```

This displays MAC addresses currently bypassing DNS Booster at the device level.

---

# Manual Network-Level Procedure

The CLI automates this, but the underlying procedure is useful for troubleshooting.

Find the network UUID:

```bash
for key in $(redis-cli --scan --pattern 'network:uuid:*'); do
    echo
    echo "$key"
    redis-cli HMGET "$key" intf ipv4Subnet type monitoring
done
```

For example:

```text
network:uuid:d2d01b44-4309-4057-961a-25ce9358d917
```

Store the network policy:

```bash
UUID="d2d01b44-4309-4057-961a-25ce9358d917"

redis-cli HSET \
    "policy:network:$UUID" \
    dnsmasq \
    '{"dnsCaching":false}'
```

Notify the running Firewalla policy engine:

```bash
redis-cli PUBLISH \
    'Network:PolicyChanged' \
    '{"type":"d2d01b44-4309-4057-961a-25ce9358d917","id":"dnsmasq","msg":{"dnsmasq":{"dnsCaching":false}}}'
```

Firewalla schedules policy application approximately three seconds after receiving the event.

Verify:

```bash
sleep 5

ipset list no_dns_caching_set |
    grep 'd2d01b44-4309'
```

Expected:

```text
c_net_d2d01b44-4309_set
c_net_d2d01b44-4309_set6
c_net_ll6_d2d01b44-4309_set6
```

---

# Redis Policy Locations

Useful keys:

```text
network:uuid:<UUID>
policy:network:<UUID>
host:mac:<MAC>
policy:mac:<MAC>
```

Network DNS Booster policy:

```bash
redis-cli HGET \
    "policy:network:<UUID>" \
    dnsmasq
```

Device DNS Booster policy:

```bash
redis-cli HGET \
    "policy:mac:<MAC>" \
    dnsmasq
```

---

# Firewalla Policy Events

The Firewalla build used during development subscribes to policy events through its `Monitorable` framework.

Network policy channel:

```text
Network:PolicyChanged
```

Network event shape:

```json
{
  "type": "NETWORK-UUID",
  "id": "dnsmasq",
  "msg": {
    "dnsmasq": {
      "dnsCaching": false
    }
  }
}
```

Device policy channel:

```text
Host:PolicyChanged
```

Device event shape:

```json
{
  "type": "MAC-ADDRESS",
  "id": "dnsmasq",
  "msg": {
    "dnsmasq": {
      "dnsCaching": false
    }
  }
}
```

This is why simply changing the Redis value is not enough for an immediate update.

The persistent policy must be stored **and** the appropriate event must be published so the running Firewalla process applies the change.

---

# Policy Application Delay

Firewalla does not necessarily apply the event synchronously.

The tested implementation schedules policy application roughly three seconds after receiving the policy-change notification.

After modifying policy, allow approximately:

```text
3-5 seconds
```

before checking the resulting ipsets.

---

# Why Not Modify ipset Directly?

It is possible to manually run commands similar to:

```bash
ipset add ...
```

but that only modifies the current enforcement state.

It does not make Firewalla's persistent policy database agree with the change.

Firewalla can later rebuild its firewall/ipset state and remove the manual modification.

The CLI instead uses:

```text
Redis persistent policy
        +
Firewalla policy event
        |
        v
Firewalla policy engine
        |
        v
ipset enforcement
```

This is much closer to what Firewalla itself does internally.

---

# Persistence

The main script is stored under:

```text
/home/pi/.firewalla/config/
```

The startup helper is stored under:

```text
/home/pi/.firewalla/config/post_main.d/
```

Firewalla provides `post_main.d` for custom scripts that should execute whenever the Firewalla services are initialized, including after reboots and software updates.

The startup helper does **not** reapply the DNS Booster policy itself.

The policy already exists persistently in Redis.

Its only job is to recreate:

```text
/usr/local/bin/dnsbooster
```

if a Firewalla update removes that symlink.

---

# Updating the Utility

Replace:

```text
/home/pi/.firewalla/config/dnsbooster
```

with the newer version.

Then:

```bash
chmod 755 /home/pi/.firewalla/config/dnsbooster
```

Verify:

```bash
dnsbooster --help
```

No Firewalla reboot should be required.

---

# Uninstall

First restore DNS Booster if desired:

```bash
dnsbooster all-on br0
```

Wait several seconds and verify:

```bash
dnsbooster status br0
```

Then remove the command and persistence helper:

```bash
rm -f /usr/local/bin/dnsbooster

rm -f \
    /home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh

rm -f \
    /home/pi/.firewalla/config/dnsbooster
```

This removes the custom utility.

The explicit `dnsCaching:true` policies created by `all-on` remain in Firewalla's policy database, which is harmless and corresponds to DNS Booster being enabled.

---

# Source Files Used During Development

The behavior was traced through Firewalla's source code, particularly:

```text
net2/Monitorable.js
net2/MessageBus.js
net2/NetworkProfile.js
net2/Host.js
```

Important implementation details include:

```text
Monitorable.setPolicyAsync()
Monitorable.saveSinglePolicy()
Monitorable.onPolicyChange()
Monitorable.scheduleApplyPolicy()

NetworkProfile.getClassName()
NetworkProfile._getPolicyKey()
NetworkProfile._dnsmasq()

Host._getPolicyKey()
Host._dnsmasq()

MessageBus.publish()
MessageBus.subscribe()
```

The original tested Firewalla commit was:

```text
db737fdf37b20a107ed03cd4aae76e9b592f873b
```

Because this utility relies on internal implementation details, these files should be checked again if a future Firewalla release breaks the command.

---

# Summary

For normal use:

```bash
dnsbooster all-off br0
```

Check it:

```bash
dnsbooster status br0
```

For newly discovered devices, the network-wide policy means nothing else is required.

If you want every per-device checkbox to visually match:

```bash
dnsbooster gui-off
```

The resulting design is:

```text
                  Firewalla
                      |
             +--------+--------+
             |                 |
       Network Policy      Device Policy
       dnsCaching=false    dnsCaching=false
             |                 |
             |                 +-- GUI unchecked
             |
             +-- all current devices bypass
             |
             +-- all future devices bypass
```

The network policy provides the actual guarantee.

The per-device policy keeps the GUI tidy.

---

## Addendum: Runtime Reconciliation and Reboot Persistence

### Why `reconcile` Was Added

Firewalla stores DNS Booster configuration persistently in Redis, but the runtime enforcement ipsets are rebuilt as Firewalla services start and devices become active.

This creates an important distinction between:

```text
Persistent policy
```

and:

```text
Current runtime ipset state
```

For example, all known devices may have:

```json
{"dnsCaching":false}
```

stored under their individual `policy:mac:<MAC>` Redis keys, while only currently active devices are present in:

```text
no_dns_caching_mac_set
```

During testing, there were:

```text
Known devices:                       86
Explicitly OFF / unchecked:         86
Currently in bypass IPset:           58
```

The remaining devices were correctly configured in Redis but were not currently represented in the live MAC bypass ipset.

To provide true **belt-and-suspenders enforcement**, the utility now includes:

```bash
dnsbooster reconcile
```

---

## What `reconcile` Does

`reconcile` treats Firewalla's persistent Redis policies as the source of truth.

It does **not modify policy values**.

Instead, it examines the stored configuration and makes the runtime DNS Booster ipsets agree with it.

Conceptually:

```text
              Persistent Redis Policy
                       |
          +------------+------------+
          |                         |
   policy:network:*            policy:mac:*
          |                         |
          v                         v
  Network DNS Booster       Device DNS Booster
       preference                preference
          |                         |
          +------------+------------+
                       |
                       v
               dnsbooster reconcile
                       |
          +------------+------------+
          |                         |
 no_dns_caching_set     no_dns_caching_mac_set
```

This preserves the distinction between the different operating modes.

---

## Operating Modes Survive Reboot

The utility does not store its own separate mode such as:

```text
MODE=all-off
```

Instead, the actual Firewalla policies determine what should happen after restart.

### Device-Only Disable

If you run:

```bash
dnsbooster gui-off
```

while leaving the network policy enabled or unset, the persistent state is approximately:

```text
Network: DNS Booster ON/default
Devices: DNS Booster OFF
```

After reboot:

```bash
dnsbooster reconcile
```

restores all explicitly disabled MAC addresses to:

```text
no_dns_caching_mac_set
```

but does **not** disable DNS Booster network-wide.

---

### Network-Only Disable

If you run:

```bash
dnsbooster net-off br0
```

without explicitly disabling every device, the persistent state is:

```text
br0:     DNS Booster OFF
Devices: individual policies unchanged
```

After reboot, `reconcile` restores the network's Firewalla ipsets into:

```text
no_dns_caching_set
```

but does not invent or change individual device policies.

New devices on that network continue to bypass DNS Booster because the network itself is excluded.

---

### Full Disable

Running:

```bash
dnsbooster all-off br0
```

creates both:

```text
Network policy: DNS Booster OFF
Device policies: DNS Booster OFF
```

and immediately reconciles the known MAC addresses into the live bypass ipset.

This provides:

```text
Network-wide bypass
        +
Persistent per-device OFF policies
        +
Every known MAC in the live bypass ipset
```

After reboot, `reconcile` rebuilds the same runtime state from Redis.

---

## Belt-and-Suspenders Device Enforcement

The updated `gui-off` / `devices-off` behavior does more than store the Firewalla policy.

For every known device it now:

1. Ensures the persistent Redis policy has:

```json
{"dnsCaching":false}
```

2. Publishes Firewalla's normal:

```text
Host:PolicyChanged
```

event when the persistent policy actually changes.

3. Ensures the MAC is directly present in:

```text
no_dns_caching_mac_set
```

even if Firewalla currently considers the device offline or stale.

This means a successful run should result in matching counts.

Example:

```text
Devices: DNS Booster OFF / unchecked
  Known devices:       86
  Redis changed:       0
  Redis already set:   86
  Skipped:             0
  Added to live ipset: 28
  Already in ipset:    58
```

Afterward:

```bash
dnsbooster status br0
```

should show:

```text
Devices
  Known:                       86
  Explicitly OFF / unchecked: 86
  Explicitly ON / checked:     0
  Unset (default ON):          0
  Invalid policy JSON:         0
  Currently in bypass IPset:   86
```

The raw ipset can also be checked with:

```bash
ipset list no_dns_caching_mac_set |
    grep 'Number of entries'
```

Example:

```text
Number of entries: 86
```

---

## Reconcile Command

Run manually at any time with:

```bash
dnsbooster reconcile
```

This is safe to run repeatedly.

It does not change the chosen DNS Booster configuration.

Its job is simply:

```text
Stored policy
     ↓
Live enforcement
```

Typical reasons to run it manually include:

- after troubleshooting Firewalla services
- after manually inspecting or modifying ipsets
- after a Firewalla software update
- after restarting policy-related services
- when persistent policy and runtime ipset counts appear inconsistent

---

## Updated Startup Helper

The startup helper:

```text
/home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh
```

now performs two jobs.

### 1. Restore the Command Symlink

It ensures:

```text
/usr/local/bin/dnsbooster
```

points to:

```text
/home/pi/.firewalla/config/dnsbooster
```

This is useful in case a Firewalla software update removes files or symlinks under `/usr/local/bin`.

### 2. Reconcile Runtime DNS Booster State

After Firewalla starts, it runs:

```bash
/home/pi/.firewalla/config/dnsbooster reconcile
```

This rebuilds the runtime DNS Booster bypass state according to the persistent Redis policies.

The startup helper does **not** blindly run:

```bash
dnsbooster all-off
```

or:

```bash
dnsbooster gui-off
```

That is intentional.

Doing so would destroy the distinction between device-only and network-only configurations.

Instead:

```text
Redis remembers what was chosen.
reconcile restores what Redis says.
```

---

## Startup Logging

Automatic reconciliation output is written to:

```text
/home/pi/.firewalla/config/dnsbooster-reconcile.log
```

Check the latest startup reconciliation with:

```bash
tail -100 \
    /home/pi/.firewalla/config/dnsbooster-reconcile.log
```

A successful run should end with output indicating that the runtime ipsets were reconciled successfully.

---

## Test the Startup Helper Manually

A reboot is not required to test the startup behavior.

Run:

```bash
sudo \
    /home/pi/.firewalla/config/post_main.d/10-dnsbooster-command.sh
```

Then inspect:

```bash
tail -100 \
    /home/pi/.firewalla/config/dnsbooster-reconcile.log
```

Verify the final state with:

```bash
dnsbooster status
```

or:

```bash
dnsbooster status br0
```

---

## Recommended Verification After Reboot

After rebooting Firewalla:

```bash
dnsbooster status br0
```

For a fully disabled configuration, verify:

```text
Stored policy:             OFF
Network bypass IPset:      YES
```

and:

```text
Explicitly OFF / unchecked: <all known devices>
Currently in bypass IPset:   <all known devices>
```

Also verify directly:

```bash
ipset list no_dns_caching_set
```

and:

```bash
ipset list no_dns_caching_mac_set |
    grep 'Number of entries'
```

---

## Current Command Summary

```text
dnsbooster status [interface]

dnsbooster net-off <interface>
dnsbooster net-on <interface>

dnsbooster devices-off
dnsbooster devices-on

dnsbooster gui-off
dnsbooster gui-on

dnsbooster all-off <interface>
dnsbooster all-on <interface>

dnsbooster reconcile
```

### `net-off`

Persistent network-level DNS Booster disable.

Covers current and future devices on that Firewalla network.

### `gui-off` / `devices-off`

Persistent per-device disable for every currently known device and immediate reconciliation into the live MAC bypass ipset.

### `all-off`

Combines network-wide and per-device disable.

This is the strongest configuration.

### `reconcile`

Makes runtime ipsets match the existing persistent policies without changing those policies.

---

## Final Persistence Model

The completed design is:

```text
                    FIREWALLA REDIS
                         |
          +--------------+--------------+
          |                             |
   Network policy                 Device policies
   dnsCaching=false               dnsCaching=false
          |                             |
          |                             |
          +--------------+--------------+
                         |
                  Persistent across
                       reboot
                         |
                         v
             10-dnsbooster-command.sh
                         |
                         v
                dnsbooster reconcile
                         |
          +--------------+--------------+
          |                             |
 no_dns_caching_set        no_dns_caching_mac_set
          |                             |
          +--------------+--------------+
                         |
                         v
              Runtime DNS enforcement
```

This provides three independent layers:

```text
Persistent Firewalla network policy
             +
Persistent Firewalla device policies
             +
Explicit runtime ipset reconciliation
```

The selected configuration survives reboot without the startup process having to guess whether the intended mode was network-only, device-only, or both.
