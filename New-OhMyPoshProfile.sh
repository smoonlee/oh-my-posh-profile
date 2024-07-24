#!/bin/bash
scriptVersion=v3

# Function - update System Packages
function updateSystem() {
    echo "[OhMyPoshProfile $scriptVersion] :: Update System Packages"
    sudo apt update
    sudo apt upgrade -y && sudo apt install -y gcc build-essential apt-utils
    sudo apt autoremove -y
}

function installApplications() {
    echo ""
    echo "[OhMyPoshProfile $scriptVersion] :: Installing Applications"

    # Install Azure CLI
    if ! command -v /usr/bin/az &>/dev/null; then
        echo "[OhMyPoshProfile $scriptVersion] :: Installing Azure CLI"
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    else
        echo "[OhMyPoshProfile $scriptVersion] :: Azure CLI already installed"
    fi

    # Install Kubectl
    if ! command -v kubectl &>/dev/null; then
        echo ""   
        echo "[OhMyPoshProfile $scriptVersion] :: Installing Kubectl"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    else
        echo "[OhMyPoshProfile $scriptVersion] :: Kubectl already installed"
    fi
}

# Function - Install Brew Package Manager
function installBrewPackageManager() {
    echo ""
    echo "[OhMyPoshProfile $scriptVersion] :: Installing Brew Package Manager"

    # Check if Homebrew is already installed
    if command -v /home/linuxbrew/.linuxbrew/bin/brew &>/dev/null; then
        echo "[OhMyPoshProfile $scriptVersion] :: Homebrew is already installed. Skipping installation."
        return 0
    fi

    # Check if curl is installed, if not, install it
    if ! command -v /usr/bin/curl &>/dev/null; then
        echo "curl is not installed. Installing curl..."
        if [[ $(lsb_release -is) == "Ubuntu" ]]; then
            sudo apt update
            sudo apt install -y curl
        else
            echo "Error: curl is not installed and cannot be automatically installed on this system. Please install curl manually and try again."
            return 1
        fi
    fi

    # Download and Install Homebrew
    echo "[OhMyPoshProfile $scriptVersion] :: Downloading and installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Check if installation was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Homebrew installation failed."
        return 1
    fi

    # Add Homebrew to User Profile/Session
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>"$HOME/.profile"

    # Reload Profile with Homebrew
    echo "[OhMyPoshProfile $scriptVersion] :: Homebrew installed successfully."
    . $HOME/.profile
}

# Function - Install Oh-My-Posh
function installOhMyPosh() {
    echo ""
    echo "[OhMyPoshProfile $scriptVersion] :: Installing Oh My Posh"

    # Check if Oh My Posh is already installed
    if command -v /home/linuxbrew/.linuxbrew/bin/oh-my-posh &>/dev/null; then
        echo "[OhMyPoshProfile $scriptVersion] :: Oh My Posh is already installed. Skipping installation."
        return 0
    fi

    # Check if Homebrew is installed, if not, install it
    if ! command -v brew &>/dev/null; then
        echo "Homebrew is not installed. Installing Brew Package Manager..."
        installBrewPackageManager
        if [[ $? -ne 0 ]]; then
            echo "Error: Homebrew installation failed. Cannot proceed with Oh My Posh installation."
            return 1
        fi
    fi

    # Install Oh-My-Posh
    brew install jandedobbeleer/oh-my-posh/oh-my-posh

    # Check if installation was successful
    if [[ $? -ne 0 ]]; then
        echo "Error: Oh My Posh installation failed."
        return 1
    fi

    echo "[OhMyPoshProfile $scriptVersion] :: Oh My Posh installed successfully."

    # Reload Profile with Oh-My-Posh
    . $HOME/.profile
}

function configureOhMyPoshTheme() {
    echo ""
    echo "[OhMyPoshProfile $scriptVersion] :: Configure Posh Theme"

    # Check dependencies
    if ! command -v curl &>/dev/null || ! command -v oh-my-posh &>/dev/null; then
        echo "Error: Required dependencies not found. Please make sure 'curl' and 'oh-my-posh' are installed." >&2
        return 1
    fi

    # Theme configuration
    local themeProfile="https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-azure.omp.json"
    local themeName=$(basename "$themeProfile")
    local outFile="$(brew --prefix oh-my-posh)/themes/$themeName"

    # Download theme
    echo "[OhMyPoshProfile $scriptVersion] :: Downloading [$themeName]"
    if ! curl -fsSL "$themeProfile" -o "$outFile"; then
        echo "Error: Failed to download theme." >&2
        return 1
    fi

    # Add Oh-My-Posh to user profile
    local initCommand="eval \"\$(oh-my-posh init bash --config $(brew --prefix oh-my-posh)/themes/$themeName)\""
    if ! grep -qF "$initCommand" "$HOME/.profile"; then
        echo "$initCommand" >>"$HOME/.profile"
    fi

    # Reload profile
    echo "[OhMyPoshProfile $scriptVersion] :: Reloading Profile"
    . $HOME/.profile
}

function configureKubectl() {
    echo ""
    echo "[OhMyPoshProfile $scriptVersion] :: Patching Kubernetes Configuration into WSL"

    localUser="Simon"
    kubeDir="$HOME/.kube"
    configFile="/mnt/c/Users/$localUser/.kube/config"

    # Check if kube directory exists, if not create it
    if [ ! -d "$kubeDir" ]; then
        mkdir -p "$kubeDir"
        echo "[OhMyPoshProfile $scriptVersion] :: Created $kubeDir directory"
    fi

    # Check if config file exists
    if [ ! -f "$configFile" ]; then
        echo "Error: Kubernetes config file not found at $configFile"
        return 1
    fi

    # Create symbolic link to config file
    ln -sf "$configFile" "$kubeDir/config"
    echo "[OhMyPoshProfile $scriptVersion] :: Kubernetes configuration symlink created"
}

#
##
echo "[OhMyPoshProfile $scriptVersion] :: Linux Setup Script"

updateSystem
installApplications
installBrewPackageManager
installOhMyPosh
configureOhMyPoshTheme
configureKubectl

# Load Profile
. .profile
