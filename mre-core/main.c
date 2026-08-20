#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <emscripten.h>

#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 320

// 240x320 screen buffer in RGBA32 format (4 bytes per pixel)
uint32_t framebuffer[SCREEN_WIDTH * SCREEN_HEIGHT];
static int animation_tick = 0;
static int is_app_loaded = 0;

// Expose framebuffer memory address to JavaScript
EMSCRIPTEN_KEEPALIVE
uint32_t* get_framebuffer() {
    return framebuffer;
}

// Minimal ELF header parser for .vxp files
int parse_vxp_header(const char* filepath) {
    FILE* file = fopen(filepath, "rb");
    if (!file) {
        printf("[MRE Core Error] Unable to open %s\n", filepath);
        return 0;
    }

    uint8_t header[52];
    size_t read_bytes = fread(header, 1, 52, file);
    fclose(file);

    if (read_bytes < 52) {
        printf("[MRE Core Error] File too small to be a valid .vxp binary.\n");
        return 0;
    }

    // Check ELF Magic Number (\x7F ELF)
    if (header[0] == 0x7F && header[1] == 'E' && header[2] == 'L' && header[3] == 'F') {
        printf("[MRE VXP Parser] Valid ELF Header detected (ARM target).\n");
        return 1;
    } else {
        printf("[MRE VXP Parser] Warning: Standard ELF magic missing. Attempting raw MRE binary load...\n");
        return 1;
    }
}

// MRE Graphics API Stub: Clear screen with color
void vm_graphic_clear_screen(uint32_t color) {
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
        framebuffer[i] = color;
    }
}

// MRE Key Handler API Stub
EMSCRIPTEN_KEEPALIVE
void send_mre_key(int key_code, int is_pressed) {
    printf("[MRE Event] Key Code: %d | State: %s\n", key_code, is_pressed ? "DOWN" : "UP");
}

// Engine Frame Loop (Called by Emscripten 60 times/sec)
void main_loop_tick() {
    if (!is_app_loaded) return;

    animation_tick++;

    // Simulated MRE Engine rendering pass
    // Generates test patterns on canvas to verify WebGL/Canvas BLT pipeline
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            uint8_t r = (x + animation_tick) % 256;
            uint8_t g = (y + animation_tick) % 256;
            uint8_t b = 128;
            uint8_t a = 255;

            // Store in ABGR/RGBA memory layout
            framebuffer[y * SCREEN_WIDTH + x] = (a << 24) | (b << 16) | (g << 8) | r;
        }
    }
}

EMSCRIPTEN_KEEPALIVE
int run_vxp_app(const char* filepath) {
    printf("[MRE Engine] Loading application: %s\n", filepath);

    if (parse_vxp_header(filepath)) {
        is_app_loaded = 1;
        printf("[MRE Engine] Application mounted successfully. Starting main execution loop...\n");
        emscripten_set_main_loop(main_loop_tick, 60, 0);
        return 1;
    }

    return 0;
}

EMSCRIPTEN_KEEPALIVE
int main() {
    printf("[MRE Core] Dynamic runtime initialized.\n");
    return 0;
}
