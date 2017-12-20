#!/bin/bash

#
# Minimalistic script to handle Go environments - Meant to be used along with
# glide (curl https://glide.sh/get | sh)
#
DN=$(realpath $(dirname $0))

# Load Config
if [ -f ~/.go2go.rc ]; then
    . ~/.go2go.rc
else
    echo ""
    echo "Edit ~/.go2go.rc if you want to customize, defaults are being used:"
    echo ""
    echo "  GO_INSTALL_PATH=~/.go2go/versions"
    echo "  GO_ENVIRON_PATH=~/go"
    echo ""
fi


# Set defaults if missing
: ${GO_INSTALL_PATH:=~/.go2go/versions}
: ${GO_ENVIRON_PATH:=~/go}


function help {
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "  Commands:"
    echo "      install <version>           Install a new version of Go"
    echo "      uninstall <version>         Uninstall a Go version"
    echo "      lsvers                      List installed go version"
    echo ""
    echo "      env <name> <version> [path] Define a new environment (path is optional, default ~/go)"
    echo "      rmenv <name>                Remove an environment (will not delete code... hopefully)"
    echo "      activate <name>             Activate a go environemnt"
    echo "      lsenvs                      List environments"
    echo ""
}

function lsvers_go {
    echo
    echo " * Available Go versions:"
    ls $GO_INSTALL_PATH | sort -V | sed 's|^|   - |g'
    echo
}

function uninstall_go {
    version=$1

    # https://stackoverflow.com/a/35894180/3727050
    rx='^([0-9]+\.){0,2}(\*|[0-9]+)$'
    if [[ ! $version =~ $rx ]]; then
        echo "Supplied thing is NOT a VERSION !!! ('$version')"
        exit 20
    fi

    echo " * Unistalling version '$version'"
    install_path="$GO_INSTALL_PATH/$1"

    if [ ! -d "$install_path" ]; then
        echo " ! Version $1 does not exist..."
        exit 21
    fi

    echo " * Removing $install_path"
    rm -rf "$install_path"
}

function install_go {
    version=$1
    echo " * Installing version $version"
    install_path="$GO_INSTALL_PATH/$1"

    if [ -d "$install_path" ]; then
        echo " ! Version $1 already exists... remove before reinstalling"
        exit 10
    fi

    # Shameless copy/paste from https://github.com/kaneshin/goenv/blob/master/libexec/goenv-install
    platform="$(uname -s | tr '[:upper:]' '[:lower:]')"

    if [ "$(uname -m)" = "x86_64" ]; then
      arch="amd64"
    else
      arch="386"
    fi

    if [ "$platform" = "darwin" ]; then
      # Since go version 1.2, osx packages were subdivided into 10.6 and 10.8
      case "$version" in
      1.2*|1.3*|1.4|1.4.[12] )
        if [ "$(uname -r)" \> "12" ]; then
          extra="-osx10.8"
        else
          extra="-osx10.6"
        fi
        ;;
      esac
    fi

    download=""
    if [[ ${version} =~ ^gae- ]]; then
      aeversion=${version/$BASH_REMATCH}
      download="https://storage.googleapis.com/appengine-sdks/featured/go_appengine_sdk_${platform}_${arch}${extra}-${aeversion}.zip"

    else
      download="https://storage.googleapis.com/golang/go${version}.${platform}-${arch}${extra}.tar.gz"
    fi

    code="$(curl --silent -LI -w '%{http_code}' -o /dev/null ${download})"
    if [ "404" = ${code} ]; then
      echo " ! Requested version (${version}) not found..."
      exit 11
    fi

    # Make the version dir
    mkdir -p "$install_path"

    archive="$(basename $download)"
    echo "  - Downloading ${archive}..."
    echo "     -> ${download}"

    # Download binary tarball and install
    # Linux downloads are formatted differently from OS X
    ext="${archive##*.}"
    (
      curl --silent -L -f "$download" > "/tmp/$archive"
      if [ "zip" = $ext ]; then
        unzip "/tmp/$archive" > /dev/null
        for file in go_appengine/*; do
          rm -fr "$(basename $file)" && mv "$file" "$install_path"
        done
        rm -rf go_appengine
      else
        tar zxf "/tmp/$archive" --strip-components 1 -C "$install_path"
      fi
      rm "/tmp/$archive"
    ) || {
      rm "/tmp/$archive" 2> /dev/null

      echo " ! go2go: Unable to install Go \`${version}' from binary, download not available at ${download}"
      exit 12
    }

    echo " * Installed ${version} to ${install_path}"
}

function _get_env_config {
    name=$1
    cat ~/.go2go.db 2> /dev/null | grep "^$name:"
}

function _env_cfg_get_name {
     echo -n "$1" | cut -d: -f1
}

function _env_cfg_get_go_version {
     echo -n "$1" | cut -d: -f2
}

function _env_cfg_get_go_home {
     echo -n "$1" | cut -d: -f3
}

function _env_cfg_get_go_path {
     echo -n "$1" | cut -d: -f4
}

function _print_env_config {
    name=$1
    cfg=$(_get_env_config "$name")
    echo "   -  name:       $name"
    echo "   -  version:    $(_env_cfg_get_go_version "$cfg") ($(_env_cfg_get_go_home "$cfg"))"
    echo "   -  path:       $(_env_cfg_get_go_path "$cfg")"
}

function env_go {
    if [ $# -lt 2 ]; then
        echo " ! You need to provide <name> and <version>"
        echo " !   - name can be anything (your reference)"
        echo " !   - version is Go version"
        exit 30
    fi

    name="$1"
    version="$2"
    path="$GO_ENVIRON_PATH"
    go_home="$GO_INSTALL_PATH/$version"

    if [ $# -gt 2 ]; then
        path="$3"
    fi

    # Check our config!
    if [ "$(_get_env_config "$name")" != "" ]; then
        echo " * Environment '$name' is already defined as: "
        _print_env_config "$name"
        exit 31
    fi

    echo " * Setting you up with a new environemnt:"
    echo "   -  name:       $name"
    echo "   -  version:    $version"
    echo "   -  path:       $path"
    echo

    # Check Go version exists and install if not...
    if [ ! -d "$go_home" ]; then
        echo " * Go version $version does not exist... installing..."
        install_go $version
    fi

    if [ ! -d "$path" ]; then
        mkdir -p "$path"
        if [ ! -d "$path" ]; then
            echo "Something went wrong... cannot create '$path'?? Permissions??"
            exit 32
        fi
    fi

    echo "$name:$version:$go_home:$path" >> ~/.go2go.db

    echo " * Activating new environment"
    . <($0 activate "$name" 2>/dev/null)

    echo " * Installing glide for you!"
    if [ "`which glide`" == "" ]; then
        echo "   - Installing glide"
        curl --silent https://glide.sh/get | sh > /dev/null 2>&1
    else
        echo "   - glide already installed!"
    fi

    echo " * Deactivating"
    go_away
    echo " * All done"
}

function rmenv_go {
    name="$1"
    if [ "$name" == "" ]; then
        echo " ! <name> is required..."
        exit 30
    fi
    cfg=$(_get_env_config "$name")

    if [ "$cfg" == "" ]; then
        echo " * Environment '$name' does not exist!?"
        exit 33
    fi

    echo
    echo " * Removing Environment:"
    _print_env_config "$name"


    sed -i "/^$name:/d" ~/.go2go.db
    echo
    echo " * Removed configuration. NOTE any srcs and pkgs should still exist in:"
    echo
    echo "     $(_env_cfg_get_go_path $cfg)"
    echo
    echo "To clean-up use:   rm -fr $(_env_cfg_get_go_path $cfg)"
    echo
}

function lsenvs_go {
    echo
    echo " * Available environmetns:"
    echo
    while read cfg
    do
        echo "  - Environement '$(_env_cfg_get_name $cfg)':"
        echo "    version:    $(_env_cfg_get_go_version "$cfg") ($(_env_cfg_get_go_home "$cfg"))"
        echo "    path:       $(_env_cfg_get_go_path "$cfg")"

        # Basic sanity check...
        if [ ! -d $(_env_cfg_get_go_home "$cfg") ]; then
            echo " !!! Invalid environment !!!"
            echo " Go path does not exist ($(_env_cfg_get_go_home "$cfg"))"
        fi
        echo
    done < ~/.go2go.db
}

function activate_go {

    name="$1"
    if [ "$name" == "" ]; then
        echo " ! <name> is required..." 1>&2
        exit 40
    fi

    cfg=$(_get_env_config "$name")

    if [ "$cfg" == "" ]; then
        echo " * Environment '$name' does not exist!? Use 'go2go lsenvs'" 1>&2
        exit 41
    fi

    # Basic sanity check...
    if [ ! -d $(_env_cfg_get_go_home "$cfg") ]; then
        echo " !!! Invalid environment !!!" 1>&2
        echo " Go path does not exist ($(_env_cfg_get_go_home "$cfg"))" 1>&2
        exit 42 # -- ha
    fi

    # Deactivate any running environments...
    type -t go_away > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo " ! Deactivating current environment ($GO2GO_ENV)" 1>&2
        go_away 1>&2
        # Remove the old prompt!
        echo "export PS1=\$(echo \"\$PS1\" | sed 's|[^)]*) ||g')"
    fi

    echo 1>&2
    echo " * Activating Go environment:" 1>&2
    _print_env_config "$name" 1>&2
    echo 1>&2

    cat <<EOE
export GOHOME=$(_env_cfg_get_go_home "$cfg")
# This fixes godoc...
export GOROOT=$(_env_cfg_get_go_home "$cfg")
export GOPATH=$(_env_cfg_get_go_path "$cfg")
export GOBIN=\$GOHOME/bin
export PATH=\$GOPATH/bin:\$GOHOME/bin:$PATH
export PS1="(go: $name) \$PS1"
export GO2GO_ENV=$name

function go_away {
    export PATH=\$(echo "\$PATH" | sed "s|\$GOPATH/bin:\$GOHOME/bin:||g")
    unset GOHOME GOPATH GOBIN GOROOT GO2GO_ENV
    export PS1=\$(echo "\$PS1" | sed 's|[^)]*) ||g')
    unset go_away
}

export -f go_away
EOE

}

#
# Do the job...
#
if [ $# -lt 1 ]; then
    help
    exit 1
fi

# Parse command
CMD="$1"
version=""
path=""
case $CMD in
    install|uninstall|env|activate|lsenvs|lsvers|rmenv)
        shift
        ;;
    -h)
        help
        exit 0
        ;;
    *)
        echo "Unknown Command '$CMD'"
        exit 2
esac

# Invoke the command as function...
${CMD}_go $@
