## Platforms with a built-in command-not-found handler init file

if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
  function command_not_found_handler {
    # check because c-n-f could've been removed in the meantime
    if [ -x /usr/lib/command-not-found ]; then
      /usr/lib/command-not-found -- "$1"
      return $?
    elif [ -x /usr/share/command-not-found/command-not-found ]; then
      /usr/share/command-not-found/command-not-found -- "$1"
      return $?
    else
      printf "zsh: command not found: %s\n" "$1" >&2
      return 127
    fi
    return 0
  }
fi

# Fedora command-not-found support
if [ -f /usr/libexec/pk-command-not-found ]; then
  command_not_found_handler() {
    runcnf=1
    retval=127
    [ ! -S /var/run/dbus/system_bus_socket ] && runcnf=0
    [ ! -x /usr/libexec/packagekitd ] && runcnf=0
    if [ $runcnf -eq 1 ]; then
      /usr/libexec/pk-command-not-found $@
      retval=$?
    fi
    return $retval
  }
fi

# Fedora: https://fedoraproject.org/wiki/Features/PackageKitCommandNotFound
if [[ -x /usr/libexec/pk-command-not-found ]]; then
  command_not_found_handler() {
    if [[ -S /var/run/dbus/system_bus_socket && -x /usr/libexec/packagekitd ]]; then
      /usr/libexec/pk-command-not-found "$@"
      return $?
    fi

    printf "zsh: command not found: %s\n" "$1" >&2
    return 127
  }
fi

# NixOS command-not-found support
if [ -x /run/current-system/sw/bin/command-not-found ]; then
  command_not_found_handler() {
    /run/current-system/sw/bin/command-not-found $@
  }
fi
