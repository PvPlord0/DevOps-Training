# RSA Keys for JWT Authentication

Asymmetric key pair used for RS256 JWT signing and verification.

## Files

| File | Purpose | Location |
|------|---------|----------|
| `private.pem` | Signs JWTs | Auth service only (`JWT_PRIVATE_KEY_PATH` env var) |
| `public.pem` | Verifies JWTs | API Gateway (`JWT_PUBLIC_KEY_PATH` env var) |

## Regenerate Keys

```bash
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
```

## Security

- The private key never leaves the auth service
- The public key is shared with the gateway for verification
- Do not commit real keys to version control in production
