#include <stdio.h>
#include <emscripten.h>

// Handle keypad inputs from JS
EMSCRIPTEN_KEEPALIVE
void send_mre_key(int key_code, int is_pressed) {
    printf("MRE Key Event: Code %d | State: %s\n", key_code, is_pressed ? "DOWN" : "UP");
    // Connect to core key handler here (e.g., vm_key_event(key_code, is_pressed);)
}

// Emscripten main loop tick
void main_loop_tick() {
    // Call core frame update here (e.g., retro_run() or vm_frame_update())
}

EMSCRIPTEN_KEEPALIVE
int run_vxp_app(const char* filepath) {
    printf("MRE Web Engine: Booting application from %s...\n", filepath);
    
    // Set up a 60 FPS main loop for the browser frame
    emscripten_set_main_loop(main_loop_tick, 60, 1);
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int main() {
    printf("MRE Web Engine Ready.\n");
    return 0;
}
