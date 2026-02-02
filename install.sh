#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ $(id -u) != 0 ] ; then
  echo "Les droits Superuser (root) sont nécessaires pour installer select-freeboxos"
  echo "Lancez 'sudo $0' pour obtenir les droits Superuser."
  exit 1
fi

is_valid_python3_version() {
    [[ $1 =~ ^python3\.[0-9]+$ ]]
}
PYTHON_VERSIONS=($(compgen -c python3. | sort -Vr))
PYTHON_COMMAND=""
for version in "${PYTHON_VERSIONS[@]}"
do
    if is_valid_python3_version "$version" && command -v $version &> /dev/null
    then
        ver_number=${version#python3.}
        if (( ver_number >= 9 ))
        then
            PYTHON_COMMAND=$version
            break
        fi
    fi
done
if [[ -z $PYTHON_COMMAND ]]
then
    echo "Une version 3.9 minimum de Python est nécessaire."
    echo "Merci d'installer une version de Python supérieur ou égale à 3.9 puis de relancer le programme"
    exit 1
else
    echo "Utilisation de $PYTHON_COMMAND (version $($PYTHON_COMMAND --version 2>&1 | cut -d' ' -f2))"
fi

echo -e "Installation des librairies nécessaires\n"

step_1_update() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 1 - Update"
  apt update
  echo "Step 1 - Update done"
}

step_2_mainpackage() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 2 - packages"
  apt -y install curl
  apt -y install wget
  apt -y install unzip
  apt -y install firefox
  apt -y install cron
  apt -y install anacron
  apt -y install jq
  hostname=$(uname -n)
  codename=$(grep 'VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2)
  echo "step 2 - packages done"
}

step_3_freeboxos_download() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 3 - select-freeboxos download"

  user=${SUDO_USER:-$USER}
  HOME_DIR=$(getent passwd "$user" | cut -d: -f6)
  if [ -z "$HOME_DIR" ]; then
    echo "ERROR: unable to determine home directory for user '$user'" >&2
    exit 1
  fi

  cd "$HOME_DIR" && curl https://github.com/mediaselect/select-freeboxos/archive/refs/tags/v2.0.0.zip -L -o select_freebox.zip
  selectos=$(ls "$HOME_DIR" | grep select-freeboxos)
  if [ -n "$selectos" ]
  then
    rm -rf /home/$user/select-freeboxos
  fi
  unzip select_freebox.zip && mv select-freeboxos-2.0.0 select-freeboxos && rm select_freebox.zip
  chown -R "$SUDO_USER:$SUDO_USER" "$HOME_DIR/select-freeboxos"
  echo "Step 3 - select-freeboxos download done"
}

step_4_create_select_freeboxos_directories() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 4 - Creating .local/share/select_freeboxos"
  user=${SUDO_USER:-${USER}}
  echo "User: $user"
  if [ ! -d /home/$user/.local ]; then
    sudo -u $user mkdir /home/$user/.local
    sudo -u $user chmod 700 /home/$user/.local
  fi
  if [ ! -d /home/$user/.local/share ]; then
    sudo -u $user mkdir /home/$user/.local/share
    sudo -u $user chmod 700 /home/$user/.local/share
  fi
  if [ ! -d /home/$user/.config ]; then
    sudo -u $user mkdir /home/$user/.config
    sudo -u $user chmod 700 /home/$user/.config
  fi
  sudo -u $user mkdir -p /home/$user/.local/share/select_freeboxos/logs
  sudo -u $user chmod -R 740 /home/$user/.local/share/select_freeboxos
  sudo -u $user mkdir -p /home/$user/.config/select_freeboxos
  sudo -u $user chmod -R 740 /home/$user/.config/select_freeboxos
  echo "Step 4 - select_freeboxos directories created"
}

step_5_install_gpg_key() {
  echo "---------------------------------------------------------------------"
  echo "Step 5 - Installing GPG public key"

  user=${SUDO_USER:-$USER}
  HOME_DIR=$(getent passwd "$user" | cut -d: -f6)
  if [ -z "$HOME_DIR" ]; then
    echo "ERROR: unable to determine home directory for user '$user'" >&2
    exit 1
  fi

  SRC_KEY="$HOME_DIR/select-freeboxos/.gpg/public.key"
  DEST_DIR="$HOME_DIR/.config/select_freeboxos"
  DEST_KEY="$DEST_DIR/public.key"

  if [ ! -f "$SRC_KEY" ]; then
    echo "ERROR: GPG public key not found at $SRC_KEY"
    exit 1
  fi

  sudo -u "$user" mkdir -p "$DEST_DIR"
  sudo -u "$user" cp "$SRC_KEY" "$DEST_KEY"
  sudo -u "$user" chmod 640 "$DEST_KEY"

  echo "Step 5 - GPG public key installed"
}

amd64=("x86_64" "x86" "amd64")

info_not_amd64=false

step_6_geckodriver_download() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 6 - geckodriver download"
  cd /home/$user/.local/share/select_freeboxos
  cpu=$(lscpu | grep Architecture | awk {'print $2'})
  cpu_lower=$(echo "$cpu" | tr '[:upper:]' '[:lower:]')
  cpu_five_chars="${cpu_lower:0:5}"

  if echo "${amd64[@],,}" | grep -q "$cpu_five_chars"
  then
    wget https://github.com/mozilla/geckodriver/releases/download/v0.35.0/geckodriver-v0.35.0-linux64.tar.gz
    GECKODRIVER_SHA256="ac26e9ba8f3b8ce0fbf7339b9c9020192f6dcfcbf04a2bcd2af80dfe6bb24260"
    if ! echo "$GECKODRIVER_SHA256  geckodriver-v0.35.0-linux64.tar.gz" | sha256sum -c -; then
        echo "ERROR: Checksum verification failed for geckodriver!"
        exit 1
    fi
    sudo -u $user bash -c "tar xzvf geckodriver-v0.35.0-linux64.tar.gz"
    rm geckodriver-v0.35.0-linux64.tar.gz
  else
    info_not_amd64=true
  echo "Step 6 - geckodriver download done"
  fi
}

step_7_virtual_environment() {
  echo "---------------------------------------------------------------------"
  echo "Starting step 7 - Virtual env + requirements install"
  curl -f --location -o virtualenv.pyz https://bootstrap.pypa.io/virtualenv.pyz
  VENV_SHA256="8c34d62f8dff28c87a9640257831d1c7ba81dd60c1cf0acbe57b3d4baa627b87"
  if ! echo "$VENV_SHA256  virtualenv.pyz" | sha256sum -c -; then
      echo "ERROR: Checksum verification failed for virtualenv!"
      exit 1
  fi
  sudo -u $user bash -c "$PYTHON_COMMAND virtualenv.pyz .venv"
  sudo -u $user bash -c "source .venv/bin/activate && pip install -r /home/$user/select-freeboxos/requirements.txt"
  echo "Step 7 - Virtual env created and requirements installed"
}


STEP=0

case ${STEP} in
  0)
  echo "Starting installation ..."
  step_1_update
  step_2_mainpackage
  step_3_freeboxos_download
  step_4_create_select_freeboxos_directories
  step_5_install_gpg_key
  step_6_geckodriver_download
  step_7_virtual_environment
  ;;
esac

if $info_not_amd64
then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "Geckodriver n'a pas pu être téléchargé car votre architecture \
CPU est différente de amd64. Le programme ne peut pas \
fonctionner sans Geckodriver. Le programme pourra néanmoins fonctionner si \
firefox est installé à partir de snap car Geckodriver est déjà présent. \
Dans le cas contraire, contactez Media-select pour obtenir le geckodriver \
qui correspond à votre architecture CPU."
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi
