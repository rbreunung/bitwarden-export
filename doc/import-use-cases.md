# Import Use Cases

There are many possibilities how an import of BitWarden may be intended. I focus on the documented ones and appreciate any contributions.

## Relevant Preconditions

In all following use cases you need to be aware of the following preconditions.

### Powershell Preconditions

- Install latest `Powershell` from Microsoft on your system. (at least 7.4)
- Ensure the Security Policy allow you to execute the scripts.

### Export Preconditions

- Bitwarden CLI `bw` is installed
- Bitwarden **Login** and **Unlock** are done

Please refer to the official [Documentation](https://bitwarden.com/help/cli/) in case of doubt.

### Import Preconditions

## Move all credentials to a different server

You export all your data with the intention to move permanently to a different BitWarden server instance.

### Scope

- private vault
- attachments of the private vault
- folder structure of the private vault

In this case the existing export is almost sufficient. The big lack in feature is the movement of attachments.

### Steps

After applied [export preconditions](#export-preconditions) export your data.

```powershell
./export.ps1
```

After applied [import preconditions](#import-preconditions) import your data.

```powershell
# Import the given Path
./import.psi -ExportPath <String>
# e.g.
./import.ps1 -ExportPath ./export-2023-12-19-07-10-25/
```
