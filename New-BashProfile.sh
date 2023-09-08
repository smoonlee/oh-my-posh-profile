
# Update Local packages
sudo apt update && sudo apt install build-essential -y
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/smooney/.profile
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install oh-my-posh
brew install jandedobbeleer/oh-my-posh/oh-my-posh

# Download theme
wget https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/quick-term-smoon.omp.json -O $(brew --prefix oh-my-posh)/themes/quick-term-smoon.omp.json

# Add to profile
echo 'eval "$(oh-my-posh init bash --config $(brew --prefix oh-my-posh)/themes/quick-term-smoon.omp.json)"' >> $HOME/.profile

# Reload Bash Profile
. ~/.profile