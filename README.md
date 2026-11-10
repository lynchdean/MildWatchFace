Watch face for Mild Activity Run club

For instructions please see Garmin IQ store page

For a list of specific devices that are supported please view monkey.jungle

## Checking your changes build

CI only runs static checks (`scripts/check_resource_refs.py`) — no Garmin
SDK, no credentials, nothing that could touch your Garmin account. Before
a release, or after editing `monkey.jungle`/`manifest.xml`, run a real
compile check locally against your own installed Connect IQ SDK:

```
CIQ_KEY=/path/to/developer_key ./scripts/compile-check.sh
```

This compiles one representative device per resource/annotation bucket.

![Image 17-09-2024 at 12 12](https://github.com/user-attachments/assets/64778082-d94f-4691-af2e-35591f075843)
