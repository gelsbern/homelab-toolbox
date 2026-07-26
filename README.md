# Homelab Toolbox

A collection of practical shell scripts, configuration helpers, troubleshooting notes, and one-off fixes created while maintaining a real-world homelab.

This repository is intended to be a reusable toolbox rather than a single application. Each project lives in its own subdirectory and includes its own `README.md` with usage instructions, warnings, testing notes, and any relevant background.

Most of these projects began with some variation of:

> “There has to be a better way to do this.”

Sometimes there was. Sometimes the answer was hidden behind undocumented PJL commands in a printer from 2010.

## Repository Goals

This repository is designed to:

- Preserve useful fixes and scripts that would otherwise disappear into shell history
- Document unusual solutions that were difficult to find elsewhere
- Provide reusable tools for Linux, NAS, networking, virtualization, backups, printers, and Docker
- Keep each project self-contained and easy to share
- Record warnings and recovery steps alongside every potentially destructive operation
- Help other homelab users avoid repeating several hours of unnecessary suffering

## Project Structure

Each project should use a structure similar to:

```text
category/
└── project-name/
    ├── README.md
    ├── script-name.sh
    └── supporting-files/
```

Suggested repository layout:

```text
homelab-toolbox/
├── README.md
├── backups/
├── docker/
├── linux/
├── networking/
├── printers/
├── proxmox/
├── synology/
├── terramaster/
└── utilities/
```

## Current Projects

### Printers

#### Brother HL-2270DW Sleep Control

Location:

```text
printers/brother-hl2270dw-sleep-control/
```

Files:

```text
README.md
brother-hl2270dw-sleep-control.sh
```

A Bash and Python utility that controls hidden sleep and power-save settings on a Brother HL-2270DW through PJL over TCP port 9100.

The Brother web interface contains a hidden `AUTOSLEEP` control, but the normal web form does not save it. The printer does expose the same settings through PJL:

```text
AUTOSLEEP
TIMEOUTSLEEP
POWERSAVE
POWERSAVETIME
```

The script can:

- Query the current power-management settings
- Disable sleep persistently
- Re-enable sleep
- Set both sleep timers
- Verify changes after writing them
- Confirm that settings survive a power cycle

Important discovery:

```text
TIMEOUTSLEEP=0
```

means sleep immediately on this model. It does not mean sleep is disabled.

### Synology

Planned and existing utilities include:

#### Music Artist Folder Organizer

Organizes a large music library into:

```text
Artists 0-9
Artists A-M
Artists N-Z
```

This works around practical folder-count and File Station usability limits on large Synology music libraries.

#### Rsnapshot Configuration Helpers

Scripts and notes for:

- Managing per-host rsnapshot configuration files
- Using database dumps before filesystem snapshots
- Storing snapshot roots under persistent Synology volumes
- Avoiding unsupported Active Backup for Business configurations on newer Debian releases
- Keeping troubleshooting backups under a dedicated persistent backup directory

#### Certificate Deployment

Utilities and documentation for:

- Deploying ACME certificates to Synology DSM
- Updating service certificates
- Reloading affected services
- Keeping scripts and certificates outside nonpersistent system paths
- Preserving backups before certificate replacement

#### Storage and Recovery Notes

Documentation and scripts related to:

- Rebuilding storage pools
- Restoring data after a volume rebuild
- Mounting old Linux RAID members
- Inspecting Btrfs filesystems
- Using `mdadm`, `dmsetup`, and recovery mounts safely
- Excluding backup directories from migration jobs

### TerraMaster

Planned and existing utilities include:

#### Certificate Deployment

Scripts for replacing TerraMaster nginx certificates while:

- Backing up current certificate files
- Installing temporary replacements safely
- Testing nginx configuration
- Reloading only after validation
- Preserving the vendor certificate used by alternate management ports

#### Custom Reverse Proxy Notes

Documentation for:

- Running Nginx Proxy Manager in Docker
- Proxying TerraMaster management services
- Handling vendor ports such as 8181 and 5443
- Avoiding conflicts with the built-in nginx service
- Preserving access during proxy changes

#### Docker Service Utilities

Scripts and notes for:

- Dozzle agent deployment
- Portainer deployment
- Filebrowser deployment
- Container migration between compose project directories
- Restart and health verification
- Avoiding container-name conflicts during redeployment

### Backups

Planned and existing projects include:

#### Rsnapshot Database-Aware Backups

Utilities that:

- Dump MariaDB, MySQL, or PostgreSQL databases
- Run database exports before rsnapshot
- Store backups by hostname
- Keep backup configuration files organized by system
- Verify that backup roots point to the correct volume

#### Rsync Migration Tools

Scripts for:

- Large NAS-to-NAS migrations
- Resume-safe transfers
- Logging progress
- Monitoring transfer rates
- Excluding specific directories
- Performing dry-run verification after completion

#### Rsync Transfer Monitor

A terminal-based monitor that displays:

- Interface transfer rates
- Current rsync process status
- Elapsed time
- CPU and memory use
- Log progress

### Linux

Planned and existing projects include:

#### Secure Boot Recovery Notes

Documentation for recovering Debian systems that fail to boot with Secure Boot enabled, including:

- Temporarily disabling Secure Boot
- Repairing Debian shim and bootloader files
- Validating EFI binaries
- Restoring the fallback boot path
- Re-enabling Secure Boot
- Verifying signatures

This project also records the deeply traditional troubleshooting experience of finding the official Debian documentation only after independently solving the problem.

#### Entropy and Random Number Testing

Utilities and notes for:

- Installing `jitterentropy-rngd`
- Checking the kernel entropy pool
- Testing random-data throughput
- Comparing entropy-related services
- Verifying refill behavior

#### Failed Service Diagnosis

Reusable commands and scripts for:

- Listing failed systemd units
- Inspecting timer-triggered services
- Distinguishing successful one-shot services from persistent daemons
- Reviewing journal output
- Safely restarting and validating services

#### Desktop Environment Cleanup

Notes for removing unwanted desktop environments and display-session entries from Debian systems without leaving large piles of unused packages behind.

### Networking

Planned and existing projects include:

#### Pi-hole and Unbound Utilities

Scripts and notes for:

- Pi-hole blocklist troubleshooting
- DNSSEC testing
- Identifying which list blocked a domain
- Adjusting Pi-hole blocking modes
- Maintaining multiple Pi-hole systems
- Testing keepalived virtual IP behavior
- Running Unbound as a local encrypted forwarder

#### Wake-on-LAN Testing

Planned utilities for:

- Discovering target MAC addresses
- Sending standard magic packets
- Testing subnet-directed broadcasts
- Monitoring ARP behavior
- Determining whether sleeping devices retain network presence
- Comparing WoL behavior with application-level wake traffic

#### Reverse Proxy Testing

Reusable commands for:

- Testing upstream HTTP and HTTPS services
- Validating expected HTTP status codes
- Checking alternate IP paths
- Diagnosing 404 responses that still prove upstream reachability
- Testing TLS listeners and certificates

### Proxmox

Planned and existing projects include:

#### Storage Configuration Notes

Documentation for:

- Locating `/etc/pve/storage.cfg`
- Safely editing Proxmox storage definitions
- Understanding when changes apply automatically
- Verifying storage availability after edits

#### VM and LXC Migration Helpers

Scripts and notes for:

- Distinguishing VM and LXC environments
- Migrating services between guests
- Preserving hostname conventions
- Updating reverse proxies after moves
- Verifying service reachability after migration

### Docker

Planned and existing projects include:

#### Nginx Proxy Manager Compose

A clean Docker Compose deployment for Nginx Proxy Manager using:

- Ports 80, 81, and 443
- Persistent application data
- Persistent certificate storage
- Resource limits
- Security options
- Optional MariaDB configuration

#### Portainer Migration Notes

Documentation for:

- Moving Portainer data
- Correcting reverse proxy targets
- Handling Edge Agent deployments
- Avoiding port conflicts
- Migrating compose projects to standardized locations

#### Dozzle Deployment

Scripts and compose examples for:

- Running a central Dozzle instance
- Deploying remote agents
- Correcting agent IP configuration
- Verifying port 7007
- Testing remote log visibility

### General Utilities

Future miscellaneous tools may include:

- File and directory organizers
- Configuration backup helpers
- Certificate inspection scripts
- Service health checks
- Log parsers
- Network test wrappers
- Storage verification tools
- Safe search-and-replace helpers
- System inventory scripts
- Migration checklists

## Project Standards

Each project should include:

### A README

Every project directory should explain:

- What the tool does
- Which systems it was tested on
- Required packages
- Installation steps
- Usage examples
- Expected output
- Known limitations
- Safety warnings
- Recovery or rollback steps

### Safe Defaults

Scripts should:

- Use `set -euo pipefail` where appropriate
- Validate required arguments
- Check required commands before running
- Refuse invalid or dangerous values
- Avoid destructive operations by default
- Use dry-run modes when practical
- Back up files before modifying them
- Verify results after making changes
- Clearly identify model-specific behavior

### Execution Order

Procedures should be written in the exact order they must be performed:

1. Prerequisites
2. Backups
3. Validation
4. Changes
5. Service reload or restart
6. Verification
7. Rollback instructions

No “actually, do this first” surprises halfway through the instructions.

## Compatibility

These tools are primarily developed and tested in environments including:

- Debian 12 Bookworm
- Debian 13 Trixie
- Proxmox VE
- Synology DSM
- TerraMaster TOS
- Docker and Docker Compose
- Raspberry Pi OS and Debian ARM64
- Brother network laser printers

Compatibility with other systems is not guaranteed unless explicitly documented in the project README.

## Contributing

Issues, testing results, corrections, and improvements are welcome.

When submitting a change:

- Describe the hardware and operating system used
- Include exact commands and output
- Mention whether the change survived a reboot or power cycle
- Avoid removing safety checks merely to make a script shorter
- Document unexpected behavior
- Do not include passwords, API keys, certificates, private keys, or public IP addresses

## Disclaimer

These scripts and notes are unofficial and are not affiliated with Brother, Synology, TerraMaster, Proxmox, Debian, Docker, or any other vendor.

Review every script before running it.

Some tools modify persistent settings, service configurations, storage layouts, certificates, or network behavior. Use them at your own risk and maintain current backups.

## License

Choose a license before accepting outside contributions.

For a public collection of reusable scripts, the MIT License is a straightforward option. A `LICENSE` file can be added at the repository root.

## Repository Name

Suggested repository name:

```text
homelab-toolbox
```

Because “miscellaneous collection of things discovered after several hours of swearing” was accurate, but slightly long for GitHub.

