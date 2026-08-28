#!/usr/bin/env python3
"""Technocore message signing: the single-line sweep, the nonce clock, Ed25519.

The signed preimage is the UTF-8 encoding of

    <room>|<nonce>|<text>

where <text> is the text *after* the sweep. Sign what the server will
canonicalise, never the raw input -- otherwise the signature covers a string
nobody else can reproduce.
"""

import argparse
import base64
import json
import os
import sys
import threading
import time
import unicodedata

from keygen import KEY_PATH, load_key

HERE = os.path.dirname(os.path.abspath(__file__))
NONCE_PATH = os.path.join(HERE, "nonces.json")

# Unicode general categories erased by the single-line sweep:
#   Cc control, Cf format, Cs surrogate, Co private-use,
#   Zl line separator, Zp paragraph separator.
# Cn (unassigned) is deliberately NOT swept.
SWEEP_CATEGORIES = frozenset({"Cc", "Cf", "Cs", "Co", "Zl", "Zp"})

_nonce_lock = threading.Lock()


def sweep(text: str) -> str:
    """Technocore's single-line sweep: swept categories -> space, then trim.

    Newlines and tabs are Cc, so this is what flattens a message to one line.
    Surrogates are Cs, so a swept string is always UTF-8 encodable.
    """
    out = "".join(
        " " if unicodedata.category(ch) in SWEEP_CATEGORIES else ch for ch in text
    )
    return out.strip()


def preimage(room: str, nonce: int, text: str) -> bytes:
    """The exact bytes that get signed. text is swept here, once."""
    return f"{room}|{nonce}|{sweep(text)}".encode("utf-8")


def sign(room: str, nonce: int, text: str, priv=None) -> str:
    """Return the unpadded base64url Ed25519 signature over the preimage."""
    if priv is None:
        priv = load_key()
    raw = priv.sign(preimage(room, nonce, text))
    sig = base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")
    # 64 signature bytes -> 86 base64 chars once the two '=' pad chars are cut.
    assert len(sig) == 86, f"expected an 86-char signature, got {len(sig)}"
    return sig


# --- nonce clock -------------------------------------------------------------

def _read_nonces() -> dict:
    try:
        with open(NONCE_PATH, "r", encoding="utf-8") as fh:
            doc = json.load(fh)
        return doc if isinstance(doc, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def _write_json_atomic(path: str, doc: dict) -> None:
    tmp = f"{path}.tmp.{os.getpid()}"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.write(fd, (json.dumps(doc, indent=2) + "\n").encode("utf-8"))
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(tmp, path)


def next_nonce(room: str) -> int:
    """A strictly increasing millisecond nonce for this room.

    Wall-clock milliseconds, floored by the last nonce we persisted for the
    room. The floor is what makes it monotonic: it survives a restart, an NTP
    step backwards, and two sends inside the same millisecond. Persisted before
    it is returned, so a crash mid-send can never reissue a nonce.
    """
    with _nonce_lock:
        nonces = _read_nonces()
        last = nonces.get(room)
        last = last if isinstance(last, int) else 0
        nonce = max(time.time_ns() // 1_000_000, last + 1)
        nonces[room] = nonce
        _write_json_atomic(NONCE_PATH, nonces)
        return nonce


def last_nonce(room: str) -> int:
    n = _read_nonces().get(room)
    return n if isinstance(n, int) else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="sign a technocore message")
    ap.add_argument("room")
    ap.add_argument("text")
    ap.add_argument("--nonce", type=int, help="default: next nonce for the room")
    ap.add_argument("--key", default=KEY_PATH)
    args = ap.parse_args()

    nonce = args.nonce if args.nonce is not None else next_nonce(args.room)
    priv = load_key(args.key)
    sig = sign(args.room, nonce, args.text, priv)
    json.dump(
        {
            "room": args.room,
            "nonce": nonce,
            "text": sweep(args.text),
            "sig": sig,
        },
        sys.stdout,
        indent=2,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
