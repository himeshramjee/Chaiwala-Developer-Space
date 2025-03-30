#!/bin/bash
#
# Script to create and store secrets in OCI Vault
# Uses OCI session authentication
# Accepts a JSON or YAML file containing target compartment and list of secrets
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
verbose_mode=0
secrets_file="sample-secrets.json"
profile=""
auth_type="" # Will be set from file or defaulted to security_token if not specified
summary=()

# Function to display usage information
usage() {
    echo -e "${BLUE}Usage:${NC} $0 [-f <secrets_file>] [-p <profile>] [-a <auth_type>] [-v] [-h]"
    echo -e "  -f <secrets_file>  Path to JSON or YAML file containing secrets configuration"
    echo -e "                     (Optional: defaults to sample-secrets.json if not provided)"
    echo -e "  -p <profile>       OCI CLI profile to use for authentication"
    echo -e "                     (Required if not specified in the secrets file)"
    echo -e "  -a <auth_type>     OCI CLI authentication type (e.g., security_token, api_key)"
    echo -e "                     (Defaults to security_token if not specified)"    
    echo -e "  -v                 Verbose mode - display detailed output and error messages"
    echo -e "                     with suggested corrective actions"
    echo -e "  -h                 Display this help message"
    echo
    echo -e "${BLUE}File format (JSON):${NC}"
    echo -e '{
  "compartment_id": "ocid1.compartment.oc1..example",
  "profile": "DEFAULT", // Optional, OCI CLI profile to use for authentication
  "auth_type": "security_token", // Optional, OCI CLI authentication type (e.g., security_token, api_key)
  "vault_id": "ocid1.vault.oc1..example", // Optional, will be created if not provided
  "vault_name": "my-vault", // Required if vault_id is not provided
  "encryption_key_id": "ocid1.key.oc1..example", // Optional, will be created if not provided
  "key_name": "my-key", // Required if encryption_key_id is not provided
  "secrets": [
    {
      "name": "secret-name",
      "description": "Secret description",
      "content": "Secret content",
      "content_type": "BASE64" 
    },
    ...
  ]
}'
    echo
    echo -e "${BLUE}File format (YAML):${NC}"
    echo -e 'compartment_id: ocid1.compartment.oc1..example
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
  - ...'
    exit 1
}

# Function to display verbose output
log_verbose() {
    if [ $verbose_mode -eq 1 ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to display error messages
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [ $verbose_mode -eq 1 ] && [ -n "$2" ]; then
        echo -e "${YELLOW}[SUGGESTION]${NC} $2"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add auth parameter to OCI commands
add_auth_param() {
    if [[ -n "$auth_type" ]]; then
        echo "--auth $auth_type"
    else
        echo ""
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=0

    echo -e "${BLUE}Checking dependencies...${NC}"
    
    if ! command_exists oci; then
        log_error "OCI CLI is not installed. Please install it first." \
            "Visit: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
        missing_deps=1
    fi
    
    if ! command_exists jq; then
        log_error "jq is not installed. Please install it first." \
            "Run: brew install jq (macOS) or apt-get install jq (Ubuntu/Debian)"
        missing_deps=1
    fi
    
    if ! command_exists base64; then
        log_error "base64 is not installed." \
            "This utility should be pre-installed on most systems."
        missing_deps=1
    fi

    # Check for YAML parser if needed
    if [[ "$secrets_file" == *.yaml || "$secrets_file" == *.yml ]]; then
        if ! command_exists yq; then
            log_error "yq is not installed. It's required for YAML parsing." \
                "Run: brew install yq (macOS) or snap install yq (Ubuntu/Debian)"
            missing_deps=1
        fi
    fi
    
    if [ $missing_deps -eq 1 ]; then
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies are installed.${NC}"
}

# Function to check OCI CLI session
check_oci_session() {
    echo -e "${BLUE}Checking OCI session for profile: $profile with auth type: $auth_type...${NC}"
    
    local auth_param=$(add_auth_param)
    
    local oci_cmd="oci session validate --profile \"$profile\" $auth_param 2>/dev/null"
    log_verbose "Executing: $oci_cmd"
    
    if ! eval "$oci_cmd"; then
        log_error "OCI session for profile '$profile' is not valid or has expired." \
            "Please run 'oci session authenticate --profile $profile' to create a new session."
        exit 1
    fi
    
    echo -e "${GREEN}OCI session for profile '$profile' is valid.${NC}"
}

# Function to parse input file
parse_input_file() {
    local file_ext="${secrets_file##*.}"
    
    echo -e "${BLUE}Parsing input file: $secrets_file${NC}"
    
    # Check if file exists
    if [ ! -f "$secrets_file" ]; then
        log_error "Input file '$secrets_file' does not exist." \
            "Please provide a valid file path or create the file first."
        exit 1
    fi
    
    # Parse based on file extension
    if [ "$file_ext" = "json" ]; then
        # Validate JSON syntax
        if ! jq empty "$secrets_file" 2>/dev/null; then
            log_error "Invalid JSON format in $secrets_file." \
                "Please check the file for syntax errors."
            exit 1
        fi
        
        # Extract values from JSON
        compartment_id=$(jq -r '.compartment_id // empty' "$secrets_file")
        file_profile=$(jq -r '.profile // empty' "$secrets_file")
        file_auth_type=$(jq -r '.auth_type // empty' "$secrets_file")
        vault_id=$(jq -r '.vault_id // empty' "$secrets_file")
        vault_name=$(jq -r '.vault_name // empty' "$secrets_file")
        encryption_key_id=$(jq -r '.encryption_key_id // empty' "$secrets_file")
        key_name=$(jq -r '.key_name // empty' "$secrets_file")
        
        # Validate mandatory fields
        if [ -z "$compartment_id" ]; then
            log_error "compartment_id is required in the input file." \
                "Please specify a valid compartment OCID in your config file."
            exit 1
        fi
        
        # Check if vault_name is provided when vault_id is empty
        if [ -z "$vault_id" ] && [ -z "$vault_name" ]; then
            log_error "vault_name is required when vault_id is not provided." \
                "Please specify either a vault_id or a vault_name in your config file."
            exit 1
        fi
        
        # Check if key_name is provided when encryption_key_id is empty
        if [ -z "$encryption_key_id" ] && [ -z "$key_name" ]; then
            log_error "key_name is required when encryption_key_id is not provided." \
                "Please specify either an encryption_key_id or a key_name in your config file."
            exit 1
        fi
        
        # Get secrets array
        secret_count=$(jq '.secrets | length' "$secrets_file")
        
        if [ "$secret_count" -eq 0 ]; then
            log_error "No secrets found in the input file." \
                "Please add at least one secret entry in the 'secrets' array."
            exit 1
        fi
        
    elif [ "$file_ext" = "yaml" ] || [ "$file_ext" = "yml" ]; then
        # Check if yq is installed again just to be sure
        if ! command_exists yq; then
            log_error "yq is not installed. It's required for YAML parsing." \
                "Run: brew install yq (macOS) or snap install yq (Ubuntu/Debian)"
            exit 1
        fi
        
        # Extract values from YAML
        compartment_id=$(yq e '.compartment_id' "$secrets_file")
        file_profile=$(yq e '.profile' "$secrets_file")
        file_auth_type=$(yq e '.auth_type' "$secrets_file")
        vault_id=$(yq e '.vault_id' "$secrets_file")
        vault_name=$(yq e '.vault_name' "$secrets_file")
        encryption_key_id=$(yq e '.encryption_key_id' "$secrets_file")
        key_name=$(yq e '.key_name' "$secrets_file")
        
        # Check for null or empty values
        if [ "$compartment_id" = "null" ]; then compartment_id=""; fi
        if [ "$file_profile" = "null" ]; then file_profile=""; fi
        if [ "$file_auth_type" = "null" ]; then file_auth_type=""; fi
        if [ "$vault_id" = "null" ]; then vault_id=""; fi
        if [ "$vault_name" = "null" ]; then vault_name=""; fi
        if [ "$encryption_key_id" = "null" ]; then encryption_key_id=""; fi
        if [ "$key_name" = "null" ]; then key_name=""; fi
        
        # Validate mandatory fields
        if [ -z "$compartment_id" ]; then
            log_error "compartment_id is required in the input file." \
                "Please specify a valid compartment OCID in your config file."
            exit 1
        fi
        
        # Check if vault_name is provided when vault_id is empty
        if [ -z "$vault_id" ] && [ -z "$vault_name" ]; then
            log_error "vault_name is required when vault_id is not provided." \
                "Please specify either a vault_id or a vault_name in your config file."
            exit 1
        fi
        
        # Check if key_name is provided when encryption_key_id is empty
        if [ -z "$encryption_key_id" ] && [ -z "$key_name" ]; then
            log_error "key_name is required when encryption_key_id is not provided." \
                "Please specify either an encryption_key_id or a key_name in your config file."
            exit 1
        fi
        
        # Get secrets array length
        secret_count=$(yq e '.secrets | length' "$secrets_file")
        
        if [ "$secret_count" -eq 0 ]; then
            log_error "No secrets found in the input file." \
                "Please add at least one secret entry in the 'secrets' array."
            exit 1
        fi
    else
        log_error "Unsupported file format: .$file_ext" \
            "Please provide a JSON (.json) or YAML (.yaml/.yml) file."
        exit 1
    fi
    
    # Use profile and auth_type from command line if provided, otherwise use from file
    if [ -z "$profile" ]; then
        profile="$file_profile"
        
        if [ -z "$profile" ]; then
            log_error "No profile specified in command line or in the input file." \
                "Please specify a profile using -p option or add a 'profile' field in your config file."
            exit 1
        fi
    fi
    
    # Use auth_type from file if it's provided and no command line auth_type was specified
    if [ -z "$auth_type" ] && [ -n "$file_auth_type" ]; then
        auth_type="$file_auth_type"
    fi
    
    # Default to security_token if still not set
    if [ -z "$auth_type" ]; then
        auth_type="security_token"
        log_verbose "No auth_type specified in command line or input file. Defaulting to security_token."
    fi
    
    echo -e "${GREEN}Input file parsed successfully.${NC}"
    log_verbose "Compartment ID: $compartment_id"
    log_verbose "Profile: $profile"
    log_verbose "Auth Type: $auth_type"
    log_verbose "Vault ID: $vault_id"
    log_verbose "Vault Name: $vault_name"
    log_verbose "Encryption Key ID: $encryption_key_id"
    log_verbose "Key Name: $key_name"
    log_verbose "Secret Count: $secret_count"
}

# Function to get vault details or create a new vault
get_or_create_vault() {
    local vault_status="UNKNOWN"
    local auth_param=$(add_auth_param)
    
    # If vault_id is provided, check if it exists
    if [ -n "$vault_id" ]; then
        echo -e "${BLUE}Checking if vault with ID '$vault_id' exists...${NC}"
        
        local oci_cmd="oci kms management vault get --vault-id \"$vault_id\" --profile \"$profile\" $auth_param 2>/dev/null"
        log_verbose "Executing: $oci_cmd"
        
        if ! vault_json=$(eval "$oci_cmd"); then
            log_error "Failed to retrieve vault with ID '$vault_id'." \
                "Check if the vault_id is correct and you have sufficient permissions."
            exit 1
        fi
        
        vault_status=$(echo "$vault_json" | jq -r '.data."lifecycle-state"')
        echo -e "${GREEN}Vault found. Status: $vault_status${NC}"
        
        # Check if vault is in ACTIVE state
        if [ "$vault_status" != "ACTIVE" ]; then
            log_error "Vault is not in ACTIVE state. Current state: $vault_status" \
                "Wait for the vault to become ACTIVE before proceeding."
            exit 1
        fi
    else
        # Check if a vault with the given name already exists
        echo -e "${BLUE}Checking if vault with name '$vault_name' exists in compartment...${NC}"
        
        local oci_cmd="oci kms management vault list --compartment-id \"$compartment_id\" --profile \"$profile\" $auth_param 2>/dev/null"
        log_verbose "Executing: $oci_cmd"
        
        if ! vaults_json=$(eval "$oci_cmd"); then
            log_error "Failed to list vaults in compartment." \
                "Check your permissions and network connectivity."
            exit 1
        fi
        
        # Check for active vaults with the matching name
        local matching_vaults=$(echo "$vaults_json" | jq -r --arg name "$vault_name" '.data[] | select(."display-name" == $name and ."lifecycle-state" == "ACTIVE") | .id' 2>/dev/null)
        local vault_count=$(echo "$matching_vaults" | grep -v '^$' | wc -l | tr -d ' ')
        
        if [ "$vault_count" -gt 1 ]; then
            log_error "Multiple active vaults with name '$vault_name' found. Please specify a vault_id instead." \
                "You can list all vaults with 'oci kms management vault list --compartment-id \"$compartment_id\" --profile \"$profile\" $auth_param'"
            exit 1
        elif [ "$vault_count" -eq 1 ]; then
            vault_id=$(echo "$matching_vaults" | tr -d ' \n')
            echo -e "${GREEN}Found existing vault with name '$vault_name' in ACTIVE state. ID: $vault_id${NC}"
            
            # Get vault status to double-check
            local oci_cmd="oci kms management vault get --vault-id \"$vault_id\" --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! vault_json=$(eval "$oci_cmd"); then
                log_error "Failed to retrieve existing vault details." \
                    "This might be a temporary issue. Try again later."
                exit 1
            fi
            
            vault_status=$(echo "$vault_json" | jq -r '.data."lifecycle-state"')
            echo -e "${GREEN}Vault status: $vault_status${NC}"
            
            # Check if vault is in ACTIVE state
            if [ "$vault_status" != "ACTIVE" ]; then
                log_error "Existing vault is not in ACTIVE state. Current state: $vault_status" \
                    "Wait for the vault to become ACTIVE before proceeding."
                exit 1
            fi
        else
            # Create new vault
            echo -e "${BLUE}Creating new vault with name '$vault_name'...${NC}"
            
            local oci_cmd="oci kms management vault create --compartment-id \"$compartment_id\" --display-name \"$vault_name\" --vault-type DEFAULT --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! create_response=$(eval "$oci_cmd"); then
                log_error "Failed to create new vault." \
                    "Check your permissions and if you have reached the vault limit for your tenancy."
                exit 1
            fi
            
            vault_id=$(echo "$create_response" | jq -r '.data.id')
            
            if [ -z "$vault_id" ]; then
                log_error "Failed to extract vault ID from creation response." \
                    "This is likely an issue with the OCI CLI response format."
                exit 1
            fi
            
            echo -e "${GREEN}New vault created. ID: $vault_id${NC}"
            summary+=("Created new vault: $vault_name ($vault_id)")
            
            # Wait for vault to become active
            echo -e "${YELLOW}Waiting for vault to become ACTIVE...${NC}"
            local max_attempts=30
            local attempt=1
            
            while [ $attempt -le $max_attempts ]; do
                local oci_cmd="oci kms management vault get --vault-id \"$vault_id\" --profile \"$profile\" $auth_param 2>/dev/null"
                log_verbose "Executing: $oci_cmd (attempt $attempt/$max_attempts)"
                
                if vault_json=$(eval "$oci_cmd"); then
                    vault_status=$(echo "$vault_json" | jq -r '.data."lifecycle-state"')
                    
                    if [ "$vault_status" = "ACTIVE" ]; then
                        echo -e "${GREEN}Vault is now ACTIVE.${NC}"
                        break
                    else
                        echo -e "${YELLOW}Vault status: $vault_status. Waiting...${NC}"
                    fi
                else
                    echo -e "${YELLOW}Failed to get vault status. Retrying...${NC}"
                fi
                
                attempt=$((attempt+1))
                sleep 10
            done
            
            if [ "$vault_status" != "ACTIVE" ]; then
                log_error "Vault did not become ACTIVE in the expected time." \
                    "You might need to check the vault status in the OCI Console or try again later."
                exit 1
            fi
        fi
    fi
}

# Function to get encryption key details or create a new key
get_or_create_key() {
    local auth_param=$(add_auth_param)
    
    # Get the management endpoint for the vault
    echo -e "${BLUE}Getting management endpoint for vault...${NC}"
    local oci_cmd="oci kms management vault get --vault-id \"$vault_id\" --profile \"$profile\" $auth_param 2>/dev/null"
    log_verbose "Executing: $oci_cmd"
    
    if ! vault_endpoint_json=$(eval "$oci_cmd"); then
        log_error "Failed to get vault details for management endpoint." \
            "Check if the vault_id is correct and you have sufficient permissions."
        exit 1
    fi
    
    management_endpoint=$(echo "$vault_endpoint_json" | jq -r '.data."management-endpoint"')
    if [ -z "$management_endpoint" ] || [ "$management_endpoint" = "null" ]; then
        log_error "Failed to extract management endpoint from vault details." \
            "Verify the vault is in the ACTIVE state and has a management endpoint."
        exit 1
    fi
    
    echo -e "${GREEN}Management endpoint: $management_endpoint${NC}"
    
    # If encryption_key_id is provided, check if it exists
    if [ -n "$encryption_key_id" ]; then
        echo -e "${BLUE}Checking if encryption key with ID '$encryption_key_id' exists...${NC}"
        
        local oci_cmd="oci kms management key get --key-id \"$encryption_key_id\" --endpoint \"$management_endpoint\" --profile \"$profile\" $auth_param 2>/dev/null"
        log_verbose "Executing: $oci_cmd"
        
        if ! key_json=$(eval "$oci_cmd"); then
            log_error "Failed to retrieve encryption key with ID '$encryption_key_id'." \
                "Check if the encryption_key_id is correct and you have sufficient permissions."
            exit 1
        fi
        
        key_status=$(echo "$key_json" | jq -r '.data."lifecycle-state"')
        echo -e "${GREEN}Encryption key found. Status: $key_status${NC}"
        
        # Check if key is in ENABLED state
        if [ "$key_status" != "ENABLED" ]; then
            log_error "Encryption key is not in ENABLED state. Current state: $key_status" \
                "The key must be in the ENABLED state to use it for encrypting secrets."
            exit 1
        fi
    else
        # Check if a key with the given name already exists
        echo -e "${BLUE}Checking if encryption key with name '$key_name' exists in vault...${NC}"
        
        local oci_cmd="oci kms management key list --compartment-id \"$compartment_id\" --endpoint \"$management_endpoint\" --profile \"$profile\" $auth_param 2>/dev/null"
        log_verbose "Executing: $oci_cmd"
        
        if ! keys_json=$(eval "$oci_cmd"); then
            log_error "Failed to list encryption keys in vault." \
                "Check your permissions and network connectivity."
            exit 1
        fi
        
        # Check for keys in enabled state with matching name and belonging to the current vault
        # First, let's log the structure of a key object to help with debugging
        if [ $verbose_mode -eq 1 ] && [ "$(echo "$keys_json" | jq -r '.data | length')" -gt 0 ]; then
            echo -e "${BLUE}[DEBUG] First key object structure:${NC}"
            echo "$keys_json" | jq -r '.data[0]'
        fi
        
        # Now filter for matching keys - the correct field for vault ID might be "vault-id", "vault_id", or "compartment-id"
        local matching_keys=$(echo "$keys_json" | jq -r --arg name "$key_name" --arg vaultid "$vault_id" '.data[] | select(."display-name" == $name and ."lifecycle-state" == "ENABLED") | .id' 2>/dev/null)
        local key_count=$(echo "$matching_keys" | grep -v '^$' | wc -l | tr -d ' ')
        
        if [ "$key_count" -gt 1 ]; then
            log_error "Multiple enabled keys with name '$key_name' found in vault. Please specify an encryption_key_id instead." \
                "You can list all keys with 'oci kms management key list --compartment-id \"$compartment_id\" --endpoint \"$management_endpoint\" --profile \"$profile\" $auth_param'"
            exit 1
        elif [ "$key_count" -eq 1 ]; then
            encryption_key_id=$(echo "$matching_keys" | tr -d ' \n')
            echo -e "${GREEN}Found existing encryption key with name '$key_name' in ENABLED state. ID: $encryption_key_id${NC}"
            
            # Get key status to double-check
            local oci_cmd="oci kms management key get --key-id \"$encryption_key_id\" --endpoint \"$management_endpoint\" --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! key_json=$(eval "$oci_cmd"); then
                log_error "Failed to retrieve existing encryption key details." \
                    "This might be a temporary issue. Try again later."
                exit 1
            fi
            
            key_status=$(echo "$key_json" | jq -r '.data."lifecycle-state"')
            echo -e "${GREEN}Encryption key status: $key_status${NC}"
            
            # Check if key is in ENABLED state
            if [ "$key_status" != "ENABLED" ]; then
                log_error "Existing encryption key is not in ENABLED state. Current state: $key_status" \
                    "The key must be in the ENABLED state to use it for encrypting secrets."
                exit 1
            fi
        else
            # Create new encryption key
            echo -e "${BLUE}Creating new encryption key with name '$key_name'...${NC}"
            
            local oci_cmd="oci kms management key create --compartment-id \"$compartment_id\" --display-name \"$key_name\" --endpoint \"$management_endpoint\" --key-shape '{\"algorithm\":\"AES\",\"length\":32}' --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! create_response=$(eval "$oci_cmd"); then
                log_error "Failed to create new encryption key." \
                    "Check your permissions and if you have reached the key limit for your vault."
                exit 1
            fi
            
            encryption_key_id=$(echo "$create_response" | jq -r '.data.id')
            
            if [ -z "$encryption_key_id" ]; then
                log_error "Failed to extract encryption key ID from creation response." \
                    "This is likely an issue with the OCI CLI response format."
                exit 1
            fi
            
            echo -e "${GREEN}New encryption key created. ID: $encryption_key_id${NC}"
            summary+=("Created new encryption key: $key_name ($encryption_key_id)")
            
            # Wait for key to become enabled
            echo -e "${YELLOW}Waiting for encryption key to become ENABLED...${NC}"
            local max_attempts=30
            local attempt=1
            
            while [ $attempt -le $max_attempts ]; do
                local oci_cmd="oci kms management key get --key-id \"$encryption_key_id\" --endpoint \"$management_endpoint\" --profile \"$profile\" $auth_param 2>/dev/null"
                log_verbose "Executing: $oci_cmd (attempt $attempt/$max_attempts)"
                
                if key_json=$(eval "$oci_cmd"); then
                    key_status=$(echo "$key_json" | jq -r '.data."lifecycle-state"')
                    
                    if [ "$key_status" = "ENABLED" ]; then
                        echo -e "${GREEN}Encryption key is now ENABLED.${NC}"
                        break
                    else
                        echo -e "${YELLOW}Encryption key status: $key_status. Waiting...${NC}"
                    fi
                else
                    echo -e "${YELLOW}Failed to get encryption key status. Retrying...${NC}"
                fi
                
                attempt=$((attempt+1))
                sleep 10
            done
            
            if [ "$key_status" != "ENABLED" ]; then
                log_error "Encryption key did not become ENABLED in the expected time." \
                    "You might need to check the key status in the OCI Console or try again later."
                exit 1
            fi
        fi
    fi
}

# Function to process secrets
process_secrets() {
    local created_count=0
    local updated_count=0
    local skipped_count=0
    local error_count=0
    local auth_param=$(add_auth_param)
    
    # The vault endpoints are different from the management endpoint, so we don't need to reuse it here
    
    echo -e "${BLUE}Processing secrets...${NC}"
    
    # Process each secret
    for ((i=0; i<secret_count; i++)); do
        local secret_name=""
        local secret_description=""
        local secret_content=""
        local content_type=""
        
        if [ "${secrets_file##*.}" = "json" ]; then
            secret_name=$(jq -r ".secrets[$i].name" "$secrets_file")
            secret_description=$(jq -r ".secrets[$i].description" "$secrets_file")
            secret_content=$(jq -r ".secrets[$i].content" "$secrets_file")
            content_type=$(jq -r ".secrets[$i].content_type" "$secrets_file")
        else
            secret_name=$(yq e ".secrets[$i].name" "$secrets_file")
            secret_description=$(yq e ".secrets[$i].description" "$secrets_file")
            secret_content=$(yq e ".secrets[$i].content" "$secrets_file")
            content_type=$(yq e ".secrets[$i].content_type" "$secrets_file")
            
            # Check for null values
            if [ "$secret_name" = "null" ]; then secret_name=""; fi
            if [ "$secret_description" = "null" ]; then secret_description=""; fi
            if [ "$secret_content" = "null" ]; then secret_content=""; fi
            if [ "$content_type" = "null" ]; then content_type=""; fi
        fi
        
        # Validate secret data
        if [ -z "$secret_name" ]; then
            log_error "Secret name is required (index $i). Skipping this secret." \
                "Make sure all secrets have a 'name' field."
            error_count=$((error_count+1))
            continue
        fi
        
        if [ -z "$secret_content" ]; then
            log_error "Secret content is required for '$secret_name'. Skipping this secret." \
                "Make sure all secrets have a 'content' field."
            error_count=$((error_count+1))
            continue
        fi
        
        if [ -z "$content_type" ]; then
            log_error "Content type is required for '$secret_name'. Defaulting to BASE64." \
                "Make sure all secrets have a 'content_type' field (BASE64 or TEXT)."
            content_type="BASE64"
        fi
        
        # Process content based on content_type
        local encoded_content=""
        if [ "$content_type" = "TEXT" ]; then
            encoded_content=$(echo -n "$secret_content" | base64)
            echo -e "${BLUE}Secret '$secret_name': TEXT content has been base64-encoded.${NC}"
        elif [ "$content_type" = "BASE64" ]; then
            encoded_content="$secret_content"
            echo -e "${BLUE}Secret '$secret_name': Content is already in BASE64 format.${NC}"
        else
            log_error "Invalid content_type for '$secret_name': $content_type. Skipping this secret." \
                "Valid values are 'BASE64' or 'TEXT'."
            error_count=$((error_count+1))
            continue
        fi
        
        echo -e "${BLUE}Processing secret: $secret_name${NC}"
        
        # Check if secret exists - use the 'vault secret list' command
        local oci_cmd="oci vault secret list --compartment-id \"$compartment_id\" --profile \"$profile\" $auth_param --all 2>/dev/null"
        log_verbose "Executing: $oci_cmd"
        
        if ! secrets_json=$(eval "$oci_cmd"); then
            log_error "Failed to list secrets in compartment." \
                "Check your permissions and network connectivity."
            error_count=$((error_count+1))
            continue
        fi
        
        local existing_secret_id=$(echo "$secrets_json" | jq -r --arg name "$secret_name" '.data[] | select(."secret-name" == $name) | .id' 2>/dev/null)
        
        if [ -n "$existing_secret_id" ]; then
            echo -e "${YELLOW}Secret '$secret_name' already exists. ID: $existing_secret_id${NC}"
            
            # Get current secret metadata
            local oci_cmd="oci vault secret get --secret-id \"$existing_secret_id\" --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! secret_json=$(eval "$oci_cmd"); then
                log_error "Failed to retrieve existing secret details for '$secret_name'." \
                    "This might be a temporary issue. Try again later."
                error_count=$((error_count+1))
                continue
            fi
            
            local current_version=$(echo "$secret_json" | jq -r '.data."current-version-number"')
            
            # Get current content
            local oci_cmd="oci secrets secret-bundle get --secret-id \"$existing_secret_id\" --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $oci_cmd"
            
            if ! secret_bundle=$(eval "$oci_cmd"); then
                log_error "Failed to retrieve secret content for '$secret_name'." \
                    "Check your permissions or if the secret is in a valid state."
                error_count=$((error_count+1))
                continue
            fi
            
            # Debug the structure of the secret bundle
            if [ $verbose_mode -eq 1 ]; then
                echo -e "${BLUE}[DEBUG] Secret bundle structure:${NC}"
                echo "$secret_bundle" | jq '.'
            fi
            
            # The path to content may differ depending on OCI CLI version - try different paths
            local current_content=$(echo "$secret_bundle" | jq -r '.data."secret-bundle-content".content // .data.content // empty')
            
            # Check if we could extract the content
            if [ -z "$current_content" ]; then
                echo -e "${YELLOW}Warning: Could not extract current content for comparison.${NC}"
                echo -e "${YELLOW}New content (masked): ${encoded_content:0:3}...${encoded_content: -3}${NC}"
            else
                # Compare current and new content
                echo -e "${YELLOW}Current content (masked): ${current_content:0:3}...${current_content: -3}${NC}"
                echo -e "${YELLOW}New content (masked): ${encoded_content:0:3}...${encoded_content: -3}${NC}"
            fi
            
            # Prompt for confirmation before updating
            echo -n -e "${YELLOW}Do you want to update this secret? [y/N]: ${NC}"
            read -r update_confirmation
            
            if [[ "$update_confirmation" =~ ^[Yy]$ ]]; then
                # Update secret
                echo -e "${BLUE}Updating secret '$secret_name'...${NC}"
                
                local oci_cmd="oci vault secret update-base64 --secret-id \"$existing_secret_id\" --secret-content-content \"$encoded_content\" --profile \"$profile\" $auth_param 2>/dev/null"
                log_verbose "Executing secret update command..."
                
                if ! update_response=$(eval "$oci_cmd"); then
                    log_error "Failed to update secret '$secret_name'." \
                        "Check your permissions and if the secret is in a valid state."
                    error_count=$((error_count+1))
                    continue
                fi
                
                echo -e "${GREEN}Secret '$secret_name' updated successfully.${NC}"
                updated_count=$((updated_count+1))
                summary+=("Updated secret: $secret_name")
            else
                echo -e "${BLUE}Skipping update for secret '$secret_name'.${NC}"
                skipped_count=$((skipped_count+1))
                summary+=("Skipped secret: $secret_name")
            fi
        else
            # Create new secret
            echo -e "${BLUE}Creating new secret '$secret_name'...${NC}"
            
            local create_cmd="oci vault secret create-base64 --compartment-id \"$compartment_id\" --secret-name \"$secret_name\" --vault-id \"$vault_id\" --key-id \"$encryption_key_id\" --secret-content-content \"$encoded_content\""
            
            if [ -n "$secret_description" ]; then
                create_cmd+=" --description \"$secret_description\""
            fi
            
            create_cmd+=" --profile \"$profile\" $auth_param 2>/dev/null"
            log_verbose "Executing: $create_cmd"
            
            if ! create_response=$(eval "$create_cmd"); then
                log_error "Failed to create secret '$secret_name'." \
                    "Check your permissions and if you have reached the secrets limit for your compartment."
                error_count=$((error_count+1))
                continue
            fi
            
            local new_secret_id=$(echo "$create_response" | jq -r '.data.id')
            
            if [ -z "$new_secret_id" ]; then
                log_error "Failed to extract secret ID from creation response for '$secret_name'." \
                    "This is likely an issue with the OCI CLI response format."
                error_count=$((error_count+1))
                continue
            fi
            
            echo -e "${GREEN}Secret '$secret_name' created successfully. ID: $new_secret_id${NC}"
            created_count=$((created_count+1))
            summary+=("Created secret: $secret_name")
        fi
    done
    
    # Display summary of secret processing
    echo -e "${BLUE}Secret processing completed.${NC}"
    echo -e "${GREEN}Created: $created_count${NC}"
    echo -e "${YELLOW}Updated: $updated_count${NC}"
    echo -e "${BLUE}Skipped: $skipped_count${NC}"
    
    if [ $error_count -gt 0 ]; then
        echo -e "${RED}Errors: $error_count${NC}"
    fi
}

# Function to display execution summary
display_summary() {
    echo -e "\n${BLUE}=== Execution Summary ===${NC}"
    
    if [ ${#summary[@]} -eq 0 ]; then
        echo -e "${YELLOW}No changes were made.${NC}"
    else
        for item in "${summary[@]}"; do
            echo -e "- $item"
        done
    fi
    
    echo -e "\n${GREEN}Script execution completed.${NC}"
}

# Parse command line arguments
while getopts ":f:p:a:vh" opt; do
    case $opt in
        f)
            secrets_file="$OPTARG"
            ;;
        p)
            profile="$OPTARG"
            ;;
        a)
            auth_type="$OPTARG"
            ;;
        v)
            verbose_mode=1
            ;;
        h)
            usage
            ;;
        \?)
            echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
            usage
            ;;
        :)
            echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
            usage
            ;;
    esac
done

# Main execution flow
check_dependencies
parse_input_file
check_oci_session
get_or_create_vault
get_or_create_key
process_secrets
display_summary

exit 0