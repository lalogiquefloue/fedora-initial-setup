#!/bin/bash

set -e

# --- GLOBAL VARIABLES ---
PRINT_PREFIX="FEDORA SETUP SCRIPT >> "

# --- FUNCTIONS --
init(){
    REL="$(rpm -E %fedora)"
    echo "${PRINT_PREFIX}Fedora $REL is running."

    # Check for root
    if [ "$(id -u)" -ne 0 ]; then
        echo "${PRINT_PREFIX}This script must be run as root."
        exit 1
    fi

    # Check for flatpak and install if needed
    if ! command -v flatpak &> /dev/null; then
        echo "${PRINT_PREFIX}Flatpak not found. Installing flatpak..."
        sudo dnf install -y flatpak
    else
        echo "${PRINT_PREFIX}Flatpak is already installed."
    fi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Check for RPM Fusion
    if ! dnf repolist | grep -q "rpmfusion-free"; then
        echo "${PRINT_PREFIX}RPM Fusion not found. Installing RPM Fusion repositories..."
        sudo dnf install -y \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${REL}.noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${REL}.noarch.rpm
    else
        echo "${PRINT_PREFIX}RPM Fusion repositories are already enabled."
    fi
}

update(){
    echo "${PRINT_PREFIX}Updating system packages..."
    dnf update -y --refresh
    dnf upgrade -y
    echo "${PRINT_PREFIX}System packages were updated! You might need to restart for updates to be completed."
}

 multimedia_setup(){
    dnf group install multimedia -y
}

install_vscode(){
    echo "${PRINT_PREFIX}Setting up Visual Studio Code repository..."
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | tee /etc/yum.repos.d/vscode.repo > /dev/null

    echo "${PRINT_PREFIX}Installing Visual Studio Code..."
    dnf check-update
    dnf install code -y

    export EDITOR="code"
}

install_docker(){
    echo "Not implemented yet..."
}

c_setup(){
    dnf group install development-tools -y
    dnf install clang -y
    dnf install gdb valgrind systemtap ltrace strace -y
}

dotnet_setup(){
    # https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora
    dnf install dotnet-sdk-10.0
    dnf install aspnetcore-runtime-10.0
}

java_setup(){
    echo "Not implemented yet..."
}

python_setup(){
    echo "Not implemented yet..."
}

haskell_setup(){
    echo "Not implemented yet..."
}

php_setup(){
    echo "Not implemented yet..."
}

node_setup(){
    echo "Not implemented yet..."
}

install_insync(){
    rpm --import https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key

    cat <<EOF > /etc/yum.repos.d/insync.repo
[insync]
name=insync repo
baseurl=http://yum.insync.io/fedora/\$releasever/
gpgcheck=1
gpgkey=https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key
enabled=1
metadata_expire=120m
EOF

    yum install insync -y
}

install_tailscale(){
    echo "${PRINT_PREFIX}Installing Tailscale..."
    dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    dnf install tailscale -y
    systemctl enable --now tailscaled
    echo "${PRINT_PREFIX}Tailscale installed and started."
    echo "${PRINT_PREFIX}Run 'tailscale up' command to authenticate and connect to your Tailscale network."
}

install_nvidia_drivers(){
    echo "${PRINT_PREFIX}Checking for NVIDIA GPU..."
    if lspci | grep -i "nvidia" > /dev/null; then
        echo "${PRINT_PREFIX}NVIDIA GPU detected. Installing drivers..."
        sudo dnf install -y akmod-nvidia
        sudo dnf install -y xorg-x11-drv-nvidia-cuda
        echo "${PRINT_PREFIX}NVIDIA drivers installed successfully."
    else
        echo "${PRINT_PREFIX}No NVIDIA GPU detected. Skipping driver installation."
    fi
}

install_dnf_packages_from_file() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local package_file="$script_dir/dnf_packages"

    if [[ ! -f "$package_file" ]]; then
        echo "${PRINT_PREFIX}Package file not found: $package_file"
        return 1
    fi

    echo "${PRINT_PREFIX}Installing packages from $package_file..."

    while IFS= read -r package || [[ -n "$package" ]]; do
        if [[ -n "$package" && ! "$package" =~ ^# ]]; then
            echo "${PRINT_PREFIX}Installing $package..."
            dnf install -y "$package"
        fi
    done < "$package_file"

    echo "${PRINT_PREFIX}All packages from $package_file have been installed."
}

install_flatpaks_from_file() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local flatpak_file="$script_dir/flatpaks"

    if [[ ! -f "$flatpak_file" ]]; then
        echo "${PRINT_PREFIX}Flatpak file not found: $flatpak_file"
        return 1
    fi

    echo "${PRINT_PREFIX}Installing Flatpaks from $flatpak_file..."
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Trim leading/trailing whitespace
        line="$(echo "$line" | xargs)"

        # Ignore comments and empty lines
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            echo "${PRINT_PREFIX}Installing $line..."
            if flatpak install -y flathub "$line"; then
                echo "${PRINT_PREFIX}$line installed successfully."
            else
                echo "${PRINT_PREFIX}Failed to install $line — continuing with next."
            fi
        fi
    done < "$flatpak_file"

    echo "${PRINT_PREFIX}All Flatpaks from $flatpak_file have been installed."
}

# --- CLI ---
show_menu() {
    echo "${PRINT_PREFIX}Please select an option:"
    echo "1) Update system packages"
    echo "2) Install DNF packages from \"dnf_packages\" file"
    echo "3) Install Flatpacks from \"flatpaks\" file"
    echo "4) Install Nvidia drivers"
    echo "5) Software Installation Menu"
    echo "6) Dev tools setup"
    echo "7) Exit"
}

read_choice() {
    local choice
    read -rp "${PRINT_PREFIX}Enter your choice [1-7]: " choice
    case $choice in
        1) update ;;
        2) install_dnf_packages_from_file ;;
        3) install_flatpaks_from_file ;;
        4) install_nvidia_drivers ;;
        5) software_submenu ;;
        6) dev_setup_submenu ;;
        7) echo "${PRINT_PREFIX}Exiting."; exit 0 ;;
        *) echo "${PRINT_PREFIX}Invalid option. Please try again."; sleep 1 ;;
    esac
}

software_submenu() {
    while true; do
        echo "${PRINT_PREFIX}Software Installation Menu:"
        
        echo "1) Install all software"
        echo "2) Install Visual Studio Code"
        echo "3) Install multimedia codecs"
        echo "4) Install Tailscale"
        echo "5) Install Insync"
        echo "6) Back to Main Menu"

        local subchoice
        read -rp "${PRINT_PREFIX}Enter your choice [1-6]: " subchoice
        case $subchoice in
            1) 
                multimedia_setup
                install_vscode
                install_tailscale
                ;;
            2) install_vscode ;;
            3) multimedia_setup ;;
            4) install_tailscale ;;
            5) install_insync ;;
            6) break ;;  # break the submenu loop and return to main
            *) echo "${PRINT_PREFIX}Invalid option. Please try again."; sleep 1 ;;
        esac
    done
}

dev_setup_submenu() {
    while true; do
        echo "${PRINT_PREFIX}Dev Setup Menu:"
        echo "1) Back to Main Menu"
        echo "2) Setup all"
        echo "3) Setup C/C++"
        echo "4) Setup .Net/C#"
        # echo "4)"
        # echo "5)"
        # echo "6)"
        # echo "7)"
        # echo "8)"
        # echo "9)"
        # echo "10)"

        local subchoice
        read -rp "${PRINT_PREFIX}Enter your choice [1-7]: " subchoice
        case $subchoice in
            1) break ;;  # break the submenu loop and return to main
            2) 
                c_setup
                dotnet_setup
                # java_setup
                # python_setup
                # haskell_setup
                # php_setup
                # node_setup
                ;;
            3) c_setup ;;
            4) dotnet_setup ;;
            # 5) ;;
            # 6) ;;
            # 7) ;;
            # 8) ;;
            # 9) ;;
            # 10) ;;

            *) echo "${PRINT_PREFIX}Invalid option. Please try again."; sleep 1 ;;
        esac
    done
}


# --- MAIN ---
main(){
    init
    while true; do
        show_menu
        read_choice
    done
}

# --- SCRIPT ENTRYPOINT ---
main "$@"
