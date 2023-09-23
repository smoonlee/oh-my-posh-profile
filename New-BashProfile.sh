#!/bin/bash
set -e

clear

# Display a header message
echo "###############################"
echo " Oh My Posh - Installer Script "
echo "###############################"

# Function to update local package repositories
update_local_system() {
    sudo apt update
    sudo apt install -y gcc build-essential
}

# Function to install HomeBrew Package Manager
install_homebrew() {
    local brew_path="/home/linuxbrew/.linuxbrew/bin/brew"

    if [ -e "$brew_path" ]; then
        echo "Home Brew Package Manager is already installed, updating..."
        brew update
    else
        echo "Home Brew Package Manager is missing - installing Brew..."

        # Install Brew
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Brew Package Manager to the local profile
        local profile_file="$HOME/.profile"
        local line_to_add='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

        if ! grep -qF "$line_to_add" "$profile_file"; then
            echo "" >>"$profile_file"
            echo "$line_to_add" >>"$profile_file"
            echo "Added the line to $profile_file"
        else
            echo "The line is already in $profile_file. Skipping."
        fi

        # Reload Shell Profile for Brew command support
        . $HOME/.profile

        if [ $? -eq 0 ]; then
            echo "Brew has been installed successfully."
        else
            echo "Failed to install Brew."
            exit 1
        fi
    fi
}

# Function to install Oh-My-Posh
configure_oh_my_posh() {
    if brew list jandedobbeleer/oh-my-posh/oh-my-posh &>/dev/null; then
        echo "Oh-My-Posh is already installed, updating..."
        brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh
    else
        # Install Oh-My-Posh
        brew install jandedobbeleer/oh-my-posh/oh-my-posh

        # Download Oh-My-Posh Theme
        ProfileThemeName="quick-term-smoon.omp.json"
        ProfileUri="https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/main/$ProfileThemeName"
        TargetPath="$(brew --prefix oh-my-posh)/themes/$ProfileThemeName"

        if curl -s -f "$ProfileUri" -o "$TargetPath"; then
            echo "$ProfileThemeName downloaded"
        else
            echo "Error: Failed to download $ProfileThemeName"
            exit 1
        fi

        # Configure Bash Profile Prompt
        # Define the theme configuration file path
        theme_config="$(brew --prefix oh-my-posh)/themes/$ProfileThemeName"

        # Append the command to initialize oh-my-posh with the theme config to .profile
        echo "eval \"\$(oh-my-posh init bash --config $theme_config)\"" >> "$HOME/.profile"
    fi
}

# Function to update Bash Profile
update_bash_profile() {

    echo "Reloading Bash Profile"
    . $HOME/.profile
}

# Clear the screen
clear

echo "-------------------------------------------------------"
echo "        Oh My Posh Profile :: Bash Profile Setup       "
echo "-------------------------------------------------------"
echo ""

# Print a header
echo "-> Update Local Apt Cache"
update_local_system

# Install HomeBrew Package Manager
echo ""
echo "-> Installing Brew Package Manager"
install_homebrew

# Install Oh-My-Posh
echo ""
echo "-> Installing Oh-My-Posh"
configure_oh_my_posh

# Update Local Profile
echo ""
echo "-> Update Bash profile"
update_bash_profile
