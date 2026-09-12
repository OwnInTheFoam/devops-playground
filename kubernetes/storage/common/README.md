# Common storage setup

Run these host-level setup scripts before installing a specific storage solution such as Longhorn or dynamic-nfs.

## Host/server

If you are using a NFS server run the following on the host.

```bash
sudo ./installHost.sh
```

## Worker/client nodes

Run the following on each of the kubernetes nodes.

```bash
sudo ./installClient.sh
```

The scripts install common storage dependencies such as NFS client support, open-iscsi, cryptsetup, and device mapper tooling. The host script also installs and enables the NFS server package for storage setups that export NFS shares.
