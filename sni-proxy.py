#!/usr/bin/env python3
"""SNI-based TLS passthrough proxy for Azure Private Endpoints.
Routes VPN client traffic to PE IPs based on TLS SNI hostname.
No TLS termination - just reads SNI and forwards the raw TCP stream."""

import socket
import struct
import threading
import sys
import os
import signal

LISTEN_PORT = 443
BACKEND_MAP = {
    "foundrype4cey.cognitiveservices.azure.com": "10.200.3.12",
    "foundrype4cey.openai.azure.com": "10.200.3.13",
    "foundrype4cey.services.ai.azure.com": "10.200.3.14",
    "foundrypesqxkstorage.blob.core.windows.net": "10.200.3.10",
    "foundrypesqxkcosmosdb.documents.azure.com": "10.200.3.4",
}
DEFAULT_BACKEND = "10.200.3.12"

def extract_sni(data):
    """Extract SNI hostname from TLS ClientHello."""
    try:
        if data[0] != 0x16:  # Not a TLS handshake
            return None
        # TLS record: type(1) + version(2) + length(2) + handshake
        # Handshake: type(1) + length(3) + client_version(2) + random(32) + session_id(var) + ...
        pos = 5  # skip TLS record header
        if data[pos] != 0x01:  # Not ClientHello
            return None
        pos += 4  # skip handshake type + length
        pos += 2  # skip client version
        pos += 32  # skip random
        session_id_len = data[pos]
        pos += 1 + session_id_len
        cipher_suites_len = struct.unpack("!H", data[pos:pos+2])[0]
        pos += 2 + cipher_suites_len
        compression_len = data[pos]
        pos += 1 + compression_len
        if pos >= len(data):
            return None
        extensions_len = struct.unpack("!H", data[pos:pos+2])[0]
        pos += 2
        end = pos + extensions_len
        while pos < end:
            ext_type = struct.unpack("!H", data[pos:pos+2])[0]
            ext_len = struct.unpack("!H", data[pos+2:pos+4])[0]
            if ext_type == 0x00:  # SNI extension
                sni_list_len = struct.unpack("!H", data[pos+4:pos+6])[0]
                sni_type = data[pos+6]
                sni_len = struct.unpack("!H", data[pos+7:pos+9])[0]
                return data[pos+9:pos+9+sni_len].decode("ascii")
            pos += 4 + ext_len
    except (IndexError, struct.error):
        pass
    return None

def pipe(src, dst):
    """Copy data between sockets."""
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except (OSError, ConnectionError):
        pass
    finally:
        try: src.shutdown(socket.SHUT_RD)
        except: pass
        try: dst.shutdown(socket.SHUT_WR)
        except: pass

def handle_client(client_sock, addr):
    """Handle a single client connection."""
    try:
        # Read ClientHello to get SNI
        client_sock.settimeout(10)
        data = client_sock.recv(16384)
        if not data:
            client_sock.close()
            return

        sni = extract_sni(data)
        backend_ip = BACKEND_MAP.get(sni, DEFAULT_BACKEND)
        print(f"[{addr[0]}:{addr[1]}] SNI={sni} -> {backend_ip}:443", flush=True)

        # Connect to backend PE
        backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        backend.settimeout(10)
        backend.connect((backend_ip, 443))
        backend.settimeout(300)
        client_sock.settimeout(300)

        # Forward the initial ClientHello
        backend.sendall(data)

        # Bidirectional pipe
        t1 = threading.Thread(target=pipe, args=(client_sock, backend), daemon=True)
        t2 = threading.Thread(target=pipe, args=(backend, client_sock), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        print(f"[{addr[0]}:{addr[1]}] Error: {e}", flush=True)
    finally:
        try: client_sock.close()
        except: pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", LISTEN_PORT))
    server.listen(64)
    print(f"SNI proxy listening on 0.0.0.0:{LISTEN_PORT}", flush=True)
    print(f"Backend map: {BACKEND_MAP}", flush=True)

    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))

    while True:
        client_sock, addr = server.accept()
        threading.Thread(target=handle_client, args=(client_sock, addr), daemon=True).start()

if __name__ == "__main__":
    main()
