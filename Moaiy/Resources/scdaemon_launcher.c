/*
 * Thin CFBundleExecutable for MoaiyScdaemon.app.
 *
 * A sandboxed parent opens this helper through CoreServicesUIAgent, which
 * drops OpenConfiguration.arguments and environment. This launcher ignores
 * Launch Services argv and environment variables. It starts the sibling
 * scdaemon binary with --multi-server and --homedir in the helper's own
 * container (the only path a standalone-sandboxed scdaemon can bind), then
 * stays in the foreground and proxies the Assuan socket into the Moaiy
 * container GNUPGHOME.
 *
 * gpg-agent does not attach to an existing S.scdaemon on first use. It
 * always pipe-connects scdaemon-program with --multi-server, then learns
 * the extra socket from GETINFO socket_name. When this executable is
 * invoked that way (as scdaemon-program), it relays stdin/stdout to the
 * already-published Moaiy-container socket instead of inherit-spawning
 * the standalone-sandboxed scdaemon, which would SIGTRAP. GETINFO
 * socket_name data lines are rewritten to the published path so later
 * agent connections use that socket, not the helper-container backend.
 *
 * The real home directory comes from getpwuid(3), never the HOME
 * environment variable or a container home path. The process stays in the
 * foreground; --daemon would exit(0) and RunningBoard would tear the job
 * down. Launch Services does not provide an Assuan stdio client, so the
 * supervisor keeps a pipe write end open to scdaemon's standard input;
 * otherwise --multi-server treats stdin EOF as shutdown.
 *
 * The supervisor must never log Assuan payload (PIN and other secrets may
 * transit the proxy).
 */

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <poll.h>
#include <pwd.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

#define MOAIY_GNUPGHOME_SUFFIX "/Library/Containers/com.moaiy.app/Data/Library/gnupg"
#define HELPER_GNUPGHOME_SUFFIX "/Library/Containers/com.moaiy.app.scdaemon/Data/Library/gnupg"
#define SCDAEMON_NAME "scdaemon"
#define SOCKET_NAME "S.scdaemon"
#define CONF_NAME "scdaemon.conf"

static volatile sig_atomic_t g_stop;
static pid_t g_scdaemon_pid = -1;

static void request_stop(int sig)
{
    (void)sig;
    g_stop = 1;
}

static int real_user_home(char *buf, size_t buflen)
{
    const struct passwd *pw = getpwuid(getuid());
    if (pw == NULL || pw->pw_dir == NULL || pw->pw_dir[0] != '/') {
        return -1;
    }
    if (strstr(pw->pw_dir, "/Library/Containers/") != NULL) {
        return -1;
    }
    size_t n = strlen(pw->pw_dir);
    if (n == 0 || n >= buflen) {
        return -1;
    }
    memcpy(buf, pw->pw_dir, n + 1);
    return 0;
}

static int executable_directory(char *buf, size_t buflen)
{
    char raw[PATH_MAX];
    uint32_t size = sizeof(raw);
    if (_NSGetExecutablePath(raw, &size) != 0) {
        return -1;
    }
    char resolved[PATH_MAX];
    if (realpath(raw, resolved) == NULL) {
        strncpy(resolved, raw, sizeof(resolved) - 1);
        resolved[sizeof(resolved) - 1] = '\0';
    }
    char *slash = strrchr(resolved, '/');
    if (slash == NULL || slash == resolved) {
        return -1;
    }
    *slash = '\0';
    size_t n = strlen(resolved);
    if (n >= buflen) {
        return -1;
    }
    memcpy(buf, resolved, n + 1);
    return 0;
}

static int mkdir_p_0700(const char *path)
{
    char tmp[PATH_MAX];
    size_t n = strlen(path);
    if (n == 0 || n >= sizeof(tmp)) {
        return -1;
    }
    memcpy(tmp, path, n + 1);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, 0700) != 0 && errno != EEXIST) {
                return -1;
            }
            *p = '/';
        }
    }
    if (mkdir(tmp, 0700) != 0 && errno != EEXIST) {
        return -1;
    }
    if (chmod(tmp, 0700) != 0) {
        return -1;
    }
    return 0;
}

static int join3(char *buf, size_t buflen, const char *a, const char *b, const char *c)
{
    int n;
    if (c != NULL) {
        n = snprintf(buf, buflen, "%s%s/%s", a, b, c);
    } else {
        n = snprintf(buf, buflen, "%s%s", a, b);
    }
    return (n < 0 || n >= (int)buflen) ? -1 : 0;
}

static int copy_file(const char *src, const char *dst)
{
    int in = open(src, O_RDONLY);
    if (in < 0) {
        return (errno == ENOENT) ? 0 : -1;
    }
    int out = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (out < 0) {
        close(in);
        return -1;
    }
    char buf[4096];
    ssize_t r;
    while ((r = read(in, buf, sizeof(buf))) > 0) {
        ssize_t off = 0;
        while (off < r) {
            ssize_t w = write(out, buf + off, (size_t)(r - off));
            if (w < 0) {
                if (errno == EINTR) {
                    continue;
                }
                close(in);
                close(out);
                return -1;
            }
            off += w;
        }
    }
    close(in);
    close(out);
    return (r < 0) ? -1 : 0;
}

static int unix_connect(const char *path)
{
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) {
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof(addr.sun_path)) {
        close(s);
        return -1;
    }
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(s);
        return -1;
    }
    return s;
}

static int unix_listen(const char *path)
{
    unlink(path);
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) {
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof(addr.sun_path)) {
        close(s);
        return -1;
    }
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(s);
        return -1;
    }
    (void)chmod(path, 0600);
    if (listen(s, 16) != 0) {
        close(s);
        unlink(path);
        return -1;
    }
    return s;
}

static int wait_for_socket(const char *path, int timeout_ms)
{
    int waited = 0;
    while (waited < timeout_ms) {
        if (g_stop) {
            return -1;
        }
        int s = unix_connect(path);
        if (s >= 0) {
            close(s);
            return 0;
        }
        usleep(50 * 1000);
        waited += 50;
    }
    return -1;
}

static void relay(int a, int b)
{
    char buf[4096];
    struct pollfd pfd[2];
    for (;;) {
        pfd[0].fd = a;
        pfd[0].events = POLLIN;
        pfd[0].revents = 0;
        pfd[1].fd = b;
        pfd[1].events = POLLIN;
        pfd[1].revents = 0;
        int rc = poll(pfd, 2, -1);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }
        for (int i = 0; i < 2; i++) {
            if (pfd[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                return;
            }
            if (pfd[i].revents & POLLIN) {
                ssize_t n = read(pfd[i].fd, buf, sizeof(buf));
                if (n <= 0) {
                    return;
                }
                int out = (i == 0) ? b : a;
                ssize_t off = 0;
                while (off < n) {
                    ssize_t w = write(out, buf + off, (size_t)(n - off));
                    if (w < 0) {
                        if (errno == EINTR) {
                            continue;
                        }
                        return;
                    }
                    off += w;
                }
            }
        }
    }
}

static void reap_children(void)
{
    while (waitpid(-1, NULL, WNOHANG) > 0) {
    }
}

static void shutdown_children(const char *published_socket)
{
    if (published_socket != NULL) {
        unlink(published_socket);
    }
    if (g_scdaemon_pid > 0) {
        kill(g_scdaemon_pid, SIGTERM);
        for (int i = 0; i < 20; i++) {
            if (waitpid(g_scdaemon_pid, NULL, WNOHANG) == g_scdaemon_pid) {
                g_scdaemon_pid = -1;
                break;
            }
            usleep(50 * 1000);
        }
        if (g_scdaemon_pid > 0) {
            kill(g_scdaemon_pid, SIGKILL);
            (void)waitpid(g_scdaemon_pid, NULL, 0);
            g_scdaemon_pid = -1;
        }
    }
    reap_children();
}

static int write_all(int fd, const void *buf, size_t n)
{
    const char *p = buf;
    size_t off = 0;
    while (off < n) {
        ssize_t w = write(fd, p + off, n - off);
        if (w < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        off += (size_t)w;
    }
    return 0;
}

static int is_safe_absolute_homedir(const char *path)
{
    size_t n;
    if (path == NULL || path[0] != '/') {
        return 0;
    }
    if (strstr(path, "/../") != NULL) {
        return 0;
    }
    n = strlen(path);
    if (n >= 3 && strcmp(path + n - 3, "/..") == 0) {
        return 0;
    }
    return 1;
}

static int published_socket_from_homedir(const char *homedir, char *out, size_t outsz)
{
    int n;
    if (!is_safe_absolute_homedir(homedir)) {
        return -1;
    }
    n = snprintf(out, outsz, "%s/%s", homedir, SOCKET_NAME);
    if (n < 0 || (size_t)n >= outsz) {
        return -1;
    }
    return 0;
}

/* "D /absolute/path/S.scdaemon" with optional CR/LF. No payload logging. */
static int is_scdaemon_socket_data_line(const char *line, size_t n)
{
    static const char suffix[] = "/" SOCKET_NAME;
    const size_t slen = sizeof(suffix) - 1;
    size_t end = n;

    if (n < 3 || line[0] != 'D' || line[1] != ' ' || line[2] != '/') {
        return 0;
    }
    if (end > 0 && line[end - 1] == '\n') {
        end--;
    }
    if (end > 0 && line[end - 1] == '\r') {
        end--;
    }
    if (end < 3 + slen) {
        return 0;
    }
    return memcmp(line + end - slen, suffix, slen) == 0;
}

static int write_rewritten_socket_name_line(int out, const char *published)
{
    char rewritten[PATH_MAX + 8];
    int n = snprintf(rewritten, sizeof(rewritten), "D %s\n", published);
    if (n < 0 || (size_t)n >= sizeof(rewritten)) {
        return -1;
    }
    return write_all(out, rewritten, (size_t)n);
}

static int flush_backend_line(int out, const char *published, const char *line, size_t n)
{
    if (is_scdaemon_socket_data_line(line, n)) {
        return write_rewritten_socket_name_line(out, published);
    }
    return write_all(out, line, n);
}

static int stdio_relay_to_published_socket(const char *sock_path)
{
    char line[4096];
    size_t line_len = 0;
    int sock;
    struct pollfd pfd[2];

    if (wait_for_socket(sock_path, 5000) != 0) {
        fprintf(stderr, "MoaiyScdaemon: published S.scdaemon is not accepting connections\n");
        return 1;
    }
    sock = unix_connect(sock_path);
    if (sock < 0) {
        fprintf(stderr, "MoaiyScdaemon: failed to connect to published S.scdaemon\n");
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);

    for (;;) {
        pfd[0].fd = STDIN_FILENO;
        pfd[0].events = POLLIN;
        pfd[0].revents = 0;
        pfd[1].fd = sock;
        pfd[1].events = POLLIN;
        pfd[1].revents = 0;
        int rc = poll(pfd, 2, -1);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }
        if (pfd[0].revents & (POLLERR | POLLNVAL)) {
            break;
        }
        if (pfd[0].revents & (POLLIN | POLLHUP)) {
            char buf[4096];
            ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n < 0) {
                if (errno == EINTR) {
                    continue;
                }
                break;
            }
            if (n == 0) {
                (void)shutdown(sock, SHUT_WR);
                pfd[0].fd = -1;
            } else if (write_all(sock, buf, (size_t)n) != 0) {
                break;
            }
        }
        if (pfd[1].revents & (POLLERR | POLLNVAL)) {
            break;
        }
        if (pfd[1].revents & (POLLIN | POLLHUP)) {
            char buf[4096];
            ssize_t n = read(sock, buf, sizeof(buf));
            if (n < 0) {
                if (errno == EINTR) {
                    continue;
                }
                break;
            }
            if (n == 0) {
                break;
            }
            for (ssize_t i = 0; i < n; i++) {
                if (line_len + 1 >= sizeof(line)) {
                    if (flush_backend_line(STDOUT_FILENO, sock_path, line, line_len) != 0) {
                        close(sock);
                        return 1;
                    }
                    line_len = 0;
                }
                line[line_len++] = buf[i];
                if (buf[i] == '\n') {
                    if (flush_backend_line(STDOUT_FILENO, sock_path, line, line_len) != 0) {
                        close(sock);
                        return 1;
                    }
                    line_len = 0;
                }
            }
        }
    }
    if (line_len > 0) {
        (void)flush_backend_line(STDOUT_FILENO, sock_path, line, line_len);
    }
    close(sock);
    return 0;
}

static int argv_has_flag(int argc, char **argv, const char *flag)
{
    int i;
    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], flag) == 0) {
            return 1;
        }
    }
    return 0;
}

static const char *argv_option_value(int argc, char **argv, const char *option)
{
    int i;
    for (i = 1; i < argc - 1; i++) {
        if (strcmp(argv[i], option) == 0) {
            return argv[i + 1];
        }
    }
    return NULL;
}

static int run_agent_stdio_relay(int argc, char **argv)
{
    char home[PATH_MAX];
    char sock_path[PATH_MAX];
    const char *homedir = argv_option_value(argc, argv, "--homedir");

    if (homedir == NULL) {
        if (real_user_home(home, sizeof(home)) != 0
            || join3(sock_path, sizeof(sock_path), home, MOAIY_GNUPGHOME_SUFFIX, SOCKET_NAME) != 0) {
            fprintf(stderr, "MoaiyScdaemon: failed to resolve published S.scdaemon\n");
            return 1;
        }
    } else if (published_socket_from_homedir(homedir, sock_path, sizeof(sock_path)) != 0) {
        fprintf(stderr, "MoaiyScdaemon: invalid --homedir for stdio relay\n");
        return 1;
    }
    return stdio_relay_to_published_socket(sock_path);
}

int main(int argc, char **argv)
{
    if (argv_has_flag(argc, argv, "--multi-server")) {
        return run_agent_stdio_relay(argc, argv);
    }


    char home[PATH_MAX];
    if (real_user_home(home, sizeof(home)) != 0) {
        fprintf(stderr, "MoaiyScdaemon: failed to resolve real user home\n");
        return 1;
    }

    char helper_home[PATH_MAX];
    char moaiy_home[PATH_MAX];
    char helper_sock[PATH_MAX];
    char moaiy_sock[PATH_MAX];
    char src_conf[PATH_MAX];
    char dst_conf[PATH_MAX];
    if (join3(helper_home, sizeof(helper_home), home, HELPER_GNUPGHOME_SUFFIX, NULL) != 0
        || join3(moaiy_home, sizeof(moaiy_home), home, MOAIY_GNUPGHOME_SUFFIX, NULL) != 0
        || join3(helper_sock, sizeof(helper_sock), home, HELPER_GNUPGHOME_SUFFIX, SOCKET_NAME) != 0
        || join3(moaiy_sock, sizeof(moaiy_sock), home, MOAIY_GNUPGHOME_SUFFIX, SOCKET_NAME) != 0
        || join3(src_conf, sizeof(src_conf), home, MOAIY_GNUPGHOME_SUFFIX, CONF_NAME) != 0
        || join3(dst_conf, sizeof(dst_conf), home, HELPER_GNUPGHOME_SUFFIX, CONF_NAME) != 0) {
        fprintf(stderr, "MoaiyScdaemon: GNUPGHOME path too long\n");
        return 1;
    }

    if (mkdir_p_0700(helper_home) != 0) {
        fprintf(stderr, "MoaiyScdaemon: failed to create helper GNUPGHOME: %s\n", strerror(errno));
        return 1;
    }
    (void)copy_file(src_conf, dst_conf);

    char dir[PATH_MAX];
    if (executable_directory(dir, sizeof(dir)) != 0) {
        fprintf(stderr, "MoaiyScdaemon: failed to resolve executable directory\n");
        return 1;
    }

    char scdaemon[PATH_MAX];
    if (snprintf(scdaemon, sizeof(scdaemon), "%s/%s", dir, SCDAEMON_NAME)
        >= (int)sizeof(scdaemon)) {
        fprintf(stderr, "MoaiyScdaemon: scdaemon path too long\n");
        return 1;
    }
    if (access(scdaemon, X_OK) != 0) {
        fprintf(stderr, "MoaiyScdaemon: scdaemon is not executable\n");
        return 1;
    }

    int stdin_pipe[2];
    if (pipe(stdin_pipe) != 0) {
        fprintf(stderr, "MoaiyScdaemon: pipe failed: %s\n", strerror(errno));
        return 1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        fprintf(stderr, "MoaiyScdaemon: fork failed: %s\n", strerror(errno));
        return 1;
    }
    if (pid == 0) {
        close(stdin_pipe[1]);
        if (dup2(stdin_pipe[0], STDIN_FILENO) < 0) {
            _exit(1);
        }
        if (stdin_pipe[0] != STDIN_FILENO) {
            close(stdin_pipe[0]);
        }
        char *newargv[] = {
            scdaemon,
            "--homedir",
            helper_home,
            "--multi-server",
            NULL
        };
        execv(scdaemon, newargv);
        _exit(127);
    }

    g_scdaemon_pid = pid;
    close(stdin_pipe[0]);
    /* Keep stdin_pipe[1] open so scdaemon does not see stdin EOF. */

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = request_stop;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    if (wait_for_socket(helper_sock, 5000) != 0) {
        fprintf(stderr, "MoaiyScdaemon: scdaemon did not accept connections\n");
        shutdown_children(NULL);
        close(stdin_pipe[1]);
        return 1;
    }

    int listenfd = unix_listen(moaiy_sock);
    if (listenfd < 0) {
        fprintf(stderr, "MoaiyScdaemon: failed to publish S.scdaemon: %s\n", strerror(errno));
        shutdown_children(NULL);
        close(stdin_pipe[1]);
        return 1;
    }

    while (!g_stop) {
        int status;
        pid_t died = waitpid(g_scdaemon_pid, &status, WNOHANG);
        if (died == g_scdaemon_pid) {
            g_scdaemon_pid = -1;
            break;
        }
        reap_children();

        struct pollfd pfd = { .fd = listenfd, .events = POLLIN, .revents = 0 };
        int rc = poll(&pfd, 1, 250);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }
        if (rc == 0 || !(pfd.revents & POLLIN)) {
            continue;
        }
        int client = accept(listenfd, NULL, NULL);
        if (client < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }
        int backend = unix_connect(helper_sock);
        if (backend < 0) {
            close(client);
            continue;
        }
        pid_t relay_pid = fork();
        if (relay_pid == 0) {
            close(listenfd);
            close(stdin_pipe[1]);
            relay(client, backend);
            _exit(0);
        }
        close(client);
        close(backend);
        if (relay_pid < 0) {
            break;
        }
    }

    close(listenfd);
    shutdown_children(moaiy_sock);
    close(stdin_pipe[1]);
    return g_stop ? 0 : 1;
}
