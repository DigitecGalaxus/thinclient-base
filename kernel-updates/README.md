# Kernel Updates

This folder contains logic to fetch the latest kernels for the current ubuntu major version from the upstream netbootxyz repository and upload them to our netboot server. The [yaml-parser.sh](yaml-parser.sh) file is based on https://gist.github.com/pkuczynski/8665367.

The script `get-kernel-updates.sh` uploads the kernels to the kernels folder on the storage account and creates a directory with the kernel version. It uploads the kernel itself as well as the initrd to this folder. It also creates the `latest-kernel-version.json` when there is a newer kernel available.

The kernel version can be determined with the command

```sh
file -b latest-kernel | grep -o 'version [^ ]*' | cut -d ' ' -f 2
```

## Updating to a new ubuntu major version

When updating to the next ubuntu version, e.g. 23.10, the latest compatible kernel has to be determined manually. This is done in the [get-kernel-updates.sh](./get-kernel-updates.sh) script, by looking for a matching yaml path in the endpoints.yaml file, e.g. [here](https://github.com/netbootxyz/netboot.xyz/blob/736b4f99214867f33034566b5bcab3d24dcee2c9/endpoints.yml#L2107) (use the latest release instead of the linked one).
