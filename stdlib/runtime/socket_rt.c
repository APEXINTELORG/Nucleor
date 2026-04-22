// socket_rt.c — TCP/UDP Networking for Nucleor
// TCP connect/listen/accept/send/recv, UDP, simple HTTP GET/POST.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/socket_rt.c -o target/socket_rt.obj -O2
// Link: -lws2_32 (Windows)

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
static int ws_init = 0;
static void ensure_winsock(void) {
    if (!ws_init) {
        WSADATA wsa;
        WSAStartup(MAKEWORD(2, 2), &wsa);
        ws_init = 1;
    }
}
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#define closesocket close
#define SOCKET int
#define INVALID_SOCKET -1
static void ensure_winsock(void) {}
#endif

// ================================================================
//  TCP
// ================================================================

long long nuc_tcp_connect(const char *host, long long port) {
    ensure_winsock();
    struct addrinfo hints = {0}, *res;
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    char port_str[16];
    snprintf(port_str, 16, "%lld", port);
    if (getaddrinfo(host, port_str, &hints, &res) != 0) return -1;

    SOCKET s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (s == INVALID_SOCKET) { freeaddrinfo(res); return -1; }
    if (connect(s, res->ai_addr, (int)res->ai_addrlen) != 0) {
        closesocket(s); freeaddrinfo(res); return -1;
    }
    freeaddrinfo(res);
    return (long long)s;
}

long long nuc_tcp_listen(long long port, long long backlog) {
    ensure_winsock();
    SOCKET s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == INVALID_SOCKET) return -1;
    int opt = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (const char *)&opt, sizeof(opt));
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons((unsigned short)port);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) { closesocket(s); return -1; }
    if (listen(s, (int)backlog) != 0) { closesocket(s); return -1; }
    return (long long)s;
}

long long nuc_tcp_accept(long long server_h) {
    ensure_winsock();
    struct sockaddr_in client_addr;
    int len = sizeof(client_addr);
    SOCKET client = accept((SOCKET)server_h, (struct sockaddr *)&client_addr, &len);
    return (long long)client;
}

long long nuc_tcp_send(long long h, const char *data, long long len) {
    return (long long)send((SOCKET)h, data, (int)len, 0);
}

long long nuc_tcp_recv(long long h, long long max_len) {
    char *buf = (char *)malloc((int)max_len + 1);
    int n = recv((SOCKET)h, buf, (int)max_len, 0);
    if (n <= 0) { free(buf); return (long long)""; }
    buf[n] = 0;
    return (long long)buf;
}

void nuc_tcp_close(long long h) {
    closesocket((SOCKET)h);
}

// ================================================================
//  UDP
// ================================================================

long long nuc_udp_open(long long port) {
    ensure_winsock();
    SOCKET s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s == INVALID_SOCKET) return -1;
    if (port > 0) {
        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons((unsigned short)port);
        bind(s, (struct sockaddr *)&addr, sizeof(addr));
    }
    return (long long)s;
}

long long nuc_udp_send(long long h, const char *host, long long port,
                        const char *data, long long len) {
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    addr.sin_addr.s_addr = inet_addr(host);
    return (long long)sendto((SOCKET)h, data, (int)len, 0,
                              (struct sockaddr *)&addr, sizeof(addr));
}

long long nuc_udp_recv(long long h, long long max_len) {
    char *buf = (char *)malloc((int)max_len + 1);
    struct sockaddr_in sender;
    int slen = sizeof(sender);
    int n = recvfrom((SOCKET)h, buf, (int)max_len, 0, (struct sockaddr *)&sender, &slen);
    if (n <= 0) { free(buf); return (long long)""; }
    buf[n] = 0;
    return (long long)buf;
}

// ================================================================
//  Simple HTTP GET
// ================================================================

const char *nuc_http_get(const char *url) {
    // Parse URL: http://host[:port]/path
    if (!url) return "";
    if (strncmp(url, "http://", 7) != 0) return "";
    const char *host_start = url + 7;
    const char *path = strchr(host_start, '/');
    if (!path) path = "/";

    char host[256] = {0};
    int port = 80;
    int host_len = path ? (int)(path - host_start) : (int)strlen(host_start);
    if (host_len >= 256) host_len = 255;
    memcpy(host, host_start, host_len);

    char *colon = strchr(host, ':');
    if (colon) { *colon = 0; port = atoi(colon + 1); }

    long long s = nuc_tcp_connect(host, port);
    if (s < 0) return "";

    char req[2048];
    snprintf(req, 2048, "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", path, host);
    send((SOCKET)s, req, (int)strlen(req), 0);

    // Read response
    int cap = 65536, len = 0;
    char *buf = (char *)malloc(cap);
    while (1) {
        int n = recv((SOCKET)s, buf + len, cap - len - 1, 0);
        if (n <= 0) break;
        len += n;
        if (len >= cap - 1) { cap *= 2; buf = (char *)realloc(buf, cap); }
    }
    buf[len] = 0;
    closesocket((SOCKET)s);

    // Skip HTTP headers
    char *body = strstr(buf, "\r\n\r\n");
    if (body) {
        body += 4;
        char *result = (char *)malloc(len - (int)(body - buf) + 1);
        strcpy(result, body);
        free(buf);
        return result;
    }
    return buf;
}
