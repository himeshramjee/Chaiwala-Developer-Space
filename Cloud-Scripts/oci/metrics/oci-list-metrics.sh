#!/bin/bash

# Script to list OCI metrics for specified namespaces within a compartment
# Usage: ./list_oci_metrics.sh -c COMPARTMENT_ID -n "namespace1,namespace2,..."

set -e

# Default values
COMPARTMENT_ID=""
NAMESPACES=""
METRICS_PREFIXES="health,service"
OCI_PROFILE=""
OCI_PROFILE_AUTH=""
OUTPUT_FORMAT="tsv"

# Function to display usage information
usage() {
  echo "Usage: $0 -c COMPARTMENT_ID -n NAMESPACES [-o OUTPUT_FORMAT] [-h]"
  echo ""
  echo "Options:"
  echo "  -c COMPARTMENT_ID   The OCID of the compartment to search in (required)"
  echo "  -n NAMESPACES       Comma-separated list of namespaces to filter (required)"
  echo "                      Example: \"oci_computeagent,oci_blockstore\""
  echo "  -o OUTPUT_FORMAT    Output format: tsv (default), csv"
  echo "  -h                  Display this help message"
  exit 1
}

# Parse command line options
while getopts "c:n:o:h" opt; do
  case "$opt" in
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

echo "===================================================="
echo "Retrieving metrics for the following configuration:"
echo "Compartment ID: $COMPARTMENT_ID"
echo "Namespaces: $NAMESPACES"
echo "Metrics Name Prefixes: $METRICS_PREFIXES"
echo "Output format: $OUTPUT_FORMAT"
echo "===================================================="

# Convert comma-separated namespaces to array
IFS=',' read -ra NAMESPACE_ARRAY <<< "$NAMESPACES"
if [ -n "$METRICS_PREFIXES" ]; then
  IFS=',' read -ra PREFIX_ARRAY <<< "$METRICS_PREFIXES"
fi

# Track if this is the first result for JSON output
first_result=true

# Loop through each namespace
for namespace in "${NAMESPACE_ARRAY[@]}"; do
  # Remove any whitespace
  namespace=$(echo "$namespace" | xargs)
  
  echo "Processing namespace: $namespace..." >&2

  # Get list of metrics for the namespace
  metrics_list=$(oci monitoring metric list \
      --compartment-id "$COMPARTMENT_ID" \
      --namespace "$namespace" \
      --all \
      --profile "$OCI_PROFILE" \
      --auth "$OCI_PROFILE_AUTH" \
      --output json 2>/dev/null || echo '{"data": []}')
  
  # Extract unique metric names, dimensions, and resource groups
  metrics=$(echo "$metrics_output" | jq -r '.data.items[] | {metricName, dimensions, resourceGroup} | @base64')
  cat oci-list-metrics-cache-result.json | jq -r '.data[] | [.name, .dimensions.application] | @tsv' | column -t -s $'\t'
  
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
  echo "Filter: $filter_expr"

  output_fields=".name, .dimensions.application, .dimensions.name, .dimensions.status, .dimensions.version"

  case "$OUTPUT_FORMAT" in
    csv)
      # CSV
      echo "Metric Name,Application,Dimension,Status,Version"
      if [[ $prefix_count -eq 0 ]]; then
        echo $metrics_list | jq -r ".data[] | [$output_fields] | @$OUTPUT_FORMAT"
      else 
        echo $metrics_list | jq -r ".data[] | select($filter_expr) | [$output_fields] | @$OUTPUT_FORMAT"
        # echo $metrics_list | jq -r ".data[] | select(.name | test('^health|^service')) | [$output_fields] | @$OUTPUT_FORMAT"
        # cat oci-list-metrics-raw-output.json | jq -r ".data[] | select((.name | startswith(\"health\")) and .dimensions.application == \"abc-service-api\" and .dimensions.name == \"ValueSetClientHealthCheck\") | [.name, .dimensions.application, .dimensions.name, .dimensions.version, .dimensions.status] | @csv"
      fi
      ;;
    *)
      # Default to table Version
      echo -e "Metric name\tApp-lication\tDimension\tStatus\tVersion" | column -t -s $'\t'
      echo -e "-----------\t------------\t---------\t------\t-------" | column -t -s $'\t'
      if [[ $prefix_count -eq 0 ]]; then
        echo $metrics_list | jq -r ".data[] | [$output_fields] | @$OUTPUT_FORMAT" | column -t -s $'\t'
      else 
        echo $metrics_list | jq -r ".data[] | select($filter_expr) | [$output_fields] | @$OUTPUT_FORMAT" | column -t -s $'\t'
      fi
      ;;
  esac
  
done

echo -e "\nMetrics retrieval completed." >&2
