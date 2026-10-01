#!/usr/bin/env bash

set -e

# Prevent non-interactive apt prompts during system installs
export DEBIAN_FRONTEND=noninteractive

echo "=== CUDA, Profiling, and GitHub CLI Setup ==="

# 1. Require sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run this script with sudo:"
  echo "    sudo ./setup.sh"
  exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

echo "[+] Target user: $REAL_USER"
echo "[+] Home directory: $USER_HOME"

# 2. Add GitHub CLI official repository
echo "[+] Adding official GitHub CLI repository..."
apt-get update -y
apt-get install -y curl wget gpg chafa

mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# 3. Update APT repositories
echo "[+] Updating APT package list..."
apt-get update -y

# 4. Automatically detect the latest Nsight Compute package version
echo "[+] Resolving latest Nsight Compute package name..."
NCU_PKG=$(apt-cache search "^nsight-compute-[0-9]" | awk '{print $1}' | sort -V | tail -n 1)

if [ -z "$NCU_PKG" ]; then
    NCU_PKG=$(apt-cache search "^nsight-compute" | awk '{print $1}' | sort -V | tail -n 1)
fi

if [ -z "$NCU_PKG" ]; then
    NCU_PKG=$(apt-cache search "^cuda-nsight-compute" | awk '{print $1}' | sort -V | tail -n 1)
fi

if [ -z "$NCU_PKG" ]; then
    NCU_PKG="nsight-compute*"
fi

echo "[+] Selected Nsight Compute package: '$NCU_PKG'"

# 5. Non-interactive installation (including 'gh')
echo "[+] Installing nvidia-cuda-toolkit, $NCU_PKG, and gh..."
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
    nvidia-cuda-toolkit $NCU_PKG gh

# 6. Locate installed binaries
NVCC_PATH=$(which nvcc 2>/dev/null || true)

NCU_PATH=$(which ncu 2>/dev/null || true)
if [ -z "$NCU_PATH" ]; then
    NCU_PATH=$(find /opt/nvidia/nsight-compute/ /usr/local/cuda/ /usr/bin/ -name ncu -type f 2>/dev/null | head -n 1 || true)
fi

echo "[+] Binary location - nvcc: ${NVCC_PATH:-Not Found}"
echo "[+] Binary location - ncu:  ${NCU_PATH:-Not Found}"

# 7. Create System-Wide Symlinks in /usr/local/bin
echo "[+] Setting up system-wide symlinks in /usr/local/bin..."

if [ -n "$NVCC_PATH" ]; then
    ln -sf "$NVCC_PATH" /usr/local/bin/nvcc
fi

if [ -n "$NCU_PATH" ]; then
    ln -sf "$NCU_PATH" /usr/local/bin/ncu
fi

# 8. Update user's ~/.bashrc
BASHRC="$USER_HOME/.bashrc"
echo "[+] Configuring PATH in $BASHRC..."

if ! grep -q "/usr/local/cuda/bin" "$BASHRC"; then
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> "$BASHRC"
fi

if ! grep -q "/usr/local/cuda/lib64" "$BASHRC"; then
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> "$BASHRC"
fi

if [ -n "$NCU_PATH" ]; then
    NCU_DIR=$(dirname "$NCU_PATH")
    if ! grep -q "$NCU_DIR" "$BASHRC"; then
        echo "export PATH=$NCU_DIR:\$PATH" >> "$BASHRC"
    fi
fi

# Fixed chown: using trailing colon to automatically resolve the user's primary group
chown "$REAL_USER:" "$BASHRC"

# 9. Enable non-root GPU profiling permissions
echo "[+] Enabling non-root GPU performance counter access..."
echo "options nvidia NVreg_RestrictProfilingToAdminUsers=0" > /etc/modprobe.d/nvidia-profiling.conf
modprobe nvidia NVreg_RestrictProfilingToAdminUsers=0 2>/dev/null || true

# 10. GitHub Authentication Prompt
echo "======================================================"
echo "[+] GitHub CLI Installed. Starting authentication..."
echo "[!] We are dropping root privileges to log YOU in."
echo "======================================================"

# Run 'gh auth login' as the normal user, not as root
sudo -u "$REAL_USER" gh auth login || echo "[!] GitHub login was skipped/aborted. You can run 'gh auth login' later."

echo "======================================================"
echo "[✓] Installation complete!"
echo "    Reload your shell settings by running:"
echo "    source ~/.bashrc"
echo "======================================================"
