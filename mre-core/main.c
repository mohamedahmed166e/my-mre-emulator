#include <stdio.h>
#include <emscripten.h>

EMSCRIPTEN_KEEPALIVE
void send_mre_key(int key_code, int is_pressed) {
    printf("Key Event: Code %d | State: %d\n", key_code, is_pressed);
}

void main_loop_tick() {
    // Emulator frame tick logic goes here
}

EMSCRIPTEN_KEEPALIVE
int run_vxp_app(const char* filepath) {
    printf("MRE Engine: Loading %s...\n", filepath);
    
    // simulate_infinite_loop = 0 prevents "Uncaught unwind" exceptions
    emscripten_set_main_loop(main_loop_tick, 60, 0);
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int main() {
    printf("MRE Core Ready.\n");
    return 0;
}
