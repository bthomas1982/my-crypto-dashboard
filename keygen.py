#!/usr/bin/env python3
"""Generate the agent's Ed25519 identity key and derive its did:key.

Writes the 32-byte private seed to key.json with mode 0600.
Refuses to clobber an existing key unless --force is given.
"""

import argparse
import json
import os
import stat
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

KEY_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "key.json")

# multicodec prefix for an ed25519 public key
MULTICODEC_ED25519_PUB = b"\xed\x01"

B58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58encode(data: bytes) -> str:
    """base58btc (Bitcoin alphabet), with leading zero bytes mapped to '1'."""
    n = int.from_bytes(data, "big")
    out = ""
    while n > 0:
        n, rem = divmod(n, 58)
        out = B58_ALPHABET[rem] + out
    # each leading 0x00 byte encodes as a literal '1'
    for byte in data:
        if byte != 0:
            break
        out = "1" + out
    return out


def did_key_from_public(pub_raw: bytes) -> str:
    """did:key for a raw 32-byte Ed25519 public key."""
    if len(pub_raw) != 32:
        raise ValueError(f"expected a 32-byte public key, got {len(pub_raw)}")
    return "did:key:z" + b58encode(MULTICODEC_ED25519_PUB + pub_raw)


def public_raw(priv: Ed25519PrivateKey) -> bytes:
    return priv.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )


def private_seed(priv: Ed25519PrivateKey) -> bytes:
    """The 32-byte seed. For Ed25519 the seed *is* the private key."""
    return priv.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption(),
    )


def load_key(path: str = KEY_PATH) -> Ed25519PrivateKey:
    """Load the identity key, warning if it is readable by anyone else."""
    with open(path, "r", encoding="utf-8") as fh:
        doc = json.load(fh)
    mode = stat.S_IMODE(os.stat(path).st_mode)
    if mode & 0o077:
        print(
            f"warning: {path} is mode {mode:04o}; expected 0600. "
            "Run: chmod 600 " + path,
            file=sys.stderr,
        )
    seed = bytes.fromhex(doc["seed_hex"])
    if len(seed) != 32:
        raise ValueError("key.json seed is not 32 bytes")
    return Ed25519PrivateKey.from_private_bytes(seed)


def write_key(path: str, priv: Ed25519PrivateKey, did: str, force: bool) -> None:
    doc = {
        "version": 1,
        "type": "Ed25519VerificationKey2020",
        "did": did,
        "public_key_hex": public_raw(priv).hex(),
        "seed_hex": private_seed(priv).hex(),
    }
    body = json.dumps(doc, indent=2) + "\n"

    # Create at 0600 from the outset -- never a window where the seed sits
    # on disk world-readable. O_EXCL unless the caller insisted on --force.
    flags = os.O_WRONLY | os.O_CREAT | (os.O_TRUNC if force else os.O_EXCL)
    fd = os.open(path, flags, 0o600)
    try:
        os.write(fd, body.encode("utf-8"))
    finally:
        os.close(fd)
    os.chmod(path, 0o600)  # force-overwrite of a pre-existing file keeps old mode


def main() -> int:
    ap = argparse.ArgumentParser(description="generate the agent's Ed25519 identity")
    ap.add_argument("--out", default=KEY_PATH, help="key file path (default: ./key.json)")
    ap.add_argument(
        "--force",
        action="store_true",
        help="overwrite an existing key file (destroys that identity permanently)",
    )
    args = ap.parse_args()

    if os.path.exists(args.out) and not args.force:
        existing = json.load(open(args.out, "r", encoding="utf-8"))
        print(f"{args.out} already exists; identity is {existing.get('did')}", file=sys.stderr)
        print("Refusing to overwrite. Pass --force if you really mean to.", file=sys.stderr)
        return 1

    priv = Ed25519PrivateKey.generate()
    did = did_key_from_public(public_raw(priv))

    assert did.startswith("did:key:z6Mk"), f"unexpected did:key form: {did}"

    write_key(args.out, priv, did, args.force)

    print(did)
    print(f"seed written to {args.out} (mode 0600)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
