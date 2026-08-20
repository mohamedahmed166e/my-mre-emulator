#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "vmsys.h"

extern uint32_t framebuffer[VM_FRAME_WIDTH * VM_FRAME_HEIGHT];

static vm_canvas_t active_canvas = {0};

void vm_graphic_init(void) {
    active_canvas.width = VM_FRAME_WIDTH;
    active_canvas.height = VM_FRAME_HEIGHT;
    active_canvas.size = VM_FRAME_WIDTH * VM_FRAME_HEIGHT * 4;
    active_canvas.buffer = (uint8_t*)framebuffer;
    printf("[MRE API] Graphic Subsystem Initialized (240x320 Canvas).\n");
}

int32_t vm_graphic_create_canvas(int32_t width, int32_t height) {
    printf("[MRE API] Created virtual canvas: %dx%d\n", width, height);
    return 1; // Return handle 1
}

// Draw/Blt pixels from app canvas buffer into WASM main framebuffer
void vm_graphic_blt(uint8_t* dst, int32_t dx, int32_t dy, uint8_t* src, int32_t sx, int32_t sy, int32_t w, int32_t h) {
    if (!src || !dst) return;

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int target_x = dx + x;
            int target_y = dy + y;

            if (target_x >= 0 && target_x < VM_FRAME_WIDTH && target_y >= 0 && target_y < VM_FRAME_HEIGHT) {
                int src_idx = ((sy + y) * w + (sx + x)) * 4;
                int dst_idx = (target_y * VM_FRAME_WIDTH + target_x);

                uint8_t r = src[src_idx];
                uint8_t g = src[src_idx + 1];
                uint8_t b = src[src_idx + 2];
                uint8_t a = src[src_idx + 3];

                framebuffer[dst_idx] = (a << 24) | (b << 16) | (g << 8) | r;
            }
        }
    }
}
