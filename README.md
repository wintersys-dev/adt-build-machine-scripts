# The Wintersys Agile Deployment Toolkit — Build Machine

The **Wintersys Agile Deployment Toolkit (ADT)** is an automated, cloud-agnostic infrastructure provisioning and deployment framework. This repository contains the core orchestration engine executed on the **Build Machine** to provision, harden, configure, and manage multi-tier web infrastructure across supported cloud providers.

---

## Supported Providers & Integrations

The toolkit is designed for frictionless cross-provider portability, supporting the following infrastructure and third-party services:

* **Cloud VPS & Managed Database Providers:** DigitalOcean, Exoscale, Linode (Akamai), Vultr
* **S3-Compatible Object Storage:** DigitalOcean Spaces, Exoscale Object Store, Linode Object Store, Vultr Object Store
* **DNS Providers:** Cloudflare DNS, DigitalOcean DNS, Exoscale DNS, Linode DNS, Vultr DNS
* **Email / SMTP Services:** Amazon SES, Mailjet, SendPulse
* **Git Repositories:** Bitbucket, GitHub, GitLab
* **Supported Operating Systems:** Ubuntu, Debian (extensible to other Linux distributions)
* **Supported Web Applications:** Joomla, WordPress, Drupal, Moodle (extensible to custom PHP/web applications)

---

## Architecture Overview

The Build Machine acts as the central control plane for a deployment. It provisions isolated infrastructure environments tagged by a unique `BUILD_IDENTIFIER` and coordinates role-specific server tiers:

* **Authenticator (`adt-authenticator`):** Handles peer identity verification (e.g. WireGuard) and perimeter access control.
* **Autoscaler (`adt-autoscaler`):** Monitors workload metrics and dynamically scales application capacity.
* **Reverse Proxy (`adt-reverseproxy`):** Terminates SSL/TLS traffic and routes external requests to internal application nodes.
* **Web Server (`adt-webserver`):** Hosts the application runtime and serves dynamic/static web traffic.
* **Database (`adt-database`):** Runs either a self-managed relational database inside the private VPC subnet or connects to a provider-managed DBaaS instance.

---

## Directory Layout

```text
\${BUILD_HOME}/
├── configuration/              # Core deployment and software selection files
│   ├── software.dat            # Active tooling switches (ORCHESTRATION_TOOL, FIREWALL, EMAILUTIL, FAIL2BAN)
│   └── firewall.dat            # Role-based custom ingress port and CIDR definitions
├── helpers/
│   └── services/               # Shared POSIX utility wrappers
│       ├── GetBuildMachineIP.sh
│       ├── GetVariableValue.sh
│       ├── LogStatusMessages.sh
│       └── RunServiceCommand.sh
├── runtime/                    # Ephemeral deployment state, active build IDs, and IP tracking
├── services/
│   ├── datastore/operations/   # S3-compatible object storage helpers (Mount, Get, Put, List, Delete)
│   ├── dns/                    # DNS provider and proxy IP range lookups (e.g. Cloudflare)
│   ├── email/                  # Pluggable notification backends (ssmtp, sendemail)
│   ├── security/firewall/      # Host (UFW/iptables) and cloud-native firewall orchestration (API & CLI)
│   └── server/                 # Cloud compute instance lifecycle management
└── templatedconfigurations/    # Provider-specific configuration templates
```

---

## Key Capabilities

* **Dual Orchestration Engines (`api` / `cli`):** Supports direct REST API calls via `curl` + `jq` as well as vendor CLI utilities (such as `linode-cli`, `doctl`, `exo`, `vultr-cli`), selectable via `ORCHESTRATION_TOOL` in `configuration/software.dat`.
* **Layered Firewall & Perimeter Security:**
  * **Host-Level Hardening:** Automatically configures `ufw` or `iptables`/`ip6tables` and dynamically updates SSH `AllowUsers` rules from an S3-backed `authorised-ips.dat` allowlist.
  * **Cloud-Native Firewalls:** Provisions and updates provider-managed firewalls per server tier with default-deny ingress policies, VPC-scoped SSH/database rules, and DNS proxy (Cloudflare) HTTPS allowlisting.
* **Pluggable Alerting & Telemetry:** Centralized status logging (`LogStatusMessages.sh`) paired with severity-filtered email notifications (`ERROR`, `INFO`, `MANDATORY`) via `ssmtp` or `sendemail`.
* **Laptop & Cloud Auto-Detection:** Detects whether execution is occurring on a local workstation or a cloud host to adjust firewall priming and deployment workflows automatically.

---

## Prerequisites & Dependencies

The Build Machine environment requires a POSIX-compliant `/bin/sh` runtime and standard system utilities:

* **Core Binaries:** `/bin/sh`, `curl`, `jq`, `awk`, `sed`, `grep`, `ipcalc`, `whois`
* **Host Firewall & SSH:** `ufw` or `iptables` / `ip6tables` (`iptables-persistent`), `openssh-server`, `fail2ban` (optional)
* **Cloud & Datastore Tools:** Provider CLI when `ORCHESTRATION_TOOL:cli` is enabled, plus S3-compatible CLI tools (`s3cmd` / `aws` / `rclone`)
* **Email Utilities:** `ssmtp` + `mailutils` or `sendemail`
* **Tracking Files:**
  * `/home/buildhome.dat` containing the absolute path to `${BUILD_HOME}`
  * `/root/buildmachine_user.dat` containing the administrative SSH username

---

## Coding & Security Conventions

All scripts in this repository adhere to strict defensive shell standards:

1. **POSIX Portability:** Written strictly for `#!/bin/sh` with `set -e` enabled and full paths (`/bin/...`, `/usr/bin/...`) to prevent `PATH` hijacking.
2. **Self-Documenting Headers:** Every script includes a structured `#:` metadata header and supports `-h` / `--help` to print usage, parameters, dependencies, and exit codes.
3. **Zero Process-Tree Secret Exposure:**
   * REST API bearer tokens are piped via `stdin` (`curl -H @-`) rather than passed on the command line.
   * CLI credential environment variables (e.g. `LINODE_CLI_TOKEN`) are exported only for the duration of the command and immediately cleared with `unset`.
4. **Injection-Safe JSON:** All API payloads and filters are constructed and parsed using `jq --arg` / `--argjson` rather than raw string interpolation.

---

## Usage

Every script supports built-in help output:

```sh
/path/to/script.sh --help
```

To inspect active runtime state on a provisioned Build Machine:

```sh
cat /home/buildhome.dat
cat "\$(cat /home/buildhome.dat)/runtime/ACTIVE_BUILD_IDENTIFIER"
```

---

## Documentation & License

* **Official Documentation:** [Wintersys Initiatives — Agile Deployment Toolkit](https://www.wintersys-initiatives.uk/Agile%20Deployment%20Toolkit/ADT)
* **License:** This project is part of **The Wintersys Agile Deployment Toolkit** and is licensed under the **GNU General Public License v3.0 (GPLv3)**. See [gnu.org/licenses/gpl-3.0](https://gnu.org) for full license terms.






