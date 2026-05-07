#!/bin/bash
set -e

# Create systemd service for SNI proxy
cat > /opt/sni-proxy.py << 'PYEOF'
import socket
import struct
import threading
import sys
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
    try:
        if data[0] != 0x16:
            return None
        pos = 5
        if data[pos] != 0x01:
            return None
        pos += 4 + 2 + 32
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
            if ext_type == 0x00:
                sni_len = struct.unpack("!H", data[pos+7:pos+9])[0]
                return data[pos+9:pos+9+sni_len].decode("ascii")
            pos += 4 + ext_len
    except (IndexError, struct.error):
        pass
    return None

def pipe(src, dst):
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
    try:
        client_sock.settimeout(10)
        data = client_sock.recv(16384)
        if not data:
            client_sock.close()
            return
        sni = extract_sni(data)
        backend_ip = BACKEND_MAP.get(sni, DEFAULT_BACKEND)
        print(f"[{addr[0]}:{addr[1]}] SNI={sni} -> {backend_ip}:443", flush=True)
        backend = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        backend.settimeout(10)
        backend.connect((backend_ip, 443))
        backend.settimeout(300)
        client_sock.settimeout(300)
        backend.sendall(data)
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
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
    while True:
        client_sock, addr = server.accept()
        threading.Thread(target=handle_client, args=(client_sock, addr), daemon=True).start()

if __name__ == "__main__":
    main()
PYEOF

cat > /etc/systemd/system/sni-proxy.service << 'SVCEOF'
[Unit]
Description=SNI TLS Passthrough Proxy for Azure Private Endpoints
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/sni-proxy.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable sni-proxy
systemctl start sni-proxy
sleep 1
echo "Service status: $(systemctl is-active sni-proxy)"
ss -tlnp | grep 443
journalctl -u sni-proxy --no-pager -n 5
