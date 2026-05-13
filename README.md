# Quick Start Guide for Custom iPXE Bootable ISO

## Overview

This project builds a **single bootable ISO** that:
- ✅ Works on BIOS and UEFI systems
- ✅ Fetches an interactive menu from your HTTPS server
- ✅ Downloads and boots ISOs on demand
- ✅ No kernel compilation needed
- ✅ Takes 3.5 hours to set up completely

---

## 📋 Prerequisites

### On Your Build Machine
```bash
# Ubuntu/Debian
sudo apt-get install -y git build-essential perl xorriso mtools syslinux

# Or use Docker (no installation needed)
docker run -it ubuntu:22.04 bash
apt-get update && apt-get install -y git build-essential perl xorriso
```

### On Your Server
- HTTPS enabled (valid SSL certificate)
- Web server (Nginx or Apache2)
- Directory structure:
  ```
  /var/www/ipxe/
  ├── ipxe/
  │   └── menu.ipxe          ← Fetch this from repo
  └── iso/
      ├── ubuntu-22.04...iso
      ├── debian-12...iso
      └── ...
  ```

---

## 🚀 Build Process (15 minutes)

### Step 1: Clone or Download This Repository
```bash
git clone https://github.com/axel-reisl/test.git
cd test
```

### Step 2: Make Build Script Executable
```bash
chmod +x scripts/build.sh
```

### Step 3: Run Build with Your Server URL
```bash
./scripts/build.sh https://your-server.com
```

This creates: `dist/ipxe-custom.iso` — a hybrid BIOS + UEFI boot ISO.

---

## 🖥️ Server Setup (30 minutes)

### Step 1: Create Directory Structure
```bash
sudo mkdir -p /var/www/ipxe/{ipxe,iso}
sudo chown -R www-data:www-data /var/www/ipxe
```

### Step 2: Copy Menu Script to Server
```bash
# From your local machine
scp scripts/menu.ipxe user@your-server.com:/var/www/ipxe/menu.ipxe

# Or manually:
# 1. Download menu.ipxe from this repo
# 2. Edit it to match your server URL (search for "https://your-server.com")
# 3. Copy to /var/www/ipxe/menu.ipxe
```

### Step 3: Upload ISO Files to Server
```bash
# Upload Ubuntu ISO
scp ~/Downloads/ubuntu-22.04.5-live-server-amd64.iso \
  user@your-server.com:/var/www/ipxe/iso/

# Upload Debian ISO
scp ~/Downloads/debian-12.0.0-amd64-DVD-1.iso \
  user@your-server.com:/var/www/ipxe/iso/
```

### Step 4: Configure Web Server

**Nginx:**
```bash
sudo cp server-configs/nginx.conf /etc/nginx/sites-available/ipxe-server
sudo ln -s /etc/nginx/sites-available/ipxe-server /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**Apache2:**
```bash
sudo cp server-configs/apache2.conf /etc/apache2/sites-available/ipxe-server.conf
sudo a2ensite ipxe-server
sudo apache2ctl configtest
sudo systemctl restart apache2

# Enable required modules
sudo a2enmod ssl rewrite headers
```

---

## ✅ Testing

### Local Testing (with QEMU)
```bash
# Test BIOS boot
qemu-system-x86_64 -m 2048 -cdrom dist/ipxe-custom.iso

# Test UEFI boot
qemu-system-x86_64 -m 2048 \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom dist/ipxe-custom.iso
```

### Physical Hardware Testing
```bash
# Write to USB
sudo dd if=dist/ipxe-custom.iso of=/dev/sdX bs=4M status=progress
sync

# Boot from USB on both BIOS and UEFI systems
```

### Verify Server is Reachable
```bash
# From boot machine
curl -v https://your-server.com/ipxe/menu.ipxe
```

---

## 📁 File Structure

```
test/
├── IPXE_BUILD_PLAN.md           ← Full technical documentation
├── README.md                     ← This file
├── scripts/
│   ├── boot.ipxe                ← Embedded in ISO
│   ├── menu.ipxe                ← Copy to your server
│   └── build.sh                 ← Build script
├── server-configs/
│   ├── nginx.conf               ← Nginx config
│   └── apache2.conf             ← Apache2 config
└── dist/
    └── ipxe-custom.iso          ← Your bootable ISO (created by build.sh)
```

---

## 🔧 Customization

### Change Boot Menu Items
Edit `scripts/menu.ipxe`:
```ipxe
item myos          My Custom OS

:myos
echo Downloading My Custom OS...
kernel ${SERVER}/iso/my-custom-os.iso || goto failed
boot || goto failed
```

### Change Server URL
Edit `scripts/boot.ipxe`:
```ipxe
set SERVER https://new-server.com
```

Then rebuild:
```bash
./scripts/build.sh https://new-server.com
```

### Add More ISOs
1. Upload ISO to `/var/www/ipxe/iso/filename.iso`
2. Add menu item to `menu.ipxe`
3. No rebuild needed! Just restart web server.

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Menu not loading" | Check HTTPS cert is valid. Test: `curl https://your-server.com/ipxe/menu.ipxe` |
| ISO download fails | Verify ISO file exists on server: `ls -lh /var/www/ipxe/iso/` |
| UEFI won't boot | Ensure xorriso is installed. Rebuild ISO. |
| Self-signed cert errors | Edit boot.ipxe, add: `set VERIFY off` (testing only!) |
| "Connection refused" | Check firewall: `sudo ufw allow 443/tcp` |

---

## 📝 Common Commands

### Build ISO
```bash
./scripts/build.sh https://your-server.com
```

### Write to USB
```bash
sudo dd if=dist/ipxe-custom.iso of=/dev/sdX bs=4M status=progress && sync
```

### Test on Local Network
```bash
python3 -m http.server 8000 --directory /var/www/ipxe
# Then boot with: set SERVER http://YOUR_IP:8000
```

### Check Server Logs
```bash
# Nginx
tail -f /var/log/nginx/ipxe-access.log

# Apache2
tail -f /var/log/apache2/ipxe-access.log
```

---

## 📚 Resources

- **iPXE Official**: https://ipxe.org/
- **iPXE Scripting**: https://ipxe.org/scripting
- **Boot Script Syntax**: https://ipxe.org/cmd/menu
- **NetbootXYZ** (alternative): https://netboot.xyz/

---

## 💡 Next Steps

1. ✅ Build the ISO: `./scripts/build.sh https://your-server.com`
2. ✅ Set up server with menu.ipxe and ISO files
3. ✅ Test with QEMU locally
4. ✅ Test with USB on physical hardware
5. ✅ Customize menu.ipxe for your needs
6. ✅ Distribute ISO to users

---

## ❓ FAQ

**Q: Can I use self-signed certificates?**  
A: Yes, but add `set VERIFY off` to boot.ipxe (testing only for security reasons)

**Q: How big is the ISO?**  
A: ~200-300 MB (depends on build options)

**Q: Can I boot without a server?**  
A: No, it needs to fetch menu.ipxe. But you can modify boot.ipxe for offline boot.

**Q: Does it work on old BIOS systems?**  
A: Yes, iPXE supports legacy BIOS and modern UEFI.

**Q: Can I add Windows ISOs?**  
A: Yes, just add them to /iso/ and menu.ipxe

---

## 📞 Support

- Check IPXE_BUILD_PLAN.md for detailed technical information
- Review server-configs/ for web server setup examples
- Test with QEMU before deploying to production

---

**Happy booting! 🚀**
