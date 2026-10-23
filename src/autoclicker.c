#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <inttypes.h>
#include <linux/input-event-codes.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/timerfd.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "virtual-pointer-client.h"

/* Defaults are passed by autoclicker-run from the saved app settings. */
static volatile sig_atomic_t stopping;
static struct zwlr_virtual_pointer_manager_v1 *manager;

static void stop(int sig) { (void)sig; stopping = 1; }
static uint32_t timestamp(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (uint32_t)((uint64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000);
}
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name))
        manager = wl_registry_bind(registry, name,
                                  &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener registry_listener = {global, removed};

int main(int argc, char **argv) {
    bool check = false;
    long interval_ms = 5;
    unsigned int button = BTN_LEFT;
    const char *button_name = "left";
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--check")) check = true;
        else if (!strcmp(argv[i], "--interval-ms") && i + 1 < argc) {
            char *end;
            errno = 0;
            interval_ms = strtol(argv[++i], &end, 10);
            if (errno || *end || interval_ms < 1 || interval_ms > 60000) {
                fprintf(stderr, "Interval must be an integer from 1 to 60000 ms\n");
                return 2;
            }
        } else if (!strcmp(argv[i], "--button") && i + 1 < argc) {
            button_name = argv[++i];
            if (!strcmp(button_name, "left")) button = BTN_LEFT;
            else if (!strcmp(button_name, "right")) button = BTN_RIGHT;
            else if (!strcmp(button_name, "middle")) button = BTN_MIDDLE;
            else { fprintf(stderr, "Button must be left, right or middle\n"); return 2; }
        } else {
            fprintf(stderr, "Usage: %s [--check] [--interval-ms 1..60000] [--button left|right|middle]\n", argv[0]);
            return 2;
        }
    }
    struct sigaction action = {.sa_handler = stop};
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    signal(SIGPIPE, SIG_IGN);
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { perror("Cannot connect to Wayland"); return 1; }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) {
        fprintf(stderr, "Compositor does not expose the virtual pointer protocol\n");
        wl_display_disconnect(display);
        return 1;
    }
    struct zwlr_virtual_pointer_v1 *pointer =
        zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    if (wl_display_roundtrip(display) < 0) {
        fprintf(stderr, "Compositor rejected the virtual pointer\n");
        wl_display_disconnect(display);
        return 1;
    }
    int result = 0, timer = -1;
    bool pressed = false;
    uint64_t clicks = 0;
    if (check) {
        printf("Wayland virtual pointer available; %ld ms %s-click cycle configured.\n", interval_ms, button_name);
        goto cleanup;
    }
    timer = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC);
    int64_t half_ns = (int64_t)interval_ms * 500000;
    struct itimerspec schedule = {
        .it_interval = {.tv_sec = half_ns / 1000000000, .tv_nsec = half_ns % 1000000000},
        .it_value = {.tv_sec = half_ns / 1000000000, .tv_nsec = half_ns % 1000000000},
    };
    if (timer < 0 || timerfd_settime(timer, 0, &schedule, NULL) < 0) {
        perror("Cannot start click timer"); result = 1; goto cleanup;
    }
    printf("Autoclicker ON: %s button, %ld ms cycle (%.2f clicks/s target)\n", button_name, interval_ms, 1000.0 / interval_ms);
    fflush(stdout);
    while (!stopping) {
        while (wl_display_prepare_read(display) != 0) {
            if (wl_display_dispatch_pending(display) < 0) {
                result = 1; goto cleanup;
            }
        }
        struct pollfd fds[] = {
            {.fd = wl_display_get_fd(display), .events = POLLIN},
            {.fd = timer, .events = POLLIN},
        };
        if (wl_display_flush(display) < 0) {
            if (errno == EAGAIN) fds[0].events |= POLLOUT;
            else { wl_display_cancel_read(display); result = 1; break; }
        }
        int ready = poll(fds, 2, -1);
        if (ready < 0 || stopping) {
            wl_display_cancel_read(display);
            if (ready < 0 && errno != EINTR) { perror("poll"); result = 1; }
            break;
        }
        if (fds[0].revents & (POLLERR | POLLHUP | POLLNVAL)) {
            wl_display_cancel_read(display); result = 1; break;
        }
        if (fds[0].revents & POLLIN) {
            if (wl_display_read_events(display) < 0) { result = 1; break; }
        } else wl_display_cancel_read(display);
        if (wl_display_dispatch_pending(display) < 0) { result = 1; break; }
        if (fds[1].revents & POLLIN) {
            uint64_t ticks;
            if (read(timer, &ticks, sizeof(ticks)) != sizeof(ticks)) {
                result = 1; break;
            }
            /* Skip missed ticks instead of producing a burst after a stall. */
            pressed = !pressed;
            zwlr_virtual_pointer_v1_button(pointer, timestamp(), button,
                pressed ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
            zwlr_virtual_pointer_v1_frame(pointer);
            if (!pressed) ++clicks;
        }
    }
cleanup:
    if (pressed) {
        zwlr_virtual_pointer_v1_button(pointer, timestamp(), button,
                                      WL_POINTER_BUTTON_STATE_RELEASED);
        zwlr_virtual_pointer_v1_frame(pointer);
        ++clicks;
    }
    /* Deliver the final release before destroying the virtual device. */
    if (!check && wl_display_get_error(display) == 0)
        wl_display_roundtrip(display);
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    if (timer >= 0) close(timer);
    if (!check) printf("Autoclicker OFF after %" PRIu64 " complete clicks\n", clicks);
    return result;
}
