# OLD SKOOL LS ALIASES
######################
# alias clf="ls -1rt | tail -1 | xargs bat" # view the last file
# alias l="ls -la "
# alias lf="ls -p | grep -v /" # list files only
# alias lgr='l | grep -i '     # ls grep
# alias lhx="ls ~"
# alias list-javas="l ~/.jenv/versions" # where the fuck is my javas?
# alias ll="ls -l "
# alias lla='ls -lat'
# alias llf="clf"
# alias lrt="ls -lrt "
# alias lsf="ls -p | grep -v /" # list files only
# alias lt="ls -1rt|head -1"    # list last file

# NEW SKOOL LS ALIASES
######################
# TODO alias lgr="eza $COMMON_EZA_PARAMS | grep -Ei 'Permissions Size|;'
COMMON_EZA_PARAMS=" --long --header --icons --git --all --no-quotes --group-directories-first "
alias eza-default="eza $COMMON_EZA_PARAMS"
alias l="eza-default"
alias ll="eza-default --time-style long-iso --git "
alias ls1="eza-default --oneline"
alias ls-tree="eza-default --tree"
alias tree-ls="ls-tree"
alias lst="ls-tree"
alias lrt="eza-default --sort newest"
alias lsd="eza-default --only-dirs"
alias lot="eza-default --sort oldest"

# PSK 07-09-2022 undoing eza as it's hanging for ages on attached volumes
# alias l="eza-default "
alias ls="eza"
alias lf="eza-default | grep -v /" # list files only
alias lgr='l | grep -i '           # ls grep
alias lhx="ls ~"
alias list-aliases=n-aliases                 # wot about my aliases?
alias list-functions=n-functions             # wot about my functions?
alias list-javas="l ~/.jenv/versions"        # where the fuck is my javas?
alias list-themes="cat ${HOME}/.zsh_favlist" # oh-my-zsh stuff
alias lock="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
alias lsf="eza-default --only-files" # list files only
