#!/bin/bash

set -e

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================
PRINT_PREFIX="FEDORA SETUP SCRIPT >> "
SEPARATOR_THIN="----------------------------------------"
SEPARATOR_THICK="========================================"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Software installation mappings
declare -A SOFTWARE_INSTALLERS=(
    ["Visual Studio Code"]="install_vscode"
    ["Multimedia codecs"]="multimedia_setup"
    ["Tailscale"]="install_tailscale"
    ["Insync"]="install_insync"
)

# Dev tools mappings
declare -A DEV_TOOLS=(
    ["C/C++"]="c_setup"
    [".NET/C#"]="dotnet_setup"

    # TODO...
    # ["Go"]="go_setup"
    # ["Java"]="java_setup"
    # ["Python"]="python_setup"
    # ["Haskell"]="haskell_setup"
    # ["PHP"]="php_setup"
    # ["Node.js"]="node_setup"
)

# =============================================================================
# UTILS
# =============================================================================

run_dnf() {
    # wrapper around the dnf command that adds error handling and logging
    echo "${PRINT_PREFIX}Running: \"dnf $*\"..."
    if ! dnf "$@"; then
        echo "${PRINT_PREFIX}ERROR: dnf command failed: $*" >&2
        return 1
    fi
}

# =============================================================================
# SYSTEM INITIALIZATION
# =============================================================================

init() {
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

update() {
    echo ""
    echo "${PRINT_PREFIX}Updating system packages..."
    run_dnf update -y --refresh
    echo ""
    run_dnf upgrade -y
    echo ""
    echo "${PRINT_PREFIX}System packages were updated! You might need to restart for updates to be completed."
}

install_dnf_packages_from_file() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local package_file="$script_dir/dnf_packages"

    if [[ ! -f "$package_file" ]]; then
        echo ""
        echo "${PRINT_PREFIX}Package file not found: $package_file"
        return 1
    fi

    echo ""
    echo "${PRINT_PREFIX}Installing packages from $package_file..."

    while IFS= read -r package || [[ -n "$package" ]]; do
        if [[ -n "$package" && ! "$package" =~ ^# ]]; then
            echo ""
            run_dnf install -y "$package"
        fi
    done < "$package_file"

    echo ""
    echo "${PRINT_PREFIX}All packages from $package_file have been installed."
}

install_flatpaks_from_file() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local flatpak_file="$script_dir/flatpaks"
    local failed_flatpaks=()

    if [[ ! -f "$flatpak_file" ]]; then
        echo "${PRINT_PREFIX}Flatpak file not found: $flatpak_file"
        return 1
    fi

    echo ""
    echo "${PRINT_PREFIX}Installing Flatpaks from $flatpak_file..."
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | xargs)"

        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            echo ""
            echo "${PRINT_PREFIX}Installing $line..."
            
            if flatpak install -y flathub "$line"; then
                echo "${PRINT_PREFIX}$line installed successfully."
            else
                echo "${PRINT_PREFIX}Failed to install $line — continuing with next."
                failed_flatpaks+=("$line")
            fi
        fi
    done < "$flatpak_file"

    echo "${SEPARATOR_THIN}"
    # Check if the failure list is empty or not
    if [[ ${#failed_flatpaks[@]} -eq 0 ]]; then
        echo "${PRINT_PREFIX}All Flatpaks installed successfully!"
    else
        echo "${PRINT_PREFIX}The following packages failed to install:"
        for failed in "${failed_flatpaks[@]}"; do
            echo "  - $failed"
        done
    fi
}

install_nvidia_drivers() {
    echo ""
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

# =============================================================================
# SOFTWARE INSTALLATION FUNCTIONS
# =============================================================================

multimedia_setup() {
    echo ""
    run_dnf group install multimedia -y
    # TODO: https://rpmfusion.org/Howto/Multimedia
}

install_vscode() {
    echo "${PRINT_PREFIX}Setting up Visual Studio Code repository..."
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | tee /etc/yum.repos.d/vscode.repo > /dev/null

    echo "${PRINT_PREFIX}Installing Visual Studio Code..."
    dnf check-update
    run_dnf install code -y

    export EDITOR="code"
}

install_insync() {
    echo "${PRINT_PREFIX}Installing Insync..."
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

    run_dnf install insync -y
}

install_tailscale() {
    dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    run_dnf install tailscale -y
    systemctl enable --now tailscaled
    echo "${PRINT_PREFIX}Tailscale installed and started."
    echo "${PRINT_PREFIX}Run 'tailscale up' command to authenticate and connect to your Tailscale network."
}

# TODO...
# install_docker() {
#     echo "${PRINT_PREFIX}Docker installation not implemented yet..."
# }

# =============================================================================
# DEVELOPMENT TOOLS SETUP FUNCTIONS
# =============================================================================

c_setup() {
    echo "${PRINT_PREFIX}Installing C/C++ development tools..."
    run_dnf group install development-tools -y
    run_dnf install clang -y
    run_dnf install gdb valgrind systemtap ltrace strace -y
}

dotnet_setup() {
    # https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora
    echo "${PRINT_PREFIX}Installing .NET SDK and ASP.NET Core Runtime..."
    run_dnf install dotnet-sdk-10.0 -y
    run_dnf install aspnetcore-runtime-10.0 -y
}

# java_setup() {
#     echo "${PRINT_PREFIX}Java setup not implemented yet..."
# }

# python_setup() {
#     echo "${PRINT_PREFIX}Python setup not implemented yet..."
# }

# haskell_setup() {
#     echo "${PRINT_PREFIX}Haskell setup not implemented yet..."
# }

# php_setup() {
#     echo "${PRINT_PREFIX}PHP setup not implemented yet..."
# }

# node_setup() {
#     echo "${PRINT_PREFIX}Node.js setup not implemented yet..."
# }

# =============================================================================
# MENU SYSTEM
# =============================================================================

show_submenu() {
    local menu_title="$1"
    local -n menu_map="$2"
    
    while true; do
        echo ""
        echo "$SEPARATOR_THICK"
        echo "${menu_title}:"
        echo "$SEPARATOR_THICK"
        echo "1) Install/Setup all"

        local -a display_keys=()
        local index=2
        
        # Get keys in sorted order
        while IFS= read -r key; do
            echo "$index) $key"
            display_keys[$index]="$key"
            ((index++))
        done < <(printf '%s\n' "${!menu_map[@]}" | sort)
        echo "${SEPARATOR_THIN}"
        echo "0) Back to Main Menu"
        echo "${SEPARATOR_THICK}"
      
        local max_choice=$((index - 1))
        local choice

        read -rp "Enter your choice [0-$max_choice]: " choice
        
        if [[ "$choice" == "1" ]]; then
            echo "${PRINT_PREFIX}Running all installations..."
            for key in "${!menu_map[@]}"; do
                echo ""
                echo "${PRINT_PREFIX}Running: $key"
                ${menu_map[$key]}
            done
            echo "${PRINT_PREFIX}All installations complete!"
            
        elif [[ "$choice" -ge 1 && "$choice" -lt "$index" ]]; then
            local selected_key="${display_keys[$choice]}"
            echo ""
            echo "${PRINT_PREFIX}Running: $selected_key"
            ${menu_map[$selected_key]}
            
        elif [[ "$choice" == "0" ]]; then
            break
            
        else
            echo "${PRINT_PREFIX}Invalid option. Please try again."
            sleep 1
        fi
    done
}

software_submenu() {
    show_submenu "Software Installation Menu" SOFTWARE_INSTALLERS
}

dev_setup_submenu() {
    show_submenu "Dev Setup Menu" DEV_TOOLS
}

show_menu() {
    echo ""
    echo "$SEPARATOR_THICK"
    echo "Main Menu - Select an option:"
    echo "$SEPARATOR_THICK"

    echo " 1) Update System"
    echo " 2) Install DNF Packages"
    echo " 3) Install Flatpaks"
    echo " 4) Software Submenu"
    echo " 5) Dev Setup Submenu"
    echo " 6) Install NVIDIA Drivers"

    echo "$SEPARATOR_THIN"
    echo " 0) Exit"
    echo "$SEPARATOR_THICK"
}
read_choice() {
    local choice
    read -rp "Enter your choice [0-6]: " choice
    case $choice in
        0) 
            echo ""; 
            echo "${PRINT_PREFIX}Exiting."; 
            echo ""; 
            exit 0 ;;
        1) update ;;
        2) install_dnf_packages_from_file ;;
        3) install_flatpaks_from_file ;;
        4) software_submenu ;;
        5) dev_setup_submenu ;;
        6) install_nvidia_drivers ;;
        *) echo "${PRINT_PREFIX}Invalid option. Please try again."; sleep 1 ;;
    esac
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    init
    while true; do
        show_menu
        read_choice
    done
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

main "$@"