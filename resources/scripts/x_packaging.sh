#!/bin/bash

# This script serves as the main installation script
# for all neccessary packages for a desktop installation.
# Via APT, core utils, browser, graphical environment
# and much more is being installed.
#
# version   1.4.0 stable

# ? Preconfig

## directories and files - absolute & normalized
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BACK="$(readlink -m "${DIR}/../../backups/packaging/$(date '+%d-%m-%Y--%H-%M-%S')")"
LOG="${BACK}/packaging_log"

IF=(
  --yes
  --allow-unauthenticated
  --allow-downgrades
  --allow-remove-essential
  --allow-change-held-packages
)
AI=( sudo apt-get install "${IF[@]}" )
SI=( sudo snap install )
WTL=( tee -a "${LOG}" )

# shellcheck source=../sys/sh/.bash_aliases
. "${DIR}/../sys/sh/.bash_aliases"

# ? Init of package selection

CRITICAL=(
    ubuntu-drivers-common
    intel-microcode
    curl
    wget
    libaio1

    net-tools
    network-manager*
    
    python3-distutils
    snapd

    rxvt-unicode
	alacritty
    vim

    nemo
	nautilus
	python-nautilus
	nautilus-admin

    file-roller
    p7zip-full

    rofi

    policykit-desktop-privileges
    policykit-1-gnome
    gnome-keyring*
    libgnome-keyring0

    firefox
    thunderbird
    thunderbird-locale-de
    thunderbird-locale-en
)

ENV=(
    xorg
    xserver-xorg
    xbacklight

	slick-greeter
    
    i3-gaps
	i3status
    i3lock

    feh
    compton
    
    mesa-utils
    mesa-utils-extra

    gtk2-engines-pixbuf
    gtk2-engines-murrine
    
    lxappearance
    arandr

    pulseaudio
    gstreamer1.0-pulseaudio
    pulseaudio-module-raop
    pulseaudio-module-bluetooth
    
    tmux

	shellcheck
)

MISC=(
    xsel
    xclip

    ruby
    python3-dev

    neofetch
    htop

    fonts-roboto
    fonts-open-sans
    fonts-lyx

    gparted

    fontconfig
    
    evince
    gedit
    nomacs
    
    scrot
    qalculate
	ripgrep

	usb-creator-common
	usb-creator-gtk
)

PACKAGES=( "${CRITICAL[@]}" "${ENV[@]}" "${MISC[@]}" )

# ? Actual script

## init of backup-directory and logfile
function init() {
	if [[ ! -d "$BACK" ]]; then
	    mkdir -p "$BACK"
	fi

	if [[ ! -f "$LOG" ]]; then
	    if [[ ! -w "$LOG" ]]; then
	        &>/dev/null sudo rm "$LOG"
	    fi
	    touch "$LOG"
	fi
}

function choices() {
	inform "Please make your choices:\n"

	read -p 'Would you like to execute ubuntu-driver autoinstall? [Y/n]' -r UDA
	read -p 'Would you like to install OpenJDK? [Y/n]' -r OJDK
	read -p 'Would you like to install Cryptomator? [Y/n]' -r CR
	read -p 'Would you like to install TeX? [Y/n]' -r TEX
	read -p 'Would you like to install ownCloud? [Y/n]' -r OC
	read -p 'Would you like to install Build-Essentials? [Y/n]' -r BE
	read -p 'Would you like to install NeoVIM? [Y/n]' -r NVIM
	read -p 'Would you like to install VS Code? [Y/n]' -r VSC

	VSCE="no"
	if [[ $VSC =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $VSC ]]; then
	    read -p 'Would you like to install recommended VS Code extensions? [Y/n]' -r VSCE
	fi

	read -p 'Would you like to install the JetBrains IDE suite? [Y/n]' -r JBIDE
	
	DOCK="n"
	[ -z "$(which docker)" ] && read -p "Would you like to install Docker? [Y/n]" -r DOCK

	read -p 'Would you like to install RUST? [Y/n]' -r RUST

	echo ''
}

function prechecks() {
	_programs=( apt dpkg apt-get )
	for _program in "${_programs[@]}"; do
		if [[ -z $(which "${_program}") ]]; then
			err "Could not find command ${_program}\n\t\t\t\t\tAborting" | "${WTL[@]}"
			exit 100
		fi
	done
}

function check_lightdm() {
	if [[ -z $(which gdm3) ]]; then
		warn 'It seems like GNOME (GDM3) is installed.\n\t\t\tThis can later conflict with LightDM and require user input.\n'
		read -p 'Would you like to uninstall it? [y/N]' -r _uninstall_gnome

		echo ''
		if [[ $_uninstall_gnome =~ ^(yes|Yes|y|Y) ]]; then
			_uninstall_gnome='true'
		else
			_uninstall_gnome='false'
			warn 'This could require user input later'
		fi
	fi
}

function add_ppas() {
	local _ppas=(
		ppa:git-core/ppa
		ppa:ubuntu-mozilla-security/ppa
		ppa:kgilmer/speed-ricer
		ppa:mmstick76/alacritty
	)

	inform 'Adding necessary PPAs' | "${WTL[@]}"

	ensure "${AI[@]}" software-properties-common >/dev/null

	for _ppa in "${_ppas[@]}"; do
		ensure sudo add-apt-repository -y "$_ppa" &>/dev/null
	done
}

function uninstall_and_log()
{
    local LOG=${1:-"/dev/null"}
    shift

    local IF=(
        --yes
        --allow-unauthenticated
        --allow-downgrades
        --allow-remove-essential
        --allow-change-held-packages
    )

    # cannot just use $*, because when logging, we need to do
    # it iteratively, so we use $@
    for PACKAGE in "$@"; do
        >/dev/null 2>>"${LOG}" sudo apt-get remove "${IF[@]}" "$PACKAGE"
        EC=$?

        if (( EC != 0 )); then
            printf "%-35s | %-15s | %-15s" "${PACKAGE}" "Not Removed" "${EC}"
        else
            printf "%-35s | %-15s | %-15s" "${PACKAGE}" "Removed" "${EC}"
        fi
        printf "\n"

        echo -e "${PACKAGE} (${EC})" &>>"$LOG"
    done
}

function packages() {
	inform "Installing packages\n" "$LOG"

	printf "%-35s | %-15s | %-15s" "PACKAGE" "STATUS" "EXIT CODE"
	printf "\n"

	## needs to be checked first, as LightDM conflicts with these packages
	ensure uninstall_and_log "${LOG}" liblightdm-gobject* liblightdm-qt*

	case $_uninstall_gnome in
		'true')
			# gnome*
			ensure uninstall_and_log "${LOG}" gdm3*
			ensure "${AI[@]}" lightdm >/dev/null 2>>"${LOG}"

			local EC=$?
	    	if (( EC != 0 )); then
	        	printf "%-35s | %-15s | %-15s" "lightdm" "Not Installed" "${EC}"
	    	else
	        	printf "%-35s | %-15s | %-15s" "lightdm" "Installed" "${EC}"
	    	fi
	
	    	printf "\n"
	    	echo -e "lightdm (${EC})" &>>"${LOG}"
			;;
		'false')
			echo ''
			inform "Installing LightDM. Verbose output and user input might necessarry\n"
			ensure "${AI[@]}" lightdm

			echo ''
			local EC=$?
	    	if (( EC != 0 )); then
	        	printf "%-35s | %-15s | %-15s" "lightdm" "Not Installed" "${EC}"
	    	else
	        	printf "%-35s | %-15s | %-15s" "lightdm" "Installed" "${EC}"
	    	fi
	
	    	printf "\n"
	    	echo -e "lightdm (${EC})" &>>"${LOG}"
			;;
	esac

	for _package in "${PACKAGES[@]}"; do
		test_on_success "$LOG" "${AI[@]}" 
	    >/dev/null 2>>"${LOG}" "${AI[@]}" "${_package}"

	    local EC=$?
	    if (( EC != 0 )); then
	        printf "%-35s | %-15s | %-15s" "${_package}" "Not Installed" "${EC}"
	    else
	        printf "%-35s | %-15s | %-15s" "${_package}" "Installed" "${EC}"
	    fi
	
	    printf "\n"
	    echo -e "${_package} (${EC})" &>>"${LOG}"
	done

	uninstall_and_log "${LOG}" suckless-tools
	echo "" | "${WTL[@]}"
	succ "Finished with packaging" "$LOG"
}

## installs icon theme and colorpack
function icons_and_colors() {
	if [[ ! -d "${HOME}/.local/share/icons/Tela" ]]; then
	    inform 'Icon-Theme is being processed' "$LOG"
        (
          cd /tmp || return 1
          ensure wget\
            -O tela.tar.gz\
            "https://github.com/vinceliuice/Tela-icon-theme/archive/2020-02-21.tar.gz" &>>/dev/null

          tar -xvzf "tela.tar.gz" &>>/dev/null
          mv Tela* tela
          cd /tmp/tela/ || return 1
          ensure ./install.sh -a "&>>${LOG}" 
        )
	fi

	(
		&>/dev/null mkdir -p "${HOME}/.themes"
		cp "${DIR}/../design/ant.tar" "${HOME}/.themes"
		cd "${HOME}/.themes" || return 1
		tar -xvf ant_dracula.tar &>/dev/null
	)
}

## processes user-choices from the beginning
function process_choices() {
	inform "Processing user-choices" "$LOG"

	if [[ $UDA =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $UDA ]]; then
		printf '\nEnabling ubuntu-drivers autoinstall... ' | "${WTL[@]}"
		test_on_success "$LOG" sudo ubuntu-drivers autoinstall
	fi

	if [[ $OJDK =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $OJDK ]]; then
		if [[ $(lsb_release -r) == *"18.04"* ]]; then
			printf '\nInstalling OpenJDK 11... ' | "${WTL[@]}"
			test_on_success "$LOG" "${AI[@]}" openjdk-11-jdk openjdk-11-doc openjdk-11-jre-headless openjdk-11-source
		else
			printf '\nInstalling OpenJDK 12... ' | "${WTL[@]}"
			test_on_success "$LOG" "${AI[@]}" openjdk-12-jdk openjdk-12-doc openjdk-12-jre-headless openjdk-12-source
		fi
	fi

	if [[ $CR =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $CR ]]; then
		printf '\nInstalling Cryptomator... ' | "${WTL[@]}"
		sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator &>>/dev/null
		
		local RSP=$?
		if [ $RSP -ne 0 ]; then
			err "Could not add Cryptomator PPA\n\t\t\t\t\tSkipping"
		else
			&>>/dev/null sudo apt update
			test_on_success "$LOG" "${AI[@]}" cryptomator
		fi
	fi

	if [[ $TEX =~ ^(yes|Yes|y|Y| ) ]] || [ -z "$TEX" ]; then
		printf '\nInstalling TeX... ' | "${WTL[@]}"
	    "${AI[@]}" python3-pygments &>/dev/null
		test_on_success "$LOG" "${AI[@]}" texlive-full
	fi

	if [[ $OC =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $OC ]]; then
		printf '\nInstalling ownCloud... ' | "${WTL[@]}"
		test_on_success "$LOG" "${AI[@]}" owncloud-client
	fi

	if [[ $BE =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $BE ]]; then
		printf '\nInstalling Build-Essential & CMake... ' | "${WTL[@]}"
		test_on_success "$LOG" "${AI[@]}" build-essential cmake
	fi

	if [[ $NVIM =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $NVIM ]]; then
		printf '\nInstalling NeoVIM... ' | "${WTL[@]}"
		test_on_success "$LOG" "${AI[@]}" neovim
	fi

	if [[ $VSC =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $VSC ]]; then
		printf '\nInstalling Visual Studio Code... ' | "${WTL[@]}"
		test_on_success "$LOG" "${SI[@]}" code --classic
	fi

	if [[ $VSCE =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $VSCE ]]; then
		printf '\nInstalling Visual Studio Code Extensions... ' | "${WTL[@]}"
		test_on_success "$LOG" "${DIR}/../sys/vscode/extensions.sh"
	fi

	if [[ $JBIDE =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $JBIDE ]]; then
		printf "\nInstalling JetBrains' IDE suite" | "${WTL[@]}"
		printf '\n  –> IntelliJ Ultimate... '
		test_on_success "$LOG" "${SI[@]}" intellij-idea-ultimate --classic
		
		printf '\n  –> PyCharm Professional... '
		test_on_success "$LOG" "${SI[@]}" pycharm-professional --classic

		printf '\n  –> CLion... '
		test_on_success "$LOG" "${SI[@]}" clion --classic
	fi

	if [[ $DOCK =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $DOCK ]]; then
		printf '\nInstalling Docker... ' | "${WTL[@]}"
		
		curl -fsSL https://get.docker.com -o get-docker.sh &>/dev/null
		sudo sh get-docker.sh &>/dev/null
		sudo usermod -aG docker "$(whoami)" &>/dev/null

		sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &>/dev/null
		sudo chmod +x /usr/local/bin/docker-compose &>/dev/null

		 sudo curl -L https://raw.githubusercontent.com/docker/compose/1.25.4/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose &>/dev/null
	fi

	if [[ $RUST =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $RUST ]]; then
		printf '\nInstalling RUST... ' | "${WTL[@]}"

		if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile complete -y &>/dev/null; then
			if [ -e "${HOME}/.cargo/env" ]; then
				# shellcheck source=/dev/null
				source "${HOME}/.cargo/env"

				mkdir -p "${HOME}/.local/share/bash-completion/completions"
				touch "${HOME}/.local/share/bash-completion/completions/rustup"
				rustup completions bash > "${HOME}/.local/share/bash-completion/completions/rustup"

				COMPONENTS=( rust-docs rust-analysis rust-src rustfmt rls clippy )
				for COMPONENT in "${COMPONENTS[@]}"; do
					&>>/dev/null rustup component add "$COMPONENT"
				done

				[ -n "$(which code)" ] && code --install-extension rust-lang.rust &>/dev/null
			fi
			printf "successful\n" | "${WTL[@]}"
		else
			printf "unsuccessful\n" | "${WTL[@]}"
		fi
	fi
	
	printf '\n\n' | "${WTL[@]}"
	succ 'Finished with processing user-choices' "$LOG"
}

function post() {
	if [[ -z $(which shutdown) ]]; then
		warn 'Altough recommended, could not find shutdown to restart'
		return 1
	fi

	read -p "It is recommended to restart. Would you like to schedule a restart? [Y/n]" -r RESTART
	if [[ $RESTART =~ ^(yes|Yes|y|Y| ) ]] || [[ -z $RESTART ]]; then
	    shutdown --reboot 1 &>/dev/null
		inform 'Rebooting in one minute'
	fi
}

# ! Main

function main() {
    if ! sudo printf ''; then
		echo ''
		err 'User input invalid. Aborting.' | "${WTL[@]}"
		exit 1
	fi

	prechecks
	init

	warn 'Desktop packaging has begun' | "${WTL[@]}"

	choices
	check_lightdm

	add_ppas

	inform 'Initial update' "$LOG"
	script_update "$LOG"
	
	packages
	icons_and_colors
	process_choices

	succ 'Finished packaging stage' "$LOG"
	post
}

main "$@" || exit 1

