/*
 * moaiy-pinentry.c
 *
 * Minimal Assuan pinentry for sandboxed OpenPGP card decrypt.
 * CONFIRM and MESSAGE are acknowledged so GnuPG 2.5 INQUIRE CONFIRM is not ignored.
 * GETPIN reads $GNUPGHOME/moaiy-pinentry.token (mode 0600). The PIN is never
 * taken from argv and is never written to stderr.
 */

#define _GNU_SOURCE

#include <ctype.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void wipe(void *ptr, size_t len) {
    volatile unsigned char *cursor = ptr;
    while (len > 0) {
        *cursor++ = 0;
        len--;
    }
}

static void send_ok(void) {
    fputs("OK\n", stdout);
    fflush(stdout);
}

static void send_cancelled(void) {
    fputs("ERR 83886179 Operation cancelled\n", stdout);
    fflush(stdout);
}

static int token_path(char *out, size_t out_len) {
    const char *home = getenv("GNUPGHOME");
    int written;
    if (home == NULL || home[0] == '\0') {
        return -1;
    }
    written = snprintf(out, out_len, "%s/moaiy-pinentry.token", home);
    if (written < 0 || (size_t)written >= out_len) {
        return -1;
    }
    return 0;
}

static int read_token(char *out, size_t out_len, size_t *out_count) {
    char path[4096];
    struct stat info;
    int fd;
    ssize_t count;
    if (token_path(path, sizeof(path)) != 0) {
        return -1;
    }
    fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || (info.st_mode & 077) != 0) {
        close(fd);
        return -1;
    }
    if (info.st_size <= 0 || (size_t)info.st_size >= out_len) {
        close(fd);
        return -1;
    }
    count = read(fd, out, (size_t)info.st_size);
    close(fd);
    if (count <= 0) {
        return -1;
    }
    while (count > 0 && (out[count - 1] == '\n' || out[count - 1] == '\r')) {
        count--;
    }
    if (count <= 0) {
        return -1;
    }
    out[count] = '\0';
    *out_count = (size_t)count;
    return 0;
}

static void send_data(const char *data, size_t count) {
    size_t index;
    fputs("D ", stdout);
    for (index = 0; index < count; index++) {
        unsigned char byte = (unsigned char)data[index];
        if (byte < 0x20 || byte == 0x7f || byte == '%') {
            fprintf(stdout, "%%%02X", byte);
        } else {
            fputc(byte, stdout);
        }
    }
    fputc('\n', stdout);
    send_ok();
}

static void handle_getinfo(const char *argument) {
    if (strcmp(argument, "pid") == 0) {
        fprintf(stdout, "D %ld\n", (long)getpid());
        send_ok();
        return;
    }
    if (strcmp(argument, "flavor") == 0) {
        fputs("D moaiy\n", stdout);
        send_ok();
        return;
    }
    if (strcmp(argument, "version") == 0) {
        fputs("D 1.0.0\n", stdout);
        send_ok();
        return;
    }
    if (strcmp(argument, "ttyinfo") == 0) {
        fputs("D - - -\n", stdout);
        send_ok();
        return;
    }
    send_cancelled();
}

static void lowercase_command(char *command) {
    while (*command != '\0') {
        *command = (char)tolower((unsigned char)*command);
        command++;
    }
}

int main(void) {
    char line[8192];
    fputs("OK Your orders please\n", stdout);
    fflush(stdout);

    while (fgets(line, sizeof(line), stdin) != NULL) {
        char *argument = NULL;
        char *space;
        size_t length = strlen(line);
        while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) {
            line[--length] = '\0';
        }
        if (length == 0) {
            continue;
        }
        space = strchr(line, ' ');
        if (space != NULL) {
            *space = '\0';
            argument = space + 1;
        }
        lowercase_command(line);
        if (strcmp(line, "bye") == 0) {
            send_ok();
            return 0;
        }
        if (strcmp(line, "reset") == 0 || strcmp(line, "option") == 0 || strncmp(line, "set", 3) == 0
            || strcmp(line, "message") == 0 || strcmp(line, "confirm") == 0) {
            send_ok();
            continue;
        }
        if (strcmp(line, "getinfo") == 0) {
            handle_getinfo(argument == NULL ? "" : argument);
            continue;
        }
        if (strcmp(line, "getpin") == 0) {
            char token[512];
            size_t count = 0;
            if (read_token(token, sizeof(token), &count) != 0) {
                wipe(token, sizeof(token));
                send_cancelled();
            } else {
                send_data(token, count);
                wipe(token, sizeof(token));
            }
            continue;
        }
        fputs("ERR 536871187 Unknown command\n", stdout);
        fflush(stdout);
    }
    return 0;
}
