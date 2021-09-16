# Kernel Updates

This folder contains logic to fetch the latest kernels from the upstream netbootxyz repository and upload them to our netboot server. The [yaml-parser.sh](yaml-parser.sh) file is based on https://gist.github.com/pkuczynski/8665367.

The script `get-kernel-updates.sh` uploads the kernels to the kernels folder on the netboot server and creates a directory with the kernel version. It uploads the kernel itself as well as the initrd to this folder. It also creates the `latest-kernel-version.json` when there is a newer kernel available.

The kernel version can be determined with the command

```sh
file -b latest-kernel | grep -o 'version [^ ]*' | cut -d ' ' -f 2
```
