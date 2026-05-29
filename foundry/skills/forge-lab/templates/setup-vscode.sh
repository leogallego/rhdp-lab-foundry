#!/bin/bash
set -euo pipefail

echo "=== Configuring code-server (VS Code) ==="

# Sudoers for rhel user
echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
chmod 440 /etc/sudoers.d/rhel_sudoers

# SSH key generation
sudo -u rhel mkdir -p /home/rhel/.ssh
sudo -u rhel chmod 700 /home/rhel/.ssh
if [ ! -f /home/rhel/.ssh/id_rsa ]; then
  sudo -u rhel ssh-keygen -t rsa -b 4096 -C "rhel@$(hostname)" \
    -f /home/rhel/.ssh/id_rsa -N ""
fi
sudo -u rhel chmod 600 /home/rhel/.ssh/id_rsa*

# Disable firewall
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

# Reconfigure code-server: bind all interfaces, no auth
systemctl stop code-server
mv /home/rhel/.config/code-server/config.yaml \
  /home/rhel/.config/code-server/config.bk.yaml 2>/dev/null || true

tee /home/rhel/.config/code-server/config.yaml << 'CSCFG'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
CSCFG

systemctl start code-server

# Install additional tools
dnf install -y git nano jq

# Install VS Code extensions
echo "Installing Ansible extension..."
sudo -u rhel code-server --install-extension redhat.ansible || true
echo "Installing YAML extension..."
sudo -u rhel code-server --install-extension redhat.vscode-yaml || true

# Configure git for the rhel user
sudo -u rhel git config --global user.email "student@lab.example.com"
sudo -u rhel git config --global user.name "Student"
sudo -u rhel git config --global init.defaultBranch main
sudo -u rhel git config --global http.sslVerify false

# Configure git credential storage for Gitea
sudo -u rhel git config --global credential.helper store
echo "http://gitea:ansible123!@gitea:3000" \
  | sudo -u rhel tee /home/rhel/.git-credentials > /dev/null
sudo -u rhel chmod 600 /home/rhel/.git-credentials

# Prepare lab workspace
mkdir -p /home/rhel/lab_exercises
chown -R rhel:rhel /home/rhel/lab_exercises

echo "=== code-server setup complete ==="
