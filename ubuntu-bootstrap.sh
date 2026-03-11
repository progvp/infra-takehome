#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "Error on line $LINENO" >&2' ERR

if [[ "${EUID}" -eq 0 ]]; then
  echo "Do not run this script as root." >&2
  echo "Run it as a regular user with sudo access." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required but not installed." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() {
  echo
  echo "==> $*"
}

require_ubuntu_2404() {
  if [[ ! -r /etc/os-release ]]; then
    echo "/etc/os-release not found. Unsupported system." >&2
    exit 1
  fi

  . /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "This script supports Ubuntu only." >&2
    exit 1
  fi

  if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    echo "This script is intended for Ubuntu 24.04 LTS. Detected: ${VERSION_ID:-unknown}" >&2
    exit 1
  fi
}

apt_install_base() {
  log "Installing base packages"
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg apt-transport-https git make
}

install_docker() {
  log "Installing Docker Engine"

  sudo apt remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  local codename
  codename="$(
    . /etc/os-release
    echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  )"

  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOSRC
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOSRC

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker

  if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker
  fi

  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    ADDED_TO_DOCKER_GROUP=1
  else
    ADDED_TO_DOCKER_GROUP=0
  fi
}

install_opentofu() {
  log "Installing OpenTofu"

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg >/dev/null
  curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg

  cat <<'EOSRC' | sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null
deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main
deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main
EOSRC

  sudo chmod a+r /etc/apt/sources.list.d/opentofu.list
  sudo apt update
  sudo apt install -y tofu
}

install_kubectl() {
  log "Installing kubectl"

  local tmpdir version
  tmpdir="$(mktemp -d)"
  version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

  curl -fsSL -o "${tmpdir}/kubectl" "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"
  curl -fsSL -o "${tmpdir}/kubectl.sha256" "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl.sha256"

  (
    cd "${tmpdir}"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  )

  chmod +x "${tmpdir}/kubectl"
  sudo mv "${tmpdir}/kubectl" /usr/local/bin/kubectl
  rm -rf "${tmpdir}"
}

install_k3d() {
  log "Installing k3d"
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

verify_tools() {
  log "Verifying installed tools"

  git --version
  make --version | head -n 1
  curl --version | head -n 1

  if docker version --format 'Docker client {{.Client.Version}}' >/dev/null 2>&1; then
    docker version --format 'Docker client {{.Client.Version}}'
    docker compose version
  else
    echo "Docker is installed, but the current shell session does not yet have access to /var/run/docker.sock."
    echo "This is expected right after adding the user to the 'docker' group."
    echo "Re-login and run: docker version && docker compose version"
  fi

  tofu version
  kubectl version --client
  k3d version
}

print_next_steps() {
  echo
  echo "Bootstrap complete."
  echo
  echo "Notes:"
  echo "  - Docker service has been installed and started."
  echo "  - OpenTofu, kubectl, k3d, git, make, and curl are installed."
  echo

  if [[ "${ADDED_TO_DOCKER_GROUP:-0}" -eq 1 ]]; then
    echo "You were added to the 'docker' group."
    echo "Log out and log back in before using docker without sudo."
    echo
  fi

  echo "Quick checks after re-login:"
  echo "  docker ps"
  echo "  tofu version"
  echo "  kubectl version --client"
  echo "  k3d version"
}

main() {
  require_ubuntu_2404
  apt_install_base
  install_docker
  install_opentofu
  install_kubectl
  install_k3d
  verify_tools
  print_next_steps
}

main "$@"
