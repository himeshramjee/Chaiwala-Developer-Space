#!/bin/bash

# Script to list OCI metrics for specified namespaces within a compartment
# Usage: ./list_oci_metrics.sh -c COMPARTMENT_ID -n "namespace1,namespace2,..."

set -e

# Default values
COMPARTMENT_ID=""
NAMESPACES=""
OUTPUT_FORMAT="table"

# Function to display usage information
usage() {
  echo "Usage: $0 -c COMPARTMENT_ID -n NAMESPACES [-o OUTPUT_FORMAT] [-h]"
  echo ""
  echo "Options:"
  echo "  -c COMPARTMENT_ID   The OCID of the compartment to search in (required)"
  echo "  -n NAMESPACES       Comma-separated list of namespaces to filter (required)"
  echo "                      Example: \"oci_computeagent,oci_blockstore\""
  echo "  -o OUTPUT_FORMAT    Output format: table (default), json, or csv"
  echo "  -h                  Display this help message"
  exit 1
}

# Parse command line options
while getopts "c:n:o:h" opt; do
  case ${opt} in
    c)
      COMPARTMENT_ID=$OPTARG
      ;;
    n)
      NAMESPACES=$OPTARG
      ;;
    o)
      OUTPUT_FORMAT=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      ;;
  esac
done

# Validate required parameters
if [ -z "$COMPARTMENT_ID" ] || [ -z "$NAMESPACES" ]; then
  echo "Error: Compartment ID and Namespaces are required parameters."
  usage
fi

# Validate OCI CLI is installed
if ! command -v oci &> /dev/null; then
  echo "Error: OCI CLI is not installed. Please install it first."
  echo "Visit https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm for installation instructions."
  exit 1
fi

echo "Checking OCI CLI configuration..."
if ! oci iam compartment get --compartment-id "$COMPARTMENT_ID" &> /dev/null; then
  echo "Error: Unable to access compartment. Please check:"
  echo "  1. Your OCI CLI is properly configured"
  echo "  2. The compartment ID is valid"
  echo "  3. You have permissions to access this compartment"
  exit 1
fi

echo "===================================================="
echo "Retrieving metrics for the following configuration:"
echo "Compartment ID: $COMPARTMENT_ID"
echo "Namespaces: $NAMESPACES"
echo "Output format: $OUTPUT_FORMAT"
echo "===================================================="

# Convert comma-separated namespaces to array
IFS=',' read -ra NAMESPACE_ARRAY <<< "$NAMESPACES"

# Set up output based on format
case "$OUTPUT_FORMAT" in
  json)
    # For JSON, we'll collect all results in an array
    echo "["
    ;;
  csv)
    # For CSV, print the header
    echo "Namespace,Metric Name,Dimensions,Resource Group"
    ;;
  *)
    # Default to table format
    printf "%-25s %-30s %-30s %-20s\n" "NAMESPACE" "METRIC NAME" "DIMENSIONS" "RESOURCE GROUP"
    printf "%-25s %-30s %-30s %-20s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..20})"
    ;;
esac

# Track if this is the first result for JSON output
first_result=true

# Loop through each namespace
for namespace in "${NAMESPACE_ARRAY[@]}"; do
  # Remove any whitespace
  namespace=$(echo "$namespace" | xargs)
  
  echo "Processing namespace: $namespace..." >&2
  
  # Get list of metrics for the namespace
  metrics_output=$(oci monitoring metric-data summarize-metrics-data \
    --compartment-id "$COMPARTMENT_ID" \
    --namespace "$namespace" \
    --query-text "" \
    --all 2>/dev/null || echo '{"items": []}')
  
  # Extract unique metric names, dimensions, and resource groups
  metrics=$(echo "$metrics_output" | jq -r '.data.items[] | {metricName, dimensions, resourceGroup} | @base64')
  
  if [ -z "$metrics" ]; then
    echo "No metrics found for namespace: $namespace" >&2
    continue
  fi
  
  # Process each metric
  for metric in $metrics; do
    metric_data=$(echo "$metric" | base64 -d)
    metric_name=$(echo "$metric_data" | jq -r '.metricName')
    dimensions=$(echo "$metric_data" | jq -r '.dimensions | to_entries | map(.key + "=" + .value) | join(", ")')
    resource_group=$(echo "$metric_data" | jq -r '.resourceGroup // "null"')
    
    case "$OUTPUT_FORMAT" in
      json)
        if [ "$first_result" = true ]; then
          first_result=false
        else
          echo ","
        fi
        echo "  {\"namespace\": \"$namespace\", \"metricName\": \"$metric_name\", \"dimensions\": \"$dimensions\", \"resourceGroup\": \"$resource_group\"}"
        ;;
      csv)
        echo "\"$namespace\",\"$metric_name\",\"$dimensions\",\"$resource_group\""
        ;;
      *)
        # Table format
        # Truncate long strings for better display
        if [ ${#metric_name} -gt 28 ]; then
          metric_name="${metric_name:0:25}..."
        fi
        if [ ${#dimensions} -gt 28 ]; then
          dimensions="${dimensions:0:25}..."
        fi
        if [ ${#resource_group} -gt 18 ]; then
          resource_group="${resource_group:0:15}..."
        fi
        printf "%-25s %-30s %-30s %-20s\n" "$namespace" "$metric_name" "$dimensions" "$resource_group"
        ;;
    esac
  done
done

# Close JSON array if needed
if [ "$OUTPUT_FORMAT" = "json" ]; then
  echo -e "\n]"
fi

echo -e "\nMetrics retrieval completed." >&2