# Thin Client Promotion

This folder uploads the squashfs file to the netboot server.

## Uploading to the Netboot Server

In the [promote.sh](promote.sh) script, the squashfs file on the local file system that is passed to the script is uploaded to the netboot server into a folder that is also passed as argument to the script. This allows to promote builds into different folders, e.g. development (i.e. untested) builds to the `dev` folder and production builds to the `prod` folder. Additionally to the squashfs file itself, a kernel version file is created that describes the kernel version that should be used together with the squashfs. The script assumes that the squashfs was tested with the latest kernel version, which is read from the netboot server at `http://<netbootIP>/kernels/latest-kernel-version.json`. The naming of the kernel file is similar to the squashfs:

```txt
[flavor]-[branchname]-[date]-[shortsha].squashfs
[flavor]-[branchname]-[date]-[shortsha]-kernel.json
```
