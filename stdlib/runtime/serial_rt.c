// serial_rt.c — Serial Port Communication (UART) for Nucleor
// Open/close/read/write serial ports. Windows COM ports, Linux /dev/ttyUSB*.
//
// Compile: clang -c stdlib/runtime/serial_rt.c -o target/serial_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#endif

// ================================================================
//  Open serial port
//  port: "COM3" (Windows) or "/dev/ttyUSB0" (Linux)
//  baud: 9600, 115200, etc.
// ================================================================

long long nuc_serial_open(const char *port, long long baud) {
    if (!port) return -1;
#ifdef _WIN32
    HANDLE h = CreateFileA(port, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (h == INVALID_HANDLE_VALUE) return -1;

    DCB dcb = {0};
    dcb.DCBlength = sizeof(DCB);
    GetCommState(h, &dcb);
    dcb.BaudRate = (DWORD)baud;
    dcb.ByteSize = 8;
    dcb.StopBits = ONESTOPBIT;
    dcb.Parity = NOPARITY;
    SetCommState(h, &dcb);

    COMMTIMEOUTS timeouts = {0};
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 100;
    timeouts.ReadTotalTimeoutMultiplier = 10;
    SetCommTimeouts(h, &timeouts);

    return (long long)h;
#else
    int fd = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) return -1;

    struct termios tio;
    tcgetattr(fd, &tio);
    cfmakeraw(&tio);
    speed_t speed;
    switch ((int)baud) {
        case 9600: speed = B9600; break;
        case 19200: speed = B19200; break;
        case 38400: speed = B38400; break;
        case 57600: speed = B57600; break;
        case 115200: speed = B115200; break;
        default: speed = B9600;
    }
    cfsetispeed(&tio, speed);
    cfsetospeed(&tio, speed);
    tio.c_cflag |= CLOCAL | CREAD;
    tio.c_cflag &= ~CSIZE; tio.c_cflag |= CS8;
    tio.c_cflag &= ~PARENB;
    tio.c_cflag &= ~CSTOPB;
    tcsetattr(fd, TCSANOW, &tio);
    return (long long)fd;
#endif
}

long long nuc_serial_write(long long h, const char *data, long long len) {
    if (!data) return 0;
#ifdef _WIN32
    DWORD written;
    WriteFile((HANDLE)h, data, (DWORD)len, &written, NULL);
    return (long long)written;
#else
    return (long long)write((int)h, data, (int)len);
#endif
}

long long nuc_serial_read(long long h, long long max_len) {
    char *buf = (char *)malloc((int)max_len + 1);
    int n;
#ifdef _WIN32
    DWORD read_bytes;
    ReadFile((HANDLE)h, buf, (DWORD)max_len, &read_bytes, NULL);
    n = (int)read_bytes;
#else
    n = read((int)h, buf, (int)max_len);
    if (n < 0) n = 0;
#endif
    buf[n] = 0;
    return (long long)buf;
}

void nuc_serial_close(long long h) {
#ifdef _WIN32
    CloseHandle((HANDLE)h);
#else
    close((int)h);
#endif
}
