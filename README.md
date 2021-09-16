# Base customizations

To be able to build multiple customizations, e.g. multiple Desktop environments, and use better caching, we have split up the customizations into a base folder and further folders. This base folder contains the customizations that are required for all final images.

## User Authentication SSSD and PAM

To authenticate users, we use a connection to our Active Directory via LDAP. This is achieved with [SSSD](https://sssd.io/) (sssd.conf) and PAM (common-session modification) to create the home directory.

SSSD does the mapping of a user to certain Linux attributes automatically:
- Home directory is set to /home/<sAMAccountName>
- The default shell is set to /bin/bash
- The user and group IDs are set automatically with the `ldap_id_mapping = True` option. This maps the IDs based on the Active Directory SID. This is further documented [here](https://linux.die.net/man/5/sssd-ad)

## Password Reminder
The password-reminder script is executed on each user login and checks, whether the user's password is expiring soon against using LDAP. If it expires soon, it notifies the user with a pop-up window that contains a link to a password change web page.

- We use a wrapper script, in order to be able to execute our password-reminder script. This needs to be done, to access a password file, where only root has access.
- 1. The password-reminder script gets the password from a hidden, and root only accessible file.
- 2. Therefore we need to run the script as "sudo", so that the script is running under the root context and can access the credentials.
- 3. As this script needs to be run by a "non-root" user, we need to wrap the execution of the script into "sudo-wrapper.sh"
- 3. This Wrapper script is placed into /etc/profiles.d. On Login, the script is executed for every user.

## Conky

[Conky](https://github.com/brndnmtthws/conky) is a tool to display system information such as the current user, the IP address, CPU and memory information and more.

## Keyboard layout

The keyboard layout can be set with the [keyboard](keyboard) file and is by default set to the Swiss German layout.

## Webapps

The Webapps only work with Chrome and are installed via WebAppInstallForceListe.json. For the Apps to work Chrome must run once, so that the policy is triggered. The desktopfiles are used to set a specific icon and name.

## Browser Favorites/Bookmarks

For both Firefox and Chrome were some favorites set through the preferences.json

## Logging

We are using syslog-ng for sending systemd-events to our remote syslog-ng server (graylog). In order to add other logging metrics, adjust the syslog-ng.conf
