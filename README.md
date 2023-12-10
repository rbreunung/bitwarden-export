# Bitwarden Export

If you want to move Bitwarden credentials to another server, there is one major feature missing in the vendors clients. Export and reimport your credentials with related attachments.

This Powershell script shall solve the issue.

## Preconditions

1. All commands are executed in a Powershell. (Tested with 7.4)
2. BitWarden CLI is installed and authenticated.

```powershell
# login to your account
bw login
# Optional: unlock your account if you already are logged in from a passed session
bw unlock
# set the key for the terminal session to avoid further authentication queries
$env:BW_SESSION="<my token>"
```

## Hints

## Developer Notes

### Export data model

- export folder with current date
  - `export-private.json` contains the export of the private vault
  - `UUID.json` contains the description of each **organization** with `id` UUID
  - `export-UUID.json` contains the export of each **organization** with `id` UUID
  - `UUID` folder contains the attachment files of the **item** with `id` UUID

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