function zsh_stats() {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}

function uninstall_oh_my_zsh() {
  command env ZSH="$ZSH" sh "$ZSH/tools/uninstall.sh"
}

function upgrade_oh_my_zsh() {
  echo >&2 "${fg[yellow]}Note: \`$0\` is deprecated. Use \`omz update\` instead.$reset_color"
  omz update
}

function take() {
  mkdir -p $@ && cd ${@:$#}
}

function open_command() {
  local open_cmd

  # define the open command
  case "$OSTYPE" in
    darwin*)  open_cmd='open' ;;
    cygwin*)  open_cmd='cygstart' ;;
    linux*)   [[ "$(uname -r)" != *icrosoft* ]] && open_cmd='nohup xdg-open' || {
                open_cmd='cmd.exe /c start ""'
                [[ -e "$1" ]] && { 1="$(wslpath -w "${1:a}")" || return 1 }
              } ;;
    msys*)    open_cmd='start ""' ;;
    *)        echo "Platform $OSTYPE not supported"
              return 1
              ;;
  esac

  # If a URL is passed, $BROWSER might be set to a local browser within SSH.
  # See https://github.com/ohmyzsh/ohmyzsh/issues/11098
  if [[ -n "$BROWSER" && "$1" = (http|https)://* ]]; then
    "$BROWSER" "$@"
    return
  fi

  ${=open_cmd} "$@" &>/dev/null
}

# take functions

# mkcd is equivalent to takedir
function mkcd takedir() {
  mkdir -p $@ && cd ${@:$#}
}

function takeurl() {
  local data thedir
  data="$(mktemp)"
  curl -L "$1" > "$data"
  tar xf "$data"
  thedir="$(tar tf "$data" | head -n 1)"
  rm "$data"
  cd "$thedir"
}

function takezip() {
  local data thedir
  data="$(mktemp)"
  curl -L "$1" > "$data"
  unzip "$data" -d "./"
  thedir="$(unzip -l "$data" | awk 'NR==4 {print $4}' | sed 's/\/.*//')"
  rm "$data"
  cd "$thedir"
}

function takegit() {
  git clone "$1"
  cd "$(basename ${1%%.git})"
}

function take() {
  if [[ $1 =~ ^(https?|ftp).*\.(tar\.(gz|bz2|xz)|tgz)$ ]]; then
    takeurl "$1"
  elif [[ $1 =~ ^(https?|ftp).*\.(zip)$ ]]; then
    takezip "$1"
  elif [[ $1 =~ ^([A-Za-z0-9]\+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]; then
    takegit "$1"
  else
    takedir "$@"
  fi
}

#
# Get the value of an alias.
#
# Arguments:
#    1. alias - The alias to get its value from
# STDOUT:
#    The value of alias $1 (if it has one).
# Return value:
#    0 if the alias was found,
#    1 if it does not exist
#
function alias_value() {
    (( $+aliases[$1] )) && echo $aliases[$1]
}

#
# Try to get the value of an alias,
# otherwise return the input.
#
# Arguments:
#    1. alias - The alias to get its value from
# STDOUT:
#    The value of alias $1, or $1 if there is no alias $1.
# Return value:
#    Always 0
#
function try_alias_value() {
    alias_value "$1" || echo "$1"
}

#
# Set variable "$1" to default value "$2" if "$1" is not yet defined.
#
# Arguments:
#    1. name - The variable to set
#    2. val  - The default value
# Return value:
#    0 if the variable exists, 3 if it was set
#
function default() {
    (( $+parameters[$1] )) && return 0
    typeset -g "$1"="$2"   && return 3
}

#
# Set environment variable "$1" to default value "$2" if "$1" is not yet defined.
#
# Arguments:
#    1. name - The env variable to set
#    2. val  - The default value
# Return value:
#    0 if the env variable exists, 3 if it was set
#
function env_default() {
    [[ ${parameters[$1]} = *-export* ]] && return 0
    export "$1=$2" && return 3
}


# Required for $langinfo
zmodload zsh/langinfo

# URL-encode a string
#
# Encodes a string using RFC 2396 URL-encoding (%-escaped).
# See: https://www.ietf.org/rfc/rfc2396.txt
#
# By default, reserved characters and unreserved "mark" characters are
# not escaped by this function. This allows the common usage of passing
# an entire URL in, and encoding just special characters in it, with
# the expectation that reserved and mark characters are used appropriately.
# The -r and -m options turn on escaping of the reserved and mark characters,
# respectively, which allows arbitrary strings to be fully escaped for
# embedding inside URLs, where reserved characters might be misinterpreted.
#
# Prints the encoded string on stdout.
# Returns nonzero if encoding failed.
#
# Usage:
#  omz_urlencode [-r] [-m] [-P] <string> [<string> ...]
#
#    -r causes reserved characters (;/?:@&=+$,) to be escaped
#
#    -m causes "mark" characters (_.!~*''()-) to be escaped
#
#    -P causes spaces to be encoded as '%20' instead of '+'
function omz_urlencode() {
  emulate -L zsh
  setopt norematchpcre

  local -a opts
  zparseopts -D -E -a opts r m P

  local in_str="$@"
  local url_str=""
  local spaces_as_plus
  if [[ -z $opts[(r)-P] ]]; then spaces_as_plus=1; fi
  local str="$in_str"

  # URLs must use UTF-8 encoding; convert str to UTF-8 if required
  local encoding=$langinfo[CODESET]
  local safe_encodings
  safe_encodings=(UTF-8 utf8 US-ASCII)
  if [[ -z ${safe_encodings[(r)$encoding]} ]]; then
    str=$(echo -E "$str" | iconv -f $encoding -t UTF-8)
    if [[ $? != 0 ]]; then
      echo "Error converting string from $encoding to UTF-8" >&2
      return 1
    fi
  fi

  # Use LC_CTYPE=C to process text byte-by-byte
  # Note that this doesn't work in Termux, as it only has UTF-8 locale.
  # Characters will be processed as UTF-8, which is fine for URLs.
  local i byte ord LC_ALL=C
  export LC_ALL
  local reserved=';/?:@&=+$,'
  local mark='_.!~*''()-'
  local dont_escape="[A-Za-z0-9"
  if [[ -z $opts[(r)-r] ]]; then
    dont_escape+=$reserved
  fi
  # $mark must be last because of the "-"
  if [[ -z $opts[(r)-m] ]]; then
    dont_escape+=$mark
  fi
  dont_escape+="]"

  # Implemented to use a single printf call and avoid subshells in the loop,
  # for performance (primarily on Windows).
  local url_str=""
  for (( i = 1; i <= ${#str}; ++i )); do
    byte="$str[i]"
    if [[ "$byte" =~ "$dont_escape" ]]; then
      url_str+="$byte"
    else
      if [[ "$byte" == " " && -n $spaces_as_plus ]]; then
        url_str+="+"
      elif [[ "$PREFIX" = *com.termux* ]]; then
        # Termux does not have non-UTF8 locales, so just send the UTF-8 character directly
        url_str+="$byte"
      else
        ord=$(( [##16] #byte ))
        url_str+="%$ord"
      fi
    fi
  done
  echo -E "$url_str"
}

# URL-decode a string
#
# Decodes a RFC 2396 URL-encoded (%-escaped) string.
# This decodes the '+' and '%' escapes in the input string, and leaves
# other characters unchanged. Does not enforce that the input is a
# valid URL-encoded string. This is a convenience to allow callers to
# pass in a full URL or similar strings and decode them for human
# presentation.
#
# Outputs the encoded string on stdout.
# Returns nonzero if encoding failed.
#
# Usage:
#   omz_urldecode <urlstring>  - prints decoded string followed by a newline
function omz_urldecode {
  emulate -L zsh
  local encoded_url=$1

  # Work bytewise, since URLs escape UTF-8 octets
  local caller_encoding=$langinfo[CODESET]
  local LC_ALL=C
  export LC_ALL

  # Change + back to ' '
  local tmp=${encoded_url:gs/+/ /}
  # Protect other escapes to pass through the printf unchanged
  tmp=${tmp:gs/\\/\\\\/}
  # Handle %-escapes by turning them into `\xXX` printf escapes
  tmp=${tmp:gs/%/\\x/}
  local decoded="$(printf -- "$tmp")"

  # Now we have a UTF-8 encoded string in the variable. We need to re-encode
  # it if caller is in a non-UTF-8 locale.
  local -a safe_encodings
  safe_encodings=(UTF-8 utf8 US-ASCII)
  if [[ -z ${safe_encodings[(r)$caller_encoding]} ]]; then
    decoded=$(echo -E "$decoded" | iconv -f UTF-8 -t $caller_encoding)
    if [[ $? != 0 ]]; then
      echo "Error converting string from UTF-8 to $caller_encoding" >&2
      return 1
    fi
  fi

  echo -E "$decoded"
}

##################################
# PSK Functions
##################################
# PSK List directories only
lsd() {
    l | grep -E "^d"
}

# ls grep
lsg() {
    l | grep -iE "$1"
}

# the ol' gfind. Doesn't take a file pattern.
function gfind-all() {
    # fd -H -t f . -x grep --color=always -Hi ${1}
    # Gah. Bye-bye gfind, here's an off-the-shelf improvement upon it https://github.com/burntsushi/ripgrep
    # $1 is search term, $2 is path
    # rg --no-ignore --hidden "$@"
    # even better is ag / silver searcher https://github.com/ggreer/the_silver_searcher
    ag -a --pager less "$@"
}

# the ol' gfind. Doesn't take a file pattern.
function gfind() {
    # fd -t f . -x grep --color=always -Hi ${1}
    ag --pager less "$@"
}

# Print out the matches only
function gfindf() {
  # TODO make this a lot less shit e.g. don't search .git . Surely rg has
  # the ability to do this.
  find . -type f -exec grep --color=always -Hil $1 {} \;
}

function heroic-repo-configure() {
  cp ${HOME}/src/spotify/prism-tools/heroic-test.yml ./heroic-guc.yml
  cp ${HOME}/src/spotify/prism-tools/heroic-api-gae.yml ./heroic-gae.yml
  ls -l | grep -E 'heroic.*yml|heroic.*yaml'
  mkdir logs
}

function kube-list-local-contexts() {
  grep '^- name: ' ~/.kube/config | awk '{print $3}'
}

function kube-list-prod-contexts() {
  gcloud container clusters list --project=gke-xpn-1 --filter="resourceLabels[env]=production" --format="value(name)"
}

# function h() {
#   NUM_LINES = ${1:-1000}
#   history | tail -n $NUM_LINES
# }

# function h() {
#   set -x
#   NUM_LINES = ${1:-25}
#   \history -${NUM_LINES}
# }

function agl() {
  ag --pager less "$@"
}

function kill-em-all() {
  NAME=$1

  echo "Attempting to kill $NAME by arg match..."
  pkill -fli $1
  echo "Attempting to kill $NAME by binary match..."
  pkill -li $1
  echo "...the killing... is done"
}

function dateline() {
  echo "––––––––––––"
  date
  echo "––––––––––––"
}

function clean-slate() {
  clear
  dateline
}

alias clr=clean-slate
alias cls=clean-slate

function psgr() {
  ps auwwwwx | grep -v 'grep ' | grep -E "%CPU|$1"
}

function edit() {
  /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code $1
}

function zshrc() {
  pushd ~/.oh-my-zsh
  edit .
  popd
}


function what-is-my-ip() {
  echo "Local IP: " $(ifconfig en0 | awk -v OFS="\n" '{ print $1 " " $2, $NF }' | grep "inet 192")
  echo "iNet IP : " $(dig @resolver4.opendns.com myip.opendns.com +short)
  echo "Hostname: " `hostname`
}

function dir-sizes() {
  du -sh ./* | sort -h
}

# to avoid slow shells, we do it manually
function kubectl() {
    if ! type __start_kubectl >/dev/null 2>&1; then
        source <(command kubectl completion zsh)
    fi

    command kubectl "$@"
}

function ssh-ds718() {
  ssh -p 658 pskadmin@192.168.2.7
}

alias git-stash-list-all='gitk `git stash list --pretty=format:%gd`'

function master-show-protection() {
  git branch -vv | grep "origin/`git branch --show-current`"
}

function git-show-branch() {
  git branch -vv | grep `git branch --show-current`
}

# kill most recent container instance
alias docker-kill-latest='docker ps -l --format='{{.Names}}' | xargs docker kill'

# stop all containers
docker-stop-all () {
        docker container stop -t 2 $(docker container ls -q) 2>/dev/null
}

function find-gig-files() {
  find . -size +1G -ls | sort -k7n # Find files larger than 1GB and then order the list by the file size
}

function start-cloud-sync() {
  echo "Starting cloud sync..."
  ${HOME}/bin/run-rclone-bisync-dropbox-gdrive.sh &
}

function tree() {
  /usr/local/homebrew/bin/tree -a $1 | colorize_less "$@"
}

# function open-all-edge-apps() {
#   EDGE_APP_DIR='/Users/peter/Dropbox (Personal)/_Settings/Edge Apps.localized/'
#   for APP in ${EDGE_APP_DIR}/*.app; do
#     echo "Opening $APP ..."
#     nohup open -a "$APP" &
#   done
# }

function _open-all-chrome-apps() {
  for APP in "${1}"/*.app; do
    echo "Opening $APP ..."
    nohup open -a "$APP" &
  done
}

function open-all-chrome-apps() {
  /Users/peter/.oh-my-zsh/bin/launch-browser-apps.sh & 2>&1 > /dev/null
}

alias start-all-edge-apps="open-all-edge-apps"

function kill-cloud-storage() {
  ─╯
  # TODO investigate pkill as alternative

  # Don't do this cos it downloads my backed up photos
  # killall "Google Drive File Stream" 2>/dev/null &
  killall -q Dropbox
  killall -q "Google Drive"
  killall -q "FinderSyncExtension" -SIGKILL
}

function mdfind() {
    /usr/bin/mdfind $@ 2> >(grep --invert-match ' \[UserQueryParser\] ' >&2)
}

function mdfind-current-dir() { # find file in .
  mdfind -onlyin . -name $1
}

function mdfind-home-dir() { # mdfind file in $HOME
  mdfind -onlyin $HOME -name $1
}

function mdfind-grep-current-dir() { # mdfind grep in current dir
  mdfind -onlyin . $1
}

function mdfind-grep-home-dir() { # mdfind grep in $HOME
  mdfind -onlyin $HOME $1
}


function google-search() {
  s $1 -p google
}

function amazon-search() {
  s $1 -p amazon
}

function youtube-search() {
  s $1 -p youtube
}

function explain-command {
    command="https://explainshell.com/explain?cmd=${1}"
osascript <<EOD
tell application "Safari" to make new document with properties {URL:"$command"}
return
EOD

  for x in *.${1}; do
    d=$(date -r "$x" +%Y-%m-%d)
    mkdir -p "$d"
    mv -- "$x" "$d/"
  done
}

### peco functions ###
function peco-directories() {
  local current_lbuffer="$LBUFFER"
  local current_rbuffer="$RBUFFER"
  if command -v fd >/dev/null 2>&1; then
    local dir="$(command \fd --type directory --hidden --no-ignore --exclude .git/ --color never 2>/dev/null | peco )"
  else
    local dir="$(
      command find \( -path '*/\.*' -o -fstype dev -o -fstype proc \) -type d -print 2>/dev/null \
      | sed 1d \
      | cut -b3- \
      | awk '{a[length($0)" "NR]=$0}END{PROCINFO["sorted_in"]="@ind_num_asc"; for(i in a) print a[i]}' - \
      | peco
    )"
  fi

  if [ -n "$dir" ]; then
    dir=$(echo "$dir" | tr -d '\n')
    dir=$(printf %q "$dir")
    # echo "PSK ${dir}"

    BUFFER="${current_lbuffer}${file}${current_rbuffer}"
    CURSOR=$#BUFFER
  fi
}

function peco-files() {
  local current_lbuffer="$LBUFFER"
  local current_rbuffer="$RBUFFER"
  if command -v fd >/dev/null 2>&1; then
    local file="$(command \fd --type file --hidden --no-ignore --exclude .git/ --color never 2>/dev/null | peco)"
  elif command -v rg >/dev/null 2>&1; then
    local file="$(rg --glob "" --files --hidden --no-ignore-vcs --iglob !.git/ --color never 2>/dev/null | peco)"
  elif command -v ag >/dev/null 2>&1; then
    local file="$(ag --files-with-matches --unrestricted --skip-vcs-ignores --ignore .git/ --nocolor -g "" 2>/dev/null | peco)"
  else
    local file="$(
    command find \( -path '*/\.*' -o -fstype dev -o -fstype proc \) -type f -print 2> /dev/null \
      | sed 1d \
      | cut -b3- \
      | awk '{a[length($0)" "NR]=$0}END{PROCINFO["sorted_in"]="@ind_num_asc"; for(i in a) print a[i]}' - \
      | peco
    )"
  fi

  if [ -n "$file" ]; then
    file=$(echo "$file" | tr -d '\n')
    file=$(printf %q "$file")
    BUFFER="${current_lbuffer}${file}${current_rbuffer}"
    CURSOR=$#BUFFER
  fi
}

zle -N peco-directories
bindkey '^Xf' peco-directories
zle -N peco-files
bindkey '^X^f' peco-files

###########################
# Percol https://github.com/mooz/percol
###########################
function ppgrep() {
    if [[ $1 == "" ]]; then
        PERCOL=percol
    else
        PERCOL="percol --query $1"
    fi
    ps aux | eval $PERCOL | awk '{ print $2 }'
}

function ppkill() {
    if [[ $1 =~ "^-" ]]; then
        QUERY=""            # options only
    else
        QUERY=$1            # with a query
        [[ $# > 0 ]] && shift
    fi
    ppgrep $QUERY | xargs kill $*
}

function smileys() {
  printf "$(awk 'BEGIN{c=127;while(c++<191){printf("\xf0\x9f\x98\\%s",sprintf("%o",c));}}')"
}

function clone-starred-repos() {
  GITUSER=sming; curl "https://api.github.com/users/${GITUSER}/starred?per_page=1000" | grep -o 'git@[^"]*' | parallel -j 25 'git clone {}'
}

function print-path() {
  echo "$PATH" | tr ':' '\n'
}

alias pretty-print-path="print-path"
alias dump-path="print-path"
alias path-dump="print-path"

function envgr() {
  env | grep -Ei "$@" | sort
}

alias interactive-ps-grep="ppgrep"
alias grep-ps-percol="ppgrep"
alias grep-ps-interactive="ppgrep"
alias interactive-kill="ppkill"
alias kill-interactive="ppkill"
alias kill-percol="ppkill"

# From https://apple.stackexchange.com/a/432408/100202 - sets the current iterm2
# tab to a random color
PRELINE="\r\033[A"

# From https://stackoverflow.com/questions/59090903/is-there-any-way-to-get-iterm2-to-color-each-new-tab-with-a-different-color-usi
function random {
    echo -e "\033]6;1;bg;red;brightness;$((1 + $RANDOM % 255))\a"$PRELINE
    echo -e "\033]6;1;bg;green;brightness;$((1 + $RANDOM % 255))\a"$PRELINE
    echo -e "\033]6;1;bg;blue;brightness;$((1 + $RANDOM % 255))\a"$PRELINE
}

function color {
    case $1 in
    green)
    echo -e "\033]6;1;bg;red;brightness;57\a"$PRELINE
    echo -e "\033]6;1;bg;green;brightness;197\a"$PRELINE
    echo -e "\033]6;1;bg;blue;brightness;77\a"$PRELINE
    ;;
    red)
    echo -e "\033]6;1;bg;red;brightness;270\a"$PRELINE
    echo -e "\033]6;1;bg;green;brightness;60\a"$PRELINE
    echo -e "\033]6;1;bg;blue;brightness;83\a"$PRELINE
    ;;
    orange)
    echo -e "\033]6;1;bg;red;brightness;227\a"$PRELINE
    echo -e "\033]6;1;bg;green;brightness;143\a"$PRELINE
    echo -e "\033]6;1;bg;blue;brightness;10\a"$PRELINE
    ;;
    *)
    random
    esac
}

function git-diff-repos() {
  RESULTS="diff-results.patch"
  echo "" > $RESULTS

  for DIR in */; do
    pushd $DIR
    echo "\n———————\nGit diffing $PWD\n———————\n" >> ../$RESULTS
    git --no-pager diff --ignore-space-change -- ':!*poetry.lock' -- ':^.vscode' . >> ../$RESULTS
    popd
  done

  bat $RESULTS
}

function git-info-repos() {
  RESULTS="info-results.txt"
  echo "" > $RESULTS

  for DIR in */; do
    pushd $DIR
    echo "\n———————\nGit info-ing $PWD\n———————\n" >> ../$RESULTS
    git-info 2>&1 >> ../$RESULTS
    popd
  done

  bat $RESULTS
}

function git-merge-develop() {
  echo "\nChecking out develop..." && gco develop && \
  echo "\nPulling develop..." && git pull && \
  echo "\nChecking out -..." && gco - && \
  echo "\nMerging develop in..." && git merge develop
}

function scrcpy-s20() {
  # presumably this once worked but does not now
  # /opt/homebrew/bin/scrcpy --serial R5CN20MZEKJ
  /opt/homebrew/bin/scrcpy --no-audio # -sadb-R5CN20MZEKJ-ogJwLS._adb-tls-connect._tcp.
  if [[ "$?" -ne 0 ]]
  then
    echo "first run usually fails, trying a second time..."
    /opt/homebrew/bin/scrcpy --no-audio
  fi
}
alias run-scrcpy="/Users/peter/.oh-my-zsh/bin/run-scrcpy.sh"
alias scr=run-scrcpy


function dir-with-most-files() {
  ~/bin/dir-with-most-files.sh "$@"
}

alias most-files-dir=dir-with-most-files
alias count-files=dir-with-most-files
alias biggest-dirs=dir-with-most-files

function check-internet() {
  ifconfig en0 | awk -v OFS="\n" '{ print $1 " " $2, $NF }' | grep "inet 192"

}
