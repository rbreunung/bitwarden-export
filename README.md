# Bitwarden Export

If you want to move Bitwarden credentials to another server, there is one major feature missing in the vendors clients. Export and reimport your credentials with related attachments.

This Powershell script shall solve the issue. Please refer to the designed [use cases](doc/import-use-cases.md).

## Preconditions

1. All commands are executed in a Powershell. (Tested with 7.4)
2. BitWarden CLI is installed and authenticated.
3. Node.js version 16 is installed.

```powershell
# check for Node.js version 16
node --version
# login to your account
bw login
# Optional: unlock your account if you already are logged in from a passed session
bw unlock
# set the key for the terminal session to avoid further authentication queries
$env:BW_SESSION="<my token>"
# ensure your data us up-to-date
bw sync
```

## Hints

## Developer Notes

### Node.js 16

The version of Node.js 16 is required by the import-attachment-step. All other steps are tested and working with latest Node.js. The command `bw create attachment` is currently broken, when executed with any other Node.js version. This is a [known issue](https://github.com/dani-garcia/vaultwarden/discussions/4217#discussioncomment-7989155).

### Export data model

- Export folder with current date.
  - `export-list-folders.json` contains an array of all folders as provided by `bw list folders`.
  - `export-list-items.json` contains an array of all items as provided by `bw list items`.
  - `export-list-organizations.json` contains an array of all items as provided by `bw list organizations`.
  - `export-private.json` contains the export of the private vault.
  - `export-UUID.json` contains the export of each **organization** with `id` UUID.
  - `UUID` folder contains the attachment files of the **item** with `id` UUID.
    - The attachment files are in their original name with their content.
- Additional files created by the import.
  - `folder-map.json` contains all folders and their `target-id` in the target vault. This is created by the import-folder-step and required by import-items-step in order to reassign all items to their prior folders.
  - `item-map.json` contains all items and their `target-id` in the target vault. This is created by the import-items-step and required by the import-attachments-step in order to reassign all attachments to their prior items.

### Edit a Value

Editing a value in an converted Object is pretty straight forward.

```powershell
bw list organizations | ConvertFrom-Json | ForEach-Object {$_.name = "foo"; $_} | ConvertTo-Json
```

### JSON Conversion Depth

Of course the default `-Depth` values of `ConvertFrom-Json` and `ConvertTo-Json` are not equal. With a `ConvertTo-Json` default depth of 2 you get nicely partially converted objects if you test your roundtrip.

```powershell
$data = Invoke-Expression "bw list items --pretty"  | ConvertFrom-Json -Depth 10 | ConvertTo-Json -Depth 10
```

### Approach `bw list`

After testing the approach in the first place I figured out, it will not be simply possible to reimport this list. More promising seems the approach to go with the official JSON export function.

Pro:

- All elements from the vault including all organizations in one view.
- All references to attachments included.

Con:

- No folder descriptions exported.
- No organization descriptions.
- Can be imported one by one through item create. (adapt item -> encode -> create)

### Approach `bw export`

The official export may support a better import behavior, but there are relevant shortages.

Pro:

- support of JSON import from BitWarden
- all Folders exported

Con:

- Major: No attachment is referenced.
- Minor: Every organization and the private vault need to be exported separately.
- Does not export folder IDs for organization vault export.

### JSON parsing via `Invoke-Expression`

Special characters are not properly parsed when reading a `bw list` via std out stream directly into a Powershell pipeline. The cause I did not get till now. A workaround is to pipe the std out directly into a file and continue the work with a file.

```powershell
bw list items > export-list.json
```
