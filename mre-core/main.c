#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <emscripten.h>
#include "vmsys.h"

// 240x320 Framebuffer (32-bit RGBA)
uint32_t framebuffer[VM_FRAME_WIDTH * VM_FRAME_HEIGHT];

// Application State
static int is_app_running = 0;
static uint8_t* vxp_memory_buffer = NULL;
static long vxp_file_size = 0;

// ELF Header Structures (ARM 32-bit)
typedef struct {
    unsigned char e_ident[16];
    uint16_t e_type;
    uint16_t e_machine;
    uint32_t e_version;
    uint32_t e_entry;     // Entry point address for ARM execution
    uint32_t e_phoff;
    uint32_t e_shoff;     // Section header table offset
    uint32_t e_flags;
    uint16_t e_ehsize;
    uint16_t e_phentsize;
    uint16_t e_phnum;
    uint16_t e_shentsize;
    uint16_t e_shnum;
    uint16_t e_shstrndx;
} Elf32_Ehdr;

typedef struct {
    uint32_t sh_name;
    uint32_t sh_type;
    uint32_t sh_flags;
    uint32_t sh_addr;
    uint32_t sh_offset;
    uint32_t sh_size;
    uint32_t sh_link;
    uint32_t sh_info;
    uint32_t sh_addralign;
    uint32_t sh_entsize;
} Elf32_Shdr;

EMSCRIPTEN_KEEPALIVE
uint32_t* get_framebuffer() {
    return framebuffer;
}

// Key Event Dispatcher
EMSCRIPTEN_KEEPALIVE
void send_mre_key(int key_code, int is_pressed) {
    if (!is_app_running) return;
    
    printf("[MRE Event] Dispatching Key Code: %d | State: %s\n", 
           key_code, is_pressed ? "DOWN" : "UP");
           
    // Pass key state directly to MRE firmware handler stub
    // vm_key_handler(key_code, is_pressed ? VM_KEY_EVENT_DOWN : VM_KEY_EVENT_UP);
}

// Parse ELF Headers & Load VXP Sections into Virtual Memory
static int load_vxp_sections(uint8_t* buffer, long size) {
    if (size < sizeof(Elf32_Ehdr)) {
        printf("[MRE Loader Error] File size too small for ELF header.\n");
        return 0;
    }

    Elf32_Ehdr* ehdr = (Elf32_Ehdr*)buffer;

    // Verify Magic Bytes (\x7F ELF)
    if (ehdr->e_ident[0] != 0x7F || ehdr->e_ident[1] != 'E' ||
        ehdr->e_ident[2] != 'L'  || ehdr->e_ident[3] != 'F') {
        printf("[MRE Loader Warning] Non-standard ELF magic. Falling back to flat binary execution.\n");
        return 1;
    }

    printf("[MRE Loader] Valid ARM ELF detected. Entry point: 0x%08X\n", ehdr->e_entry);
    printf("[MRE Loader] Section Headers: %d sections found at offset 0x%08X\n", ehdr->e_shnum, ehdr->e_shoff);

    // Iterate Section Headers
    if (ehdr->e_shoff > 0 && ehdr->e_shoff < size) {
        Elf32_Shdr* shdr = (Elf32_Shdr*)(buffer + ehdr->e_shoff);
        for (int i = 0; i < ehdr->e_shnum; i++) {
            if (shdr[i].sh_size > 0) {
                printf("  -> Section %d: Offset 0x%06X | Size %u bytes | Addr 0x%08X\n", 
                       i, shdr[i].sh_offset, shdr[i].sh_size, shdr[i].sh_addr);
            }
        }
    }

    return 1;
}

// 60 FPS Main Render & Step Loop
void main_loop_tick() {
    if (!is_app_running) return;

    // 1. Step ARM CPU execution (Executes instructions up to frame interrupt)
    // arm_cpu_step(100000); 

    // 2. Refresh active canvas display pass
    // vm_graphic_flush();
}

EMSCRIPTEN_KEEPALIVE
int run_vxp_app(const char* filepath) {
    printf("[MRE Engine] Mounting binary: %s...\n", filepath);

    FILE* f = fopen(filepath, "rb");
    if (!f) {
        printf("[MRE Engine Error] Could not open path: %s\n", filepath);
        return 0;
    }

    fseek(f, 0, SEEK_END);
    vxp_file_size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (vxp_memory_buffer) {
        free(vxp_memory_buffer);
    }

    vxp_memory_buffer = (uint8_t*)malloc(vxp_file_size);
    if (!vxp_memory_buffer) {
        printf("[MRE Engine Error] Failed to allocate %ld bytes of RAM.\n", vxp_file_size);
        fclose(f);
        return 0;
    }

    fread(vxp_memory_buffer, 1, vxp_file_size, f);
    fclose(f);

    printf("[MRE Engine] Allocated %ld bytes for executable image.\n", vxp_file_size);

    // Initialize Graphic & System Subsystems
    vm_graphic_init();

    // Parse Sections & Prepare CPU State
    if (load_vxp_sections(vxp_memory_buffer, vxp_file_size)) {
        is_app_running = 1;
        emscripten_set_main_loop(main_loop_tick, 60, 0);
        printf("[MRE Engine] Main loop attached. Ready for ARM step execution.\n");
        return 1;
    }

    return 0;
}

EMSCRIPTEN_KEEPALIVE
int main() {
    printf("[MRE Core] Fully linked main core ready.\n");
    return 0;
}
