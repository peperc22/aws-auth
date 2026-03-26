# AWS MFA Authentication Script

Generate temporary AWS credentials using your MFA device.

## Usage

```bash
source ./auth.sh [iam-username] token-code
```

## Examples

```bash
source ./auth.sh YOUR_AWS_USERNAME YOUR_MFA_CODE
source ./auth.sh YOUR_MFA_CODE          # Auto-detect current AWS user
```

## Execute Directly from GitHub

```bash
eval "$(curl -sL https://raw.githubusercontent.com/dened-mira/aws-auth/main/auth.sh)"
```

With arguments:

```bash
eval "$(curl -sL https://raw.githubusercontent.com/dened-mira/aws-auth/main/auth.sh)" YOUR_AWS_USERNAME YOUR_MFA_CODE
```

Or:

```bash
source <(curl -sL https://raw.githubusercontent.com/{user}/{repo}/main/auth.sh)
source <(curl -sL https://raw.githubusercontent.com/{user}/{repo}/main/auth.sh) YOUR_AWS_USERNAME YOUR_MFA_CODE
```

## Security Note

Always verify scripts before sourcing from the internet. Only use this method with repos you trust.
