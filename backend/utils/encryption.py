from cryptography.fernet import Fernet
import base64
from core.config import settings

def get_encryption_key() -> bytes:
    """Get or generate encryption key from settings"""
    # In production, this should be stored securely
    key = base64.urlsafe_b64encode(settings.SECRET_KEY.encode()[:32].ljust(32, b'0'))
    return key

def encrypt_password(password: str) -> str:
    """Encrypt a password for storage"""
    key = get_encryption_key()
    fernet = Fernet(key)
    encrypted_password = fernet.encrypt(password.encode())
    return base64.urlsafe_b64encode(encrypted_password).decode()

def decrypt_password(encrypted_password: str) -> str:
    """Decrypt a stored password"""
    key = get_encryption_key()
    fernet = Fernet(key)
    encrypted_bytes = base64.urlsafe_b64decode(encrypted_password.encode())
    decrypted_password = fernet.decrypt(encrypted_bytes)
    return decrypted_password.decode()
