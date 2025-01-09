
### How to install SEAD Clearinghouse DB schema

Script `install_clearinghouse_database.bash` creates or updates the `clearing_house` schema on the target database. This schema contains all required tables, functions and data needed for the SEAD Clearinghouse system.
Please note that the script _must_ be run as database user `clearinghouse_worker`.

The script will abort if `clearing_house` schema already exists on server unless user specifies how existing schema should be handled.

#### Usage

```bash
source ./install_clearinghouse_database.bash [--dbhost=target-server] [--port=port] [--dbname=target-database] [--on-schema-exists=abort|drop|update]
```

#### Install flow

The script installs the schema in the following steps:
- Checks the configuration
- Sets clearinghouse worker permissions (executed as humlab_admin)
- Sets up the clearinghouse schema
- Installs scripts for creating the DB model, populationg and data
- Creates the model by calling installed scripts
- Installs data generations scripts for the reports displayed in the web API
- Assign privileges to clearinghouse worker
