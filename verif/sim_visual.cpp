#define SDL_MAIN_HANDLED
#include "Vdocastle_core.h"
#include "verilated.h"

#include <SDL.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;
static vluint64_t sim_time = 0;
double sc_time_stamp() { return static_cast<double>(sim_time); }

static void tick(Vdocastle_core& top) {
    top.clk = 0;
    top.eval();
    ++sim_time;
    top.clk = 1;
    top.eval();
    ++sim_time;
}

static bool atomic_text(const fs::path& path, const std::string& text) {
    const fs::path tmp = path.string() + ".tmp";
    std::ofstream out(tmp, std::ios::binary);
    if (!out) return false;
    out << text;
    out.close();
    std::error_code ec;
    fs::rename(tmp, path, ec);
    if (ec) {
        fs::remove(path, ec);
        fs::rename(tmp, path, ec);
    }
    return !ec;
}

static bool atomic_rgb(const fs::path& path, const std::vector<uint8_t>& rgb) {
    const fs::path tmp = path.string() + ".tmp";
    std::ofstream out(tmp, std::ios::binary);
    if (!out) return false;
    out.write(reinterpret_cast<const char*>(rgb.data()),
              static_cast<std::streamsize>(rgb.size()));
    out.close();
    std::error_code ec;
    fs::rename(tmp, path, ec);
    if (ec) {
        fs::remove(path, ec);
        fs::rename(tmp, path, ec);
    }
    return !ec;
}

static uint64_t checksum(const std::vector<uint8_t>& data) {
    uint64_t h = 1469598103934665603ULL;
    for (uint8_t byte : data) {
        h ^= byte;
        h *= 1099511628211ULL;
    }
    return h;
}

static bool load_rom(Vdocastle_core& top, const fs::path& rom_path, uint8_t game_id) {
    std::ifstream rom_file(rom_path, std::ios::binary);
    if (!rom_file) return false;
    std::vector<uint8_t> rom((std::istreambuf_iterator<char>(rom_file)), {});
    if (rom.size() != 0x48400) return false;

    top.reset = 1;
    top.pause = 0;
    // The live differential profile uses the bounded direct renderer. The
    // CF37201/two-field backend is covered by the dedicated --pcb-framebuffer
    // regression because its full-field build is intentionally much slower.
    top.pcb_fidelity = 0;
    top.pcb_audio_filter = 0;
    top.pcb_framebuffer = 0;
    top.pcb_cursor_irq = 0;
    top.exact_pixel_clock = 1;
    top.ioctl_download = 0;
    top.ioctl_wr = 0;
    top.ioctl_index = 0;
    top.ioctl_addr = 0;
    top.ioctl_dout = 0;
    top.dsw1 = (game_id >= 7) ? 0xff : 0xdf;
    top.dsw2 = 0xff;
    top.joys = 0xff;
    top.joys2 = 0xff;
    top.buttons = 0xff;
    top.system = 0xff;
    for (int i = 0; i < 16; ++i) tick(top);

    top.ioctl_download = 1;
    top.ioctl_index = 0;
    for (std::size_t i = 0; i < rom.size(); ++i) {
        top.ioctl_wr = 1;
        top.ioctl_addr = static_cast<uint32_t>(i);
        top.ioctl_dout = rom[i];
        tick(top);
    }
    top.ioctl_index = 1;
    top.ioctl_addr = 0;
    top.ioctl_dout = game_id;
    top.ioctl_wr = 1;
    tick(top);
    top.ioctl_wr = 0;
    top.ioctl_download = 0;
    top.reset = 0;
    for (int i = 0; i < 32; ++i) tick(top);
    return top.profile_valid_debug && top.game_id_debug == game_id;
}

static bool release_seen(const fs::path& session, unsigned frame) {
    std::ifstream in(session / "release.txt");
    unsigned value = 0;
    return static_cast<bool>(in >> value) && value >= frame;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    std::cerr << "visual participant start\n" << std::flush;
    if (argc < 4) {
        std::cerr << "usage: Vdocastle_core_visual <rom> <game_id> <session> [frames]\n";
        return 2;
    }
    const fs::path rom_path = fs::absolute(argv[1]);
    const unsigned parsed_id = std::stoul(argv[2], nullptr, 0);
    const fs::path session = fs::absolute(argv[3]);
    const unsigned max_frames = argc >= 5 ? std::stoul(argv[4]) : 0;
    const fs::path rtl_dir = session / "rtl";
    fs::create_directories(rtl_dir);

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0) {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << "\n";
        return 1;
    }
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest");
    SDL_Window* window = SDL_CreateWindow(
        "Mr. Do! RTL vs MAME lockstep", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        960, 768, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    if (!window) {
        std::cerr << "SDL_CreateWindow failed: " << SDL_GetError() << "\n";
        SDL_Quit();
        return 1;
    }
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    SDL_Texture* texture = renderer ? SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGB24,
        SDL_TEXTUREACCESS_STREAMING, 240, 192) : nullptr;
    if (!renderer || !texture) {
        std::cerr << "SDL renderer/texture creation failed: " << SDL_GetError() << "\n";
        if (texture) SDL_DestroyTexture(texture);
        if (renderer) SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_RenderSetLogicalSize(renderer, 240, 192);
    SDL_RenderSetIntegerScale(renderer, SDL_TRUE);

    Vdocastle_core top;
    if (!load_rom(top, rom_path, static_cast<uint8_t>(parsed_id))) {
        std::cerr << "ROM load or game descriptor failed\n";
        return 1;
    }
    std::cerr << "visual ROM loaded\n" << std::flush;
    atomic_text(session / "rtl_manifest.txt",
        "width=240\nheight=192\nclock=pixel=819/8192\nvideo=RGB24\n");

    std::vector<uint8_t> frame(240 * 192 * 3, 0);
    std::size_t pixel = 0;
    unsigned frames = 0;
    bool prev_vblank = top.vblank;
    bool quit = false;
    auto pump = [&]() {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) quit = true;
            if (event.type == SDL_KEYDOWN || event.type == SDL_KEYUP) {
                const bool down = event.type == SDL_KEYDOWN;
                const SDL_Keycode key = event.key.keysym.sym;
                if (key == SDLK_c) top.system = down ? static_cast<uint8_t>(top.system & ~0x10)
                                                       : static_cast<uint8_t>(top.system | 0x10);
                if (key == SDLK_1) top.buttons = down ? static_cast<uint8_t>(top.buttons & ~0x08)
                                                        : static_cast<uint8_t>(top.buttons | 0x08);
                if (down && (key == SDLK_ESCAPE)) quit = true;
            }
        }
    };

    while (!quit && (max_frames == 0 || frames < max_frames) && !Verilated::gotFinish()) {
        tick(top);
        pump();
        if (top.ce_pix && !top.hblank && !top.vblank && pixel < frame.size()) {
            frame[pixel * 3 + 0] = top.r;
            frame[pixel * 3 + 1] = top.g;
            frame[pixel * 3 + 2] = top.b;
            ++pixel;
        }
        if (!prev_vblank && top.vblank) {
            ++frames;
            if (pixel != frame.size() / 3) {
                std::cerr << "frame " << frames << " has " << pixel << " visible pixels\n";
                break;
            }
            const uint64_t sum = checksum(frame);
            std::ostringstream stem;
            stem << "frame_" << std::setfill('0') << std::setw(6) << (frames - 1);
            if (!atomic_rgb(rtl_dir / (stem.str() + ".rgb"), frame) ||
                !atomic_text(rtl_dir / (stem.str() + ".ready"), std::to_string(sum) + "\n")) {
                std::cerr << "cannot publish RTL frame " << frames << "\n";
                break;
            }
            SDL_UpdateTexture(texture, nullptr, frame.data(), 240 * 3);
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, nullptr, nullptr);
            SDL_RenderPresent(renderer);
            std::ostringstream title;
            title << "Mr. Do! RTL vs MAME | frame " << frames << " | checksum 0x"
                  << std::hex << sum << std::dec;
            SDL_SetWindowTitle(window, title.str().c_str());
            pixel = 0;

            const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(30);
            while (!quit && !release_seen(session, frames - 1) &&
                   std::chrono::steady_clock::now() < deadline) {
                pump();
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
            if (!release_seen(session, frames - 1) && !quit) {
                std::cerr << "lockstep release timeout at frame " << frames - 1 << "\n";
                break;
            }
        }
        prev_vblank = top.vblank;
    }
    atomic_text(session / "rtl_done.txt", std::to_string(frames) + "\n");
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    top.final();
    return quit ? 0 : (max_frames == 0 || frames == max_frames ? 0 : 1);
}
