#!/usr/bin/env bash
set -euo pipefail

log() {
  echo -e "\n--> $1"
}

install_system_updates() {
  log "Installing System Updates and Essential Packages"
  sudo apt update
  sudo apt dist-upgrade -y
  sudo apt install -y build-essential gcc curl wget gnupg lsb-release apt-transport-https ca-certificates software-properties-common
}

install_homebrew() {
  log "Installing Homebrew Package Manager"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    echo '❌ Homebrew installation failed'
    exit 1
  }

  log "Adding Brew to User Profile"
  {
    echo
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  } >> "$HOME/.bashrc"

  {
    echo
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  } >> "$HOME/.profile"

  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

install_oh_my_posh() {
  log "Installing Oh My Posh"
  brew install jandedobbeleer/oh-my-posh/oh-my-posh

  # Theme configuration
  themeProfile="https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-cloud.omp.json"
  themeName=$(basename "$themeProfile")
  outFile="$(brew --prefix oh-my-posh)/themes/$themeName"

  log "Downloading Theme: $themeName"
  if ! curl -fsSL "$themeProfile" -o "$outFile"; then
    echo "❌ Error: Failed to download theme." >&2
    exit 1
  fi

  log "Updating Profile with Oh My Posh"
  themePath="$(brew --prefix oh-my-posh)/themes/$themeName"
  initCommand="eval \"\$(oh-my-posh init bash --config '$themePath')\""

  if ! grep -qF "$initCommand" "$HOME/.profile"; then
    echo "$initCommand" >> "$HOME/.profile"
  fi
}

install_kubectl() {
  log "Installing kubectl"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' |
    sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

  sudo apt update
  sudo apt install -y kubectl
}

install_helm() {
  log "Installing Helm"
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor |
    sudo tee /usr/share/keyrings/helm.gpg > /dev/null

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" |
    sudo tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null

  sudo apt update
  sudo apt install -y helm
}

install_powershell() {
  log "Installing PowerShell"
  wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb

  sudo apt update
  sudo apt install -y powershell
}

configure_powershell_modules() {
  log "Configuring PowerShell Gallery and Installing Az Module"
  pwsh -Command '
    echo "Updating PSGallery InstallationPolicy [Trusted]"
    Set-PSRepository -Name ''PSGallery'' -InstallationPolicy Trusted

    $modules = @(
      "Az"
      "Microsoft.Graph"
      "Terminal-Icons"
      "Posh-Git"
      "Pester"
      "PSReadLine"
      "PSRule"
      "PSRule.Rules.Azure"
    )

    foreach ($module in $modules) {
      echo "Installing Pwsh Module: $module"
      Install-Module -Repository PSGallery -Name $module -Force
    }
  '
}

install_azure_cli_and_bicep() {
  log "Installing Azure CLI and Bicep"

  # Setup Microsoft signing key
  sudo mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

  # Add Azure CLI repo
  AZ_DIST=$(lsb_release -cs)
  ARCH=$(dpkg --print-architecture)

  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${AZ_DIST} main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null

  sudo apt update && sudo apt install -y azure-cli

  log "Installing Bicep CLI via Azure CLI"
  if ! az bicep install; then
    log "Azure CLI method failed — falling back to manual Bicep install"

    BICEP_VERSION=$(curl -s https://api.github.com/repos/Azure/bicep/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -Lo bicep "https://github.com/Azure/bicep/releases/download/${BICEP_VERSION}/bicep-linux-x64"
    chmod +x bicep
    sudo mv bicep /usr/local/bin/bicep
  fi

  log "Bicep version: $(bicep --version)"
}

echo "#########################################"
echo " Simon's Oh My Posh Profile Setup v3.2.0 "
echo "#########################################"
echo "Install Start Time: $(date)"

main() {
  install_system_updates
  install_homebrew
  install_oh_my_posh
  install_kubectl
  install_helm
  install_powershell
  configure_powershell_modules
  install_azure_cli_and_bicep
  log "✅ All tools installed successfully!"
}

# Execute Installation
main

# Reload Profile
if [[ -f "$HOME/.profile" ]]; then
  . "$HOME/.profile"
fi
