# Task — add-provider-tpm-function

**Model:** sonnet · **Effort:** low · **Tokens estimated:** 8000 · **Attempts:** 0/3
**Run:** aymm
**Allowed files:** provider-config.sh

## Steps

- [x] Add a `provider_tpm()` function to provider-config.sh immediately after the closing `}` of the existing `provider_api_format()` function (which ends around line 68). The function takes a provider alias as $1 and returns its Tokens Per Minute limit as a plain integer. Use this exact implementation:
  ```bash
  provider_tpm() {
      case "$1" in
          groq_8b)        echo 6000 ;;
          groq_scout)     echo 30000 ;;
          groq_qwen3)     echo 6000 ;;
          groq_20b)       echo 8000 ;;
          groq_70b)       echo 12000 ;;
          groq_120b)      echo 8000 ;;
          groq_compound)  echo 70000 ;;
          *)              echo 6000 ;;
      esac
  }
  ```
  Done when: provider_tpm() exists in provider-config.sh and the file passes bash -n. -- test: bash -n provider-config.sh && grep -q 'provider_tpm()' provider-config.sh -- files: provider-config.sh:62-80 -- mode: aymm

## Smoke test
`source provider-config.sh && provider_tpm groq_scout` should print `30000`.
`source provider-config.sh && provider_tpm groq_70b` should print `12000`.
