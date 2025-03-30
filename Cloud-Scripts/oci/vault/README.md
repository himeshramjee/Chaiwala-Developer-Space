# OCI Vault Actions

This directory contains scripts for interacting with Oracle Cloud Infrastructure (OCI) Vault service.

## oci-vault-actions.sh

A bash script to create and store secrets in OCI Vault using OCI session authentication.

### Features

- Uses OCI session authentication
- Accepts JSON or YAML configuration files
- Creates new vaults and encryption keys if they don't exist
- Creates new secrets or updates existing ones
- Prompts for confirmation before updating existing secrets
- Displays current and new secret values for comparison
- Provides detailed execution summary
- Verbose mode for detailed command output and error diagnostics with suggested corrective actions

### Requirements

- OCI CLI installed and configured
- jq (for JSON parsing)
- yq (for YAML parsing, only if using YAML files)
- base64 (usually pre-installed on most systems)

### Usage

```bash
./oci-vault-actions.sh [-f <secrets_file>] [-p <profile>] [-a <auth_type>] [-v] [-h]
```

Options:

- `-f <secrets_file>`: Path to JSON or YAML file containing secrets configuration (Optional: defaults to sample-secrets.json if not provided)
- `-p <profile>`: OCI CLI profile to use for authentication (Required if not specified in the secrets file)
- `-a <auth_type>`: OCI CLI authentication type (e.g., security_token, api_key) (Optional: defaults to security_token if not specified in command line or in the secrets file)
- `-v`: Verbose mode - display detailed output and error messages with suggested corrective actions
- `-h`: Display help message

### Input File Format

#### JSON Format

```json
{
  "compartment_id": "ocid1.compartment.oc1..example",
  "profile": "DEFAULT",                          // Optional, OCI CLI profile to use for authentication
  "auth_type": "security_token",                 // Optional, OCI CLI authentication type (e.g., security_token, api_key)
  "vault_id": "ocid1.vault.oc1..example",        // Optional, will be created if not provided
  "vault_name": "my-vault",                      // Required if vault_id is not provided
  "encryption_key_id": "ocid1.key.oc1..example", // Optional, will be created if not provided
  "key_name": "my-key",                          // Required if encryption_key_id is not provided
  "secrets": [
    {
      "name": "secret-name",
      "description": "Secret description",
      "content": "Secret content",
      "content_type": "BASE64"
    },
    ...
  ]
}
```

#### YAML Format

```yaml
compartment_id: ocid1.compartment.oc1..example
profile: DEFAULT # Optional, OCI CLI profile to use for authentication
auth_type: security_token # Optional, OCI CLI authentication type (e.g., security_token, api_key)
vault_id: ocid1.vault.oc1..example # Optional, will be created if not provided
vault_name: my-vault # Required if vault_id is not provided
encryption_key_id: ocid1.key.oc1..example # Optional, will be created if not provided
key_name: my-key # Required if encryption_key_id is not provided
secrets:
  - name: secret-name
    description: Secret description
    content: Secret content
    content_type: BASE64
  - ...
```

### Parameters

- `compartment_id`: OCID of the compartment where the vault is located
- `profile`: OCI CLI profile to use for authentication. Must be specified either in the command line or in the configuration file.
- `auth_type`: OCI CLI authentication type (e.g., security_token, api_key). Optional, defaults to security_token if not specified.
- `vault_id`: (Optional) OCID of the vault where secrets will be stored. If not provided or if the vault doesn't exist, a new vault will be created.
- `vault_name`: Name for the vault. Required if `vault_id` is not provided or if the vault doesn't exist.
- `encryption_key_id`: (Optional) OCID of the key used for encrypting secrets. If not provided or if the key doesn't exist, a new key will be created.
- `key_name`: Name for the encryption key. Required if `encryption_key_id` is not provided or if the key doesn't exist.
- `secrets`: Array of secret objects with the following properties:
  - `name`: Name of the secret
  - `description`: Description of the secret
  - `content`: Secret content
  - `content_type`: Type of content (BASE64 or TEXT). If BASE64, the content is assumed to be already base64-encoded. If TEXT, the content will be base64-encoded by the script.

### Examples

Create or update secrets using a JSON file:

```bash
./oci-vault-actions.sh -f sample-secrets.json
```

Create or update secrets using a YAML file:

```bash
./oci-vault-actions.sh -f sample-secrets.yaml
```

Use the default sample-secrets.json file:

```bash
./oci-vault-actions.sh
```

Use a specific OCI profile:

```bash
./oci-vault-actions.sh -p production
```

Use a specific file and profile:

```bash
./oci-vault-actions.sh -f prod-secrets.json -p production
```

Run in verbose mode to see detailed output and error diagnostics:

```bash
./oci-vault-actions.sh -p production -v
```

### Sample Files

This directory includes sample files for reference:

- `sample-secrets.json`: Example JSON configuration
- `sample-secrets.yaml`: Example YAML configuration

### Authentication

The script uses OCI session authentication. Before running the script, ensure you have a valid OCI session for the profile you want to use by running:

```bash
oci session authenticate --profile <profile_name>
```

This will open a browser window for authentication. Once authenticated, the session token will be stored and used by the script.

You must specify which profile to use in one of these ways:

1. Command line option: `-p <profile>`
2. In the secrets file: `"profile": "<profile_name>"`

If no profile is specified, the script will exit with an error.

#### Authentication Type

The script supports different authentication types through the `auth_type` parameter:

1. Command line option: `-a <auth_type>`
2. In the secrets file: `"auth_type": "<auth_type>"`

Common auth types include:
- `security_token` (default): For OCI session authentication
- `api_key`: For API key authentication

If no auth_type is specified either in the command line or in the secrets file, the script defaults to `security_token`.

### Workflow

1. The script validates the input file and checks dependencies
2. It verifies the OCI session is valid
3. It checks if the specified vault exists:
   - If the vault doesn't exist or isn't specified, it creates a new vault
4. It checks if the specified encryption key exists:
   - If the key doesn't exist or isn't specified, it creates a new key
5. For each secret in the configuration file:
   - If the secret doesn't exist, it creates a new secret
   - If the secret exists, it displays the current and new values and prompts for confirmation before updating
6. After processing all secrets, it displays a summary of actions performed

### Error Handling

The script includes comprehensive error handling for:

- Missing dependencies
- Invalid input files
- Invalid or expired OCI sessions
- Failed secret creation or updates

When running in verbose mode (`-v`), the script provides:

- Detailed output of all OCI CLI commands being executed
- Complete error messages from the OCI CLI
- Suggested corrective actions based on the specific error encountered
- Troubleshooting guidance for common issues like permissions, authentication, and parameter validation

### Notes

- Secret content marked as `TEXT` will be automatically base64-encoded by the script
- Secret content marked as `BASE64` is assumed to be already base64-encoded
- The script will prompt for confirmation before updating existing secrets
- For security reasons, consider using environment variables or a secure method to pass sensitive information to the script
