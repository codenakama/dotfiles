#!/usr/bin/env bash
#
# bootstrap installs things.

# heavily inspired (copy pasted) https://github.com/holman/dotfiles/blob/master/script/bootstrap

cd "$(dirname "$0")"
DOTFILES_ROOT="$(pwd -P)/.."

set -e

echo ''

pause(){
  read -n1 -rsp $'Press any key to continue or Ctrl+C to exit...\n'
}

info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user () {
  printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail () {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

print_result () {
  [ $1 -eq 0 ] \
      && sucess "$2" \
          || fail "$2"

  [ "$3" == "true" ] && [ $1 -ne 0 ] \
      && exit
}

git_clone() {
    REPOSRC=$1
    LOCALREPO=$2

    # We do it this way so that we can abstract if from just git later on
    LOCALREPO_VC_DIR=$LOCALREPO/.git

    if [ ! -d $LOCALREPO_VC_DIR ]
    then
        git clone --recursive $REPOSRC $LOCALREPO
    else
        cd $LOCALREPO
        git pull $REPOSRC
    fi
}

link_file () {
  local src=$1 dst=$2

  local overwrite= backup= skip=
  local action=

  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]
  then

    if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ]
    then

      local currentSrc="$(readlink $dst)"


      if [ "$currentSrc" == "$src" ]
      then

        skip=true;

      else

        user "File already exists: $dst ($(basename "$src")), what do you want to do?\n\
        [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?"
        read -n 1 action

        case "$action" in
          o )
            overwrite=true;;
          O )
            overwrite_all=true;;
          b )
            backup=true;;
          B )
            backup_all=true;;
          s )
            skip=true;;
          S )
            skip_all=true;;
          * )
            ;;
        esac

      fi

    else

      skip=true;

    fi

    overwrite=${overwrite:-$overwrite_all}
    backup=${backup:-$backup_all}
    skip=${skip:-$skip_all}

    if [ "$overwrite" == "true" ]
    then
      rm -rf "$dst"
      success "removed $dst"
    fi

    if [ "$backup" == "true" ]
    then
      mv "$dst" "${dst}.backup"
      success "moved $dst to ${dst}.backup"
    fi

    if [ "$skip" == "true" ]
    then
      success "skipped $src"
    fi
  fi

  if [ "$skip" != "true" ]  # "false" or empty
  then
    ln -s "$1" "$2"
    success "linked $1 to $2"
  fi
}

setup_xcode () {
  if ! xcode-select --print-path &> /dev/null; then
    # Prompt user to install the XCode Command Line Tools
    xcode-select --install &> /dev/null

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Wait until the XCode Command Line Tools are installed
    until xcode-select --print-path &> /dev/null; do
        sleep 5
    done

    print_result $? 'Install XCode Command Line Tools'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Point the `xcode-select` developer directory to
    # the appropriate directory from within `Xcode.app`
    # https://github.com/alrra/dotfiles/issues/13

    sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
    print_result $? 'Make "xcode-select" developer directory point to Xcode'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Prompt user to agree to the terms of the Xcode license
    # https://github.com/alrra/dotfiles/issues/10

    sudo xcodebuild -license
    print_result $? 'Agree with the XCode Command Line Tools licence'
  fi
}

setup_gitconfig () {
  if ! [ -f gitconfig.symlink ]
  then
    info 'setup gitconfig'

    credential='cache'
    if [ "$(uname -s)" == "Darwin" ]
    then
      credential='osxkeychain'
    fi

    user ' - What is your git author name?'
    read -e authorname
    user ' - What is your git author email?'
    read -e authoremail
    user ' - What is your git editor?'
    read -e editor

    sed -e "s/AUTHORNAME/$authorname/g" -e "s/AUTHOREMAIL/$authoremail/g" -e "s/CREDENTIAL_HELPER/$credential/g" -e "s/EDITOR/$editor/g" gitconfig.symlink.example > gitconfig.symlink

    info 'allow to use ssh with github'
    ssh-keygen -t rsa -b 4096 -C $authoremail
    ssh-add ~/.ssh/id_rsa
    pbcopy < ~/.ssh/id_rsa.pub

    info 'public key is in clipboard, add ssh key to github'
    open https://github.com/settings/ssh
    pause

    info 'generate token if you prefer to use https'

    open https://github.com/settings/tokens
    info 'please check https://help.github.com/articles/creating-an-access-token-for-command-line-use/'
    info "and this https://help.github.com/articles/caching-your-github-password-in-git/ if you don't know or remember what to do with the token"
    pause

    success 'gitconfig'
  fi
}

install_dotfiles () {
  info 'installing dotfiles'

  local overwrite_all=false backup_all=false skip_all=false

  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.symlink')
  do
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

setup_spaceemacs () {
  info 'setting up spacemacs...'

  tic -o ~/.terminfo emacs/eterm-color.ti # fix emacs color terminal with zsh
  git_clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

setup_vim () {
  info 'setting up vim...'

  git_clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

  if ! [ -f ~/.vim/colors/hybrid.vim ]
  then
    curl -OL https://raw.githubusercontent.com/w0ng/vim-hybrid/master/colors/hybrid.vim
    mkdir -p ~/.vim/colors/; mv hybrid.vim ~/.vim/colors/
  fi

  mkdir -p ${XDG_CONFIG_HOME:=$HOME/.config}

  link_file ~/.vim "$XDG_CONFIG_HOME/nvim"
  link_file ~/.vimrc "$XDG_CONFIG_HOME/nvim/init.vim"
}

install_apps () {
  info 'installing apps...'
  #
  # Homebrew
  #
  # This installs some of the common dependencies needed (or at least desired)
  # using Homebrew.

  # Check for Homebrew
  if test ! $(which brew)
  then
    echo "  Installing Homebrew for you."

    # Install the correct homebrew for each OS type
    if test "$(uname)" = "Darwin"
    then
      ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
    then
      ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/linuxbrew/go/install)"
    fi
  else
    #statements
    # Make sure we’re using the latest Homebrew
    brew update

    # Upgrade any already-installed formulae
    brew upgrade
  fi

  # Install native apps
  brew install caskroom/cask/brew-cask
  brew tap caskroom/versions

  # daily
  brew cask install amethyst
  brew cask install alfred
  brew cask install dropbox
  brew cask install skype

  # dev
  brew cask install iterm2-nightly
  # brew cask install iterm2
  brew cask install virtualbox
  brew cask install imagealpha
  brew cask install imageoptim
  brew cask install sourcetree
  brew cask install hipchat
  brew cask install robomongo


  # browsers
  brew cask install google-chrome
  brew cask install google-chrome-canary
  brew cask install firefoxdeveloperedition
  brew cask install firefox
  brew cask install torbrowser

  # fun
  brew cask install vlc
  brew cask install spotify
  brew cask install kindle
  brew cask install steam
  brew tap caskroom/fonts
  brew cask install font-hack

  # Install homebrew packages

  # GNU core utilities (those that come with OS X are outdated)
  # Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
  brew install coreutils
  # brew install moreutils
  # GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
  brew install findutils
  # GNU `sed`, overwriting the built-in `sed`
  brew install gnu-sed --with-default-names

  # utils
  # Install wget with IRI support
  brew install wget --enable-iri
  brew install jq
  brew install zsh

  brew install tree
  brew install todo-txt
  brew install fpp;

  # install tmux
  # temporary until tmux mac with true color
  brew install https://raw.githubusercontent.com/choppsv1/homebrew-term24/master/tmux.rb
  # brew install tmux
  git_clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm # install tmux plugin

  # install improve search
  brew install the_platinum_searcher
  brew install the_silver_searcher

  # install nice to have
  brew install python
  brew install python3
  brew install lua

  # install nodejs
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.0/install.sh | bash
  export NVM_DIR=~/.nvm
  nvm install node

  # Install clojure
  brew cask install java
  brew install leiningen
  # curl -L http://smartcd.org/install | bash

  # editors
  brew cask install sublime-text

  # emacs
  brew tap railwaycat/emacsmacport
  brew cask install emacs-mac
  brew install emacs
  brew linkapps emacs

  # vim
  brew tap neovim/neovim
  brew install --HEAD neovim
  brew install vim

  setup_karabiner

  # Remove outdated versions from the cellar
  brew cleanup

}

setup_zsh () {
  # install prezto

  info 'setup zprezto'
  git_clone https://github.com/Fetz/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"

  for src in $(find "${ZDOTDIR:-$HOME}/.zprezto/runcoms" -type f ! -name '*.md')
  do
      file=$(basename $src)
      link_file "$src" "${ZDOTDIR:-$HOME}/.${file:t}"
  done

  echo 'change default shell to zsh'
  chsh -s /bin/zsh
}

setup_karabiner () {
  info 'setup karabiner'

  # karabiner
  brew cask install karabiner
  brew cask install seil

  local overwrite_all=true backup_all=false skip_all=false
  link_file karabiner/private.xml /Applications/Karabiner.app/Contents/Resources/private.xml

  info 'change key 80 in seils'
  open 'https://pqrs.org/osx/karabiner/faq.html.en#exchange-caps-lock-and-delete'
}

setup_xcode
setup_gitconfig
install_apps
install_dotfiles
setup_spaceemacs
setup_vim
setup_zsh
