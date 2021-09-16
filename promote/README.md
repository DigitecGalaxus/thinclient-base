# Thin Client Promotion

This folder solves two things: Uploading the squashfs files to the netboot server and creating the IPXE menus.

## Uploading to the Netboot Server

In the [promote.sh](promote.sh) script, the squashfs file on the local file system that is passed to the script is uploaded to the netboot server into a folder that is also passed as argument to the script. This allows to promote builds into different folders, e.g. development (i.e. untested) builds to the `dev` folder and production builds to the `prod` folder. Additionally to the squashfs file itself, a kernel version file is created that describes the kernel version that should be used together with the squashfs. The script assumes that the squashfs was tested with the latest kernel version, which is read from the netboot server at `http://<netbootIP>/kernels/latest-kernel-version.json`. The naming of the kernel file is similar to the squashfs:

```txt
[flavor]-[branchname]-[date]-[shortsha].squashfs
[flavor]-[branchname]-[date]-[shortsha]-kernel.json
```

## IPXE Menus

### Content

The iPXE-Flow works in 3 steps:

1. Load the initial bootloader from the netboot-server.
2. Triggering menu.ipxe which includes the logic to serve custom MAC logic as well as a reduced boot menu.
3. (Optional: Triggering advancedmenu.ipxe which includes dev, older prod and various other boot options.)

The caching-logic tries to set the next-server if it has a matching default-gw. If there isn't a matching default-gw, the default netboot-server will be set. Furthermore, if the client is not able to fetch the kernel-json-files, it will fallback to the default netboot-server as well. This solution does not seem to be superpretty from a coding standpoint. Yet it is the lightest and fastest that came to mind. Ping for instance makes the bootloader heavier and has a timeout (to ping 10 hosts for example).

### Creation

In out netboot structure, we have a layered menu structure with chain loading. The **main menu** is the file titled `menu.ipxe`. This file is generated first in the [generate-new-ipxe-menus.sh](generate-new-ipxe-menus.sh) script. This is templated with the Jinja2 template [menu.ipxe.j2](menu.ipxe.j2). When running the script, the new menu is generated with the squashfs filename passed to the script. The **advanced menu** is generated with the Jinja2 template [advancedmenu.ipxe.j2](advancedmenu.ipxe.j2), this menu lists all files in the `prod` and `dev` folder of the netboot server and offers to boot those.
