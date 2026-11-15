for ip in 192.168.123.103 192.168.123.117; do
  echo "========== INSTALLING ON $ip =========="

  ssh -J root@10.13.13.15 root@$ip 'bash -s' <<'REMOTE'
set -euo pipefail

# Disable swap
swapoff -a
sed -i '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab

# Kernel modules
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Kubernetes networking
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Docker official repository: containerd
apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  >/etc/apt/sources.list.d/docker.list

# Official Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y containerd.io kubelet=1.36.5-1.1 kubeadm=1.36.5-1.1 kubectl=1.36.5-1.1
apt-mark hold containerd.io kubelet kubeadm kubectl

# Configure containerd with systemd cgroups
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd
systemctl enable kubelet

echo "===== INSTALLED VERSIONS ====="
containerd --version
kubelet --version
kubeadm version -o short

echo "===== CONTAINERD STATUS ====="
systemctl is-active containerd
REMOTE

done

ssh -J root@10.13.13.15 root@192.168.123.103 \
  'apt-get install -y nvidia-driver-595-server'

ssh -J root@10.13.13.15 root@192.168.123.103 '
set -e

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit
'

ssh -J root@10.13.13.15 root@192.168.123.103 '
set -e
systemctl restart containerd
systemctl is-active containerd
crictl info >/dev/null 2>&1 && echo "CRI: OK" || echo "CRI: CHECK REQUIRED"
'

