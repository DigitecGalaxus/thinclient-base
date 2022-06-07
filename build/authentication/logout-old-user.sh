#!/bin/bash
set -eu -o pipefail

# For memory management on concurrently logged in user sessions, this script deletes the home directory and the user itself, if more than 2 other users are logged in. The script is supposed to run on login of a new session. It finds the user that has been logged in the longest and deletes it.

numberOfSessions=$(who | grep -v $(logname) | grep tty | wc -l)
if [[ $numberOfSessions -gt 2 ]]; then
  # Get the username of the oldest login session. Explanation of the command chaining:
  # who prints something like this:
  # reset.mfa :1 2021-04-23 11:20 (:1)
  # christian.cadruvi :1 2021-04-23 11:25 (:1)
  # Unfortunately, the documentation does not state whether this is sorted or ordered somehow. So we have to do this ourselves.
  # First, exclude the user who is currently logging in (grep -v $(logname),
  # then get the date and time in an ordered string to sort it, additionally pass on the corresponding username.
  # Then sort it and get the entry with the oldest login timestamp (sort | head -n 1) and get the username ($2)
  # Revert the outputs of commands to their usual output, otherwise `who` prints the date differently
  export LC_ALL=
  oldestSessionUsername=$(who | grep -v $(logname) | grep tty | awk '{printf("%s-%s %s\n",$3,$4,$1)}' | sort | head -n 1 | awk '{ print $2 }')
  loginctl kill-user "$oldestSessionUsername"
  rm -rf "/home/${oldestSessionUsername:?}/*"
fi
