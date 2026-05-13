# Custom iPXE Bootable ISO - Implementation Plan

## Option 1: Custom iPXE ISO

### Overview
Build a single hybrid BIOS/UEFI bootable ISO using iPXE that:
- Boots on any system (BIOS or UEFI)
- Fetches a menu from your HTTPS server
- Downloads and boots ISOs from HTTPS server
- Requires zero kernel compilation or custom bootloaders

---

## Phase 1: Environment Setup (30 minutes)

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt-get install -y \
  git \
  build-essential \
  perl \
  xorriso \
  mtools \
  syslinux

# Or use Docker (even simpler)
docker run -it ubuntu:22.04 bash
# Run apt-get install inside container
```

### Clone iPXE Repository
```bash
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src
```

---

## Phase 2: Create Boot Menu Script (30 minutes)

### File: `boot.ipxe`
This script runs when ISO boots. It:
1. Fetches menu from your HTTPS server
2. Displays interactive menu
3. Downloads and boots selected ISO

```ipxe
#!ipxe
# Custom iPXE Boot Menu
# Server configuration
set SERVER https://your-server.com

# Enable HTTPS with certificate checking (optional, disable for self-signed)
# set VERIFY off

# Show banner
echo ============================================
echo      Boot Menu - Loading from Server...
echo ============================================
echo

# Fetch menu from server and execute it
chain ${SERVER}/ipxe/menu.ipxe ||
echo Failed to fetch menu from server
echo Dropping to iPXE shell...
shell
```

---

## Phase 3: Create Server-Side Menu (30 minutes)

### File: `menu.ipxe` (hosted on your HTTPS server)
```ipxe
#!ipxe
# Main Boot Menu
set SERVER https://your-server.com
set TIMEOUT 30000

:menu
menu --title "Boot Menu" --timeout ${TIMEOUT}
item --gap -- ========== Linux Distributions ==========
item ubuntu          Ubuntu 22.04 LTS
item debian          Debian 12
item fedora           Fedora 39
item arch             Arch Linux
item --gap -- ========== System Tools ==========
item gparted         GParted Live
item clonezilla      CloneZilla
item memtest         Memory Test
item shell           iPXE Shell
item exit            Exit (Boot Local Disk)
choose target && goto ${target}

# Ubuntu
:ubuntu
echo Downloading Ubuntu 22.04 LTS...
kernel ${SERVER}/iso/ubuntu-22.04.5-live-server-amd64.iso || goto failed
boot || goto failed

# Debian
:debian
echo Downloading Debian 12...
kernel ${SERVER}/iso/debian-12.0.0-amd64-DVD-1.iso || goto failed
boot || goto failed

# Fedora
:fedora
echo Downloading Fedora 39...
kernel ${SERVER}/iso/Fedora-39-x86_64-dvd.iso || goto failed
boot || goto failed

# Arch Linux
:arch
echo Downloading Arch Linux...
kernel ${SERVER}/iso/archlinux-x86_64.iso || goto failed
boot || goto failed

# GParted
:gparted
echo Downloading GParted Live...
kernel ${SERVER}/iso/gparted-1.4.0-1-amd64.iso || goto failed
boot || goto failed

# CloneZilla
:clonezilla
echo Downloading CloneZilla...
kernel ${SERVER}/iso/clonezilla-3.1.1-31-amd64.iso || goto failed
boot || goto failed

# Memory Test
:memtest
echo Downloading Memtest86+...
kernel ${SERVER}/iso/memtest86+-6.10.iso || goto failed
boot || goto failed

# Shell
:shell
shell
goto menu

# Exit
:exit
echo Exiting iPXE - booting local disk
exit

:failed
echo Boot failed! Check server or try another option.
sleep 3
goto menu
```

---

## Phase 4: Build the ISO (15 minutes)

### Step 1: Create Boot Configuration
In `ipxe/src/` create `boot.ipxe` with content from Phase 2.

### Step 2: Compile iPXE with Embedded Script
```bash
cd ipxe/src
make clean
make bin/ipxe.iso EMBED=../boot.ipxe
```

This creates: `bin/ipxe.iso` - Your bootable ISO (works BIOS + UEFI)

### Alternative: Pre-configured Build
```bash
# One-liner to build with inline script
make bin/ipxe.iso \
  EMBED=../boot.ipxe \
  TRUST=/path/to/ca-certificates.crt  # For HTTPS verification (optional)
```

---

## Phase 5: Server Setup (30 minutes)

### Directory Structure
```
/var/www/html/
├── ipxe/
│   ├── menu.ipxe          # Main menu
│   ├── ubuntu.ipxe        # Optional: per-OS boot scripts
│   ├── debian.ipxe
│   └── ...
└── iso/
    ├── ubuntu-22.04.5-live-server-amd64.iso
    ├── debian-12.0.0-amd64-DVD-1.iso
    ├── Fedora-39-x86_64-dvd.iso
    └── ...
```

### HTTPS Server (Nginx Example)
```nginx
server {
    listen 443 ssl http2;
    server_name your-server.com;

    ssl_certificate /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    root /var/www/html;

    location /ipxe/ {
        types { text/plain ipxe; }
    }

    location /iso/ {
        # Large file handling
        client_max_body_size 10G;
    }
}
```

### Apache2 Alternative
```apache
<VirtualHost *:443>
    ServerName your-server.com
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/your-cert.pem
    SSLCertificateKeyFile /etc/ssl/private/your-key.pem

    <Directory /var/www/html/ipxe>
        AddType text/plain .ipxe
    </Directory>
</VirtualHost>
```

---

## Phase 6: Testing (30 minutes)

### Local Testing (No Server Required)
Edit `boot.ipxe` to use `http://10.0.2.2/` for VM host access:
```ipxe
set SERVER http://10.0.2.2:8000
```

### Test with QEMU
```bash
# BIOS Boot
qemu-system-x86_64 -m 2048 -cdrom ipxe/src/bin/ipxe.iso

# UEFI Boot
qemu-system-x86_64 -m 2048 \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom ipxe/src/bin/ipxe.iso
```

### Test with VirtualBox
1. Create new VM (BIOS or UEFI)
2. Mount ISO as CD drive
3. Boot and verify menu loads

### Physical Hardware Testing
1. Write ISO to USB: `dd if=bin/ipxe.iso of=/dev/sdX bs=4M`
2. Boot from USB on BIOS system
3. Boot from USB on UEFI system
4. Verify menu loads and ISO download works

---

## Phase 7: Deployment

### Option A: Distribute ISO
```bash
# Host on server
cp ipxe/src/bin/ipxe.iso /var/www/html/downloads/

# Users download and write to USB
dd if=ipxe.iso of=/dev/sdX bs=4M
```

### Option B: PXE Boot (Advanced)
Store ISO on HTTP server and boot via PXE directly (no USB needed).

---

## Timeline Summary

| Phase | Task | Duration |
|-------|------|----------|
| 1 | Environment setup | 30 min |
| 2 | Create boot script | 30 min |
| 3 | Create menu script | 30 min |
| 4 | Build ISO | 15 min |
| 5 | Server setup | 30 min |
| 6 | Testing | 30 min |
| 7 | Deployment | 15 min |
| **Total** | | **3.5 hours** |

---

## Key Features

✅ Single ISO file (hybrid BIOS/UEFI)
✅ Interactive menu over HTTPS
✅ Download ISOs on demand
✅ Fallback to iPXE shell
✅ Easy to update (just edit menu.ipxe on server)
✅ No custom kernel compilation
✅ Works on all systems (VM + physical hardware)

---

## Next Steps

1. Set up HTTPS server with menu.ipxe and ISOs
2. Clone iPXE repo locally
3. Create boot.ipxe script
4. Run: `make bin/ipxe.iso EMBED=../boot.ipxe`
5. Test with QEMU
6. Test on physical hardware
7. Distribute ISO

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Menu not loading | Check HTTPS server is reachable, verify menu.ipxe syntax |
| ISO download fails | Verify ISO files exist on server, check HTTPS certificates |
| UEFI boot fails | Ensure xorriso is installed, rebuild ISO |
| Self-signed cert errors | Add `set VERIFY off` to boot.ipxe (testing only) |

---

## Resources

- iPXE Documentation: https://ipxe.org/start
- iPXE Boot Scripts: https://ipxe.org/scripting
- NetbootXYZ (reference): https://netboot.xyz/
