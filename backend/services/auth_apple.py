from datetime import datetime, timezone
from typing import Dict
import requests
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, jwk
from jose.utils import base64url_decode

from core.config import settings

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

security = HTTPBearer()

class AppleTokenError(HTTPException):
    def __init__(self, detail: str = "Invalid Apple ID token"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


def verify_apple_token(id_token: str, audience: str | None = None) -> Dict:
    """Verify an Apple Sign In id_token and return the claims.
    - Validates signature using Apple's JWKS
    - Validates iss, aud (if provided), and exp
    """

    import logging
    logger = logging.getLogger("uvicorn.error")

    try:
        headers = jwt.get_unverified_header(id_token)
    except Exception:
        logger.error("Malformed id_token header for Apple token")
        raise AppleTokenError("Malformed id_token header")

    # Apple tokens must be RS256 and have a kid
    if headers.get("alg") != "RS256":
        logger.error(f"Apple id_token has invalid alg: {headers.get('alg')}. Expected RS256.")
        raise AppleTokenError("Apple id_token must be signed with RS256 (not a mock or test token)")
    if not headers.get("kid"):
        logger.error("Apple id_token missing 'kid' in header. This is not a real Apple token.")
        raise AppleTokenError("Apple id_token missing 'kid' in header. This is not a real Apple token.")

    # Fetch Apple's JWKS and find matching key
    try:
        jwks = requests.get(APPLE_JWKS_URL, timeout=5).json()
        all_kids = [k.get("kid") for k in jwks.get("keys", [])]
        logger.debug(f"Apple token kid: {headers.get('kid')}, JWKS kids: {all_kids}")
        key = next((k for k in jwks.get("keys", []) if k.get("kid") == headers.get("kid")), None)
        if not key:
            logger.error(f"No matching Apple public key for kid {headers.get('kid')}. JWKS kids: {all_kids}")
            raise AppleTokenError(f"No matching Apple public key for kid {headers.get('kid')}")
    except AppleTokenError:
        raise
    except Exception as e:
        logger.error(f"Failed to fetch Apple public keys: {e}")
        raise AppleTokenError("Failed to fetch Apple public keys")

    # Verify signature manually
    try:
        public_key = jwk.construct(key, algorithm=headers.get("alg"))
        message, encoded_sig = id_token.rsplit(".", 1)
        decoded_sig = base64url_decode(encoded_sig.encode("utf-8"))
        if not public_key.verify(message.encode("utf-8"), decoded_sig):
            raise AppleTokenError("Invalid Apple token signature")

        claims = jwt.get_unverified_claims(id_token)
    except AppleTokenError:
        raise
    except Exception:
        raise AppleTokenError("Failed to verify Apple token signature")

    # Validate iss, exp, aud
    if claims.get("iss") != APPLE_ISSUER:
        raise AppleTokenError("Invalid issuer")

    if audience:
        aud = claims.get("aud")
        # aud can be a string or list
        if (isinstance(aud, str) and aud != audience) or (
            isinstance(aud, list) and audience not in aud
        ):
            raise AppleTokenError("Invalid audience")

    exp = claims.get("exp")
    if not exp or datetime.now(timezone.utc).timestamp() > float(exp):
        raise AppleTokenError("Token expired")

    return claims


async def get_current_identity(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """FastAPI dependency that validates Apple id_token in Authorization: Bearer <id_token>.
    Returns basic identity dict: {"sub", "email" (if present)}
    """
    id_token = credentials.credentials
    audience = settings.APPLE_CLIENT_ID or None
    claims = verify_apple_token(id_token, audience=audience)
    return {
        "sub": claims.get("sub"),
        "email": claims.get("email"),
        "email_verified": claims.get("email_verified"),
        "claims": claims,
    }
