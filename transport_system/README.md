# Bundle SEAD Clearing House Transport System to a Change Request Script

This script, [`bundle-to-change-request`](command:_github.copilot.openRelativePath?%5B%22..%2Fsead_clearinghouse%2Ftransport_system%2Fbundle-to-change-request%22%5D "../sead_clearinghouse/transport_system/bundle-to-change-request"), is a Bash script that automates the process of generating and adding a change request to the SEAD Change Control System that installs (or updates) the SEAD clearing house transport system.

## Usage

You can run the script with various options:

- `--add-change-request`: Add a change request to the SEAD Control System.
- `--note`: Add a note to the change request and issue.
- `--related-issue-id`: Specify a related issue Github id.
- `--no-create-issue`: Do not create an issue.
- `--dry-run`: Do not create a change request or issue - just print commands.
- `--sead-change-control-root`: Specify the path to the SEAD Change Control System.
- `--work-folder=dir`: Override the default work directory (not recommended).

## Example

```sh
./bundle-to-change-request --add-change-request --note "This is a test note" --related-issue-id 123
```

This will generate a change request in the SEAD change control system, add a note to it, and link it to the Github issue with the id 123.

## Requirements

This script requires Bash and access to the SEAD Change Control System.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Acknowledgments

- Thanks to the SEAD project for providing the opportunity to develop this script.

