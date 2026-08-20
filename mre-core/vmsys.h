#ifndef VMSYS_H
#define VMSYS_H

#include <stdint.h>

#define VM_TRUE  1
#define VM_FALSE 0

// Screen Dimensions
#define VM_FRAME_WIDTH  240
#define VM_FRAME_HEIGHT 320

// MRE Key Codes
typedef enum {
    VM_KEY_LEFT_SOFTKEY = 1,
    VM_KEY_RIGHT_SOFTKEY = 2,
    VM_KEY_UP = 14,
    VM_KEY_DOWN = 15,
    VM_KEY_LEFT = 16,
    VM_KEY_RIGHT = 17,
    VM_KEY_OK = 13,
    VM_KEY_NUM0 = 47,
    VM_KEY_NUM1 = 48,
    VM_KEY_NUM2 = 49,
    VM_KEY_NUM3 = 50,
    VM_KEY_NUM4 = 51,
    VM_KEY_NUM5 = 52,
    VM_KEY_NUM6 = 53,
    VM_KEY_NUM7 = 54,
    VM_KEY_NUM8 = 55,
    VM_KEY_NUM9 = 56
} VM_KEY_CODE;

// Key Events
#define VM_KEY_EVENT_DOWN 1
#define VM_KEY_EVENT_UP   0

// Graphic Canvas Handle Structure
typedef struct {
    uint16_t width;
    uint16_t height;
    uint32_t size;
    uint8_t* buffer;
} vm_canvas_t;

// API Function Prototypes
void vm_graphic_init(void);
int32_t vm_graphic_create_canvas(int32_t width, int32_t height);
void vm_graphic_blt(uint8_t* dst, int32_t dx, int32_t dy, uint8_t* src, int32_t sx, int32_t sy, int32_t w, int32_t h);

#endif
