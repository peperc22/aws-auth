#!/bin/bash

# Improved AWS MFA credential script
# Usage: source ./auth.sh [iam-username] token-code
# If iam-username is omitted, script will attempt to get current AWS user
# 
# IMPORTANT: You MUST source this script to set environment variables in your current shell
# Example: source ./auth.sh JoseReyes 023351

main() {
    usage() {
        echo "Usage: source $0 [iam-username] token-code"
        echo "  iam-username: IAM username (optional). If omitted, uses current AWS user"
        echo "  token-code:   MFA token code (required)"
        echo "Example:"
        echo "  source $0 josereyes-mfa-2026 060960"
        echo "  source $0 060960          # Uses current AWS user to find MFA device"
        return 1
    }

    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        usage
        return 1
    fi

    TOKEN_CODE="${@: -1}"

    if [ $# -eq 2 ]; then
        IAM_USERNAME="$1"
    else
        echo "Getting current AWS user..."
        CURRENT_USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$CURRENT_USER_ARN" ]; then
            echo "Error: Unable to get current AWS user. Please ensure AWS credentials are configured."
            echo "You can either:"
            echo "  1. Provide IAM username as first argument: $0 <iam-username> <token-code>"
            echo "  2. Configure AWS credentials with 'aws configure'"
            return 1
        fi
        
        IAM_USERNAME=$(echo "$CURRENT_USER_ARN" | cut -d'/' -f2)
        if [ -z "$IAM_USERNAME" ]; then
            echo "Error: Could not extract username from ARN: $CURRENT_USER_ARN"
            return 1
        fi
        echo "Using current AWS user: $IAM_USERNAME"
    fi

    echo "Finding MFA device for user: $IAM_USERNAME"
    MFA_DEVICE_INFO=$(aws iam list-mfa-devices --user-name "$IAM_USERNAME" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to list MFA devices for user '$IAM_USERNAME'"
        echo "Please check:"
        echo "  1. The IAM username is correct"
        echo "  2. Your AWS credentials have permission to list MFA devices"
        echo "  3. The user has an MFA device configured"
        return 1
    fi

    SERIAL_NUMBER=$(echo "$MFA_DEVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['MFADevices'][0]['SerialNumber'] if data['MFADevices'] else '')" 2>/dev/null)
    if [ -z "$SERIAL_NUMBER" ]; then
        echo "Error: No MFA device found for user '$IAM_USERNAME'"
        return 1
    fi

    echo "Using MFA device: $SERIAL_NUMBER"

    echo "Getting session token..."
    OUTPUT=$(env -u AWS_SESSION_TOKEN -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY aws sts get-session-token --serial-number "$SERIAL_NUMBER" --token-code "$TOKEN_CODE" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get session token from AWS STS"
        echo "AWS error: $OUTPUT"
        echo "Please check:"
        echo "  1. The token code is correct"
        echo "  2. The MFA device is associated with the user"
        return 1
    fi

    AWS_ACCESS_KEY_ID=$(echo "$OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])" 2>/dev/null)
    AWS_SECRET_ACCESS_KEY=$(echo "$OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])" 2>/dev/null)
    AWS_SESSION_TOKEN=$(echo "$OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['SessionToken'])" 2>/dev/null)

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
        echo "Error: Failed to extract credentials from AWS response"
        return 1
    fi

    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
    export AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"

    echo "AWS credentials have been set for the current shell session."
    echo "Access Key ID: $AWS_ACCESS_KEY_ID"
    echo "Session Token expires at: $(echo "$OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Credentials']['Expiration'])" 2>/dev/null)"
}

main "$@"