#!/bin/bash
clear 

# Display a header message
echo "###############################"
echo " Oh My Posh - Installer Script "
echo "###############################"

# Update local package repositories
echo ""
echo "-> Updating Local Packages"
sudo apt update

# Install essential build tools
echo ""
echo "-> Installing Build Essentials"
sudo apt install build-essential -y

# Install Brew package manager
echo ""
echo "-> Installing Homebrew package manager"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install Oh My Posh
echo ""
echo "-> Installing Oh-My-Posh"
brew install jandedobbeleer/oh-my-posh/oh-my-posh

# Download Oh-My-Posh Profile and add to profile
wget https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-smoon.omp.json -O "$(brew --prefix oh-my-posh)/themes/quick-term-smoon.omp.json"
(echo; echo 'eval "$(oh-my-posh init bash --config $(brew --prefix oh-my-posh)/themes/quick-term-smoon.omp.json)"') >> ~/.profile

# Print completion message
echo ""
echo "Installation completed successfully!"


