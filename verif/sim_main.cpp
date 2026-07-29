#include "Vdocastle_core.h"
#include "verilated.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

static vluint64_t sim_time = 0;

static void tick(Vdocastle_core& top) {
    top.clk = 0;
    top.eval();
    ++sim_time;
    top.clk = 1;
    top.eval();
    ++sim_time;
}

static bool write_ppm(const std::string& path, const std::vector<uint8_t>& rgb) {
    std::ofstream out(path, std::ios::binary);
    if (!out) return false;
    out << "P6\n240 192\n255\n";
    out.write(reinterpret_cast<const char*>(rgb.data()), static_cast<std::streamsize>(rgb.size()));
    return static_cast<bool>(out);
}

static void put_le16(std::ofstream& out, uint16_t value) {
    const char bytes[2] = {static_cast<char>(value), static_cast<char>(value >> 8)};
    out.write(bytes, 2);
}

static void put_le32(std::ofstream& out, uint32_t value) {
    const char bytes[4] = {
        static_cast<char>(value), static_cast<char>(value >> 8),
        static_cast<char>(value >> 16), static_cast<char>(value >> 24)
    };
    out.write(bytes, 4);
}

static bool write_wav(const std::string& path, const std::vector<int16_t>& samples) {
    std::ofstream out(path, std::ios::binary);
    if (!out) return false;
    const uint32_t data_bytes = static_cast<uint32_t>(samples.size() * sizeof(int16_t));
    out.write("RIFF", 4);
    put_le32(out, 36 + data_bytes);
    out.write("WAVEfmt ", 8);
    put_le32(out, 16);
    put_le16(out, 1);
    put_le16(out, 1);
    put_le32(out, 48000);
    put_le32(out, 48000 * 2);
    put_le16(out, 2);
    put_le16(out, 16);
    out.write("data", 4);
    put_le32(out, data_bytes);
    out.write(reinterpret_cast<const char*>(samples.data()), data_bytes);
    return static_cast<bool>(out);
}

static uint8_t expected_profile(uint8_t game_id) {
    if (game_id <= 1) return 0;
    if (game_id <= 6) return 1;
    if (game_id <= 8) return 2;
    if (game_id == 9) return 1;
    return 0xff;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 5) {
        std::cerr
            << "usage: Vdocastle_core <combined.rom> <game_id> <frames> <frame.ppm>"
            << " [play] [audio.wav] [title.ppm] [attract.ppm]"
            << " [--pcb] [--pcb-audio] [--pcb-framebuffer]"
            << " [--cursor-irq] [--timing-check] [--events=path.csv]\n";
        return 2;
    }

    const std::string rom_path = argv[1];
    const unsigned parsed_id = std::stoul(argv[2], nullptr, 0);
    if (parsed_id > 0xff || expected_profile(static_cast<uint8_t>(parsed_id)) == 0xff) {
        std::cerr << "unsupported game ID: " << parsed_id << "\n";
        return 2;
    }
    const uint8_t game_id = static_cast<uint8_t>(parsed_id);
    const int wanted_frames = std::max(1, std::stoi(argv[3]));
    const std::string ppm_path = argv[4];
    const bool play = argc >= 6 && std::strcmp(argv[5], "play") == 0;
    const std::string wav_path = argc >= 7 && std::strcmp(argv[6], "-") != 0 ? argv[6] : std::string();
    const std::string title_path = argc >= 8 && std::strcmp(argv[7], "-") != 0 ? argv[7] : std::string();
    const std::string attract_path = argc >= 9 && std::strcmp(argv[8], "-") != 0 ? argv[8] : std::string();
    bool pcb = false;
    bool pcb_audio = false;
    bool pcb_framebuffer = false;
    bool cursor_irq = false;
    bool timing_check = false;
    std::string event_path;
    for (int i = 5; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--pcb") pcb = true;
        else if (arg == "--pcb-audio") pcb_audio = true;
        else if (arg == "--pcb-framebuffer") pcb_framebuffer = true;
        else if (arg == "--cursor-irq") cursor_irq = true;
        else if (arg == "--timing-check") timing_check = true;
        else if (arg.rfind("--events=", 0) == 0) event_path = arg.substr(9);
    }

    std::ifstream rom_file(rom_path, std::ios::binary);
    if (!rom_file) {
        std::cerr << "cannot open ROM: " << rom_path << "\n";
        return 2;
    }
    std::vector<uint8_t> rom((std::istreambuf_iterator<char>(rom_file)), {});
    if (rom.size() != 0x48400) {
        std::cerr << "bad ROM size: " << rom.size() << " (expected 295936)\n";
        return 2;
    }

    Vdocastle_core top;
    top.reset = 1;
    top.pause = 0;
    top.pcb_fidelity = pcb;
    top.pcb_audio_filter = pcb_audio;
    top.pcb_framebuffer = pcb_framebuffer;
    top.pcb_cursor_irq = cursor_irq;
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

    if (!top.profile_valid_debug || top.game_id_debug != game_id) {
        std::cerr << "game descriptor failed to latch: valid="
                  << int(top.profile_valid_debug) << " id=" << int(top.game_id_debug) << "\n";
        return 1;
    }
    if (top.profile_debug != expected_profile(game_id)) {
        std::cerr << "wrong profile " << int(top.profile_debug)
                  << " for game ID " << int(game_id) << "\n";
        return 1;
    }

    std::vector<uint8_t> frame(240 * 192 * 3, 0);
    std::size_t pixel = 0;
    int frames = 0;
    bool prev_vblank = true;
    uint64_t cycles = 0;
    uint64_t changed_main = 0;
    uint64_t changed_sub = 0;
    uint64_t changed_sprite = 0;
    uint64_t nonblack_pixels = 0;
    uint64_t audio_nonzero = 0;
    uint64_t adpcm_strobes = 0;
    uint64_t sprite_copies = 0;
    uint64_t cf_writes = 0;
    uint64_t cf_irq_rises = 0;
    uint64_t watchdog_resets = 0;
    uint64_t cursor_rises = 0;
    uint64_t previous_frame_cycle = 0;
    uint64_t shortest_frame = UINT64_MAX;
    uint64_t longest_frame = 0;
    uint64_t longest_wait = 0;
    uint64_t current_wait = 0;
    uint16_t prev_main = top.main_pc_debug;
    uint16_t prev_sub = top.sub_pc_debug;
    uint16_t prev_sprite = top.sprite_pc_debug;
    bool prev_cursor = top.crtc_cursor_debug;
    bool prev_cf_irq = top.cf_irq_debug;
    std::ofstream event_file;
    if (!event_path.empty()) {
        event_file.open(event_path);
        if (!event_file) {
            std::cerr << "cannot open event log: " << event_path << "\n";
            return 2;
        }
        event_file << "cycle,event,value,main_pc,sub_pc,sprite_pc\n";
    }
    auto log_event = [&](const char* event, unsigned value) {
        if (event_file) {
            event_file << cycles << ',' << event << ',' << value << ','
                       << std::hex << top.main_pc_debug << ',' << top.sub_pc_debug
                       << ',' << top.sprite_pc_debug << std::dec << '\n';
        }
    };
    const uint64_t max_cycles = static_cast<uint64_t>(wanted_frames + 2) * 900000ULL;
    std::vector<int16_t> audio_samples;
    audio_samples.reserve(static_cast<std::size_t>(wanted_frames) * 805U);

    while (frames < wanted_frames && cycles < max_cycles && !Verilated::gotFinish()) {
        tick(top);
        ++cycles;

        if (top.main_pc_debug != prev_main) ++changed_main;
        if (top.sub_pc_debug != prev_sub) ++changed_sub;
        if (top.sprite_pc_debug != prev_sprite) ++changed_sprite;
        prev_main = top.main_pc_debug;
        prev_sub = top.sub_pc_debug;
        prev_sprite = top.sprite_pc_debug;

        if (top.main_wait_debug) {
            ++current_wait;
            longest_wait = std::max(longest_wait, current_wait);
        } else {
            current_wait = 0;
        }
        if (top.adpcm_strobe_debug) ++adpcm_strobes;
        if (top.sprite_copy_debug) { ++sprite_copies; log_event("sprite_copy", top.sprite_pc_debug); }
        if (top.cf_write_debug) {
            ++cf_writes;
            log_event("cf_write", (unsigned(top.cf_addr_debug) << 8) | top.cf_data_debug);
        }
        if (top.cf_irq_debug && !prev_cf_irq) {
            ++cf_irq_rises;
            log_event("cf_irq", top.cf_reg2_debug);
        }
        if (top.crtc_write_debug) {
            log_event("crtc_write", (unsigned(top.crtc_reg_debug) << 8) |
                                      top.crtc_data_debug);
        }
        prev_cf_irq = top.cf_irq_debug;
        if (top.watchdog_reset_debug) { ++watchdog_resets; log_event("watchdog_reset", 1); }
        if (top.crtc_cursor_debug && !prev_cursor) { ++cursor_rises; log_event("cursor_rise", 1); }
        prev_cursor = top.crtc_cursor_debug;

        if ((cycles & 1023U) == 0) {
            const int16_t sample = static_cast<int16_t>(top.audio);
            audio_samples.push_back(sample);
            if (sample != 0) ++audio_nonzero;
        }

        if (top.ce_pix && !top.hblank && !top.vblank) {
            if (pixel < 240U * 192U) {
                frame[pixel * 3 + 0] = top.r;
                frame[pixel * 3 + 1] = top.g;
                frame[pixel * 3 + 2] = top.b;
                if (top.r || top.g || top.b) ++nonblack_pixels;
            }
            ++pixel;
        }

        if (!prev_vblank && top.vblank) {
            ++frames;
            if (previous_frame_cycle != 0) {
                const uint64_t frame_cycles = cycles - previous_frame_cycle;
                shortest_frame = std::min(shortest_frame, frame_cycles);
                longest_frame = std::max(longest_frame, frame_cycles);
            }
            previous_frame_cycle = cycles;
            if (pixel != 240U * 192U) {
                std::cerr << "frame " << frames << " has " << pixel
                          << " visible pixels, expected 46080\n";
                return 1;
            }
            if (frames == 122 && !title_path.empty() && !write_ppm(title_path, frame)) {
                std::cerr << "cannot write title PPM: " << title_path << "\n";
                return 1;
            }
            if (frames == 301 && !attract_path.empty() && !write_ppm(attract_path, frame)) {
                std::cerr << "cannot write attract PPM: " << attract_path << "\n";
                return 1;
            }
            if (frames <= 5 || (frames % 30) == 0 || frames == wanted_frames) {
                std::cout << "frame=" << frames
                          << " pixels=" << pixel
                          << " main_bus=0x" << std::hex << top.main_pc_debug
                          << " sub_bus=0x" << top.sub_pc_debug
                          << " sprite_bus=0x" << top.sprite_pc_debug
                          << std::dec << " wait=" << int(top.main_wait_debug)
                          << " psg_ready=0x" << std::hex << int(top.psg_ready_debug)
                          << std::dec << " adpcm=" << int(top.adpcm_busy_debug)
                          << "\n";
            }
            pixel = 0;

            if (play) {
                // Match mame_capture.lua: title at about frame 122, an attract
                // checkpoint three seconds later, then 80 ms coin, 350 ms
                // delay, and 80 ms 1P start.
                top.system = (frames >= 301 && frames < 306) ? 0xdf : 0xff;
                top.buttons = (frames >= 327 && frames < 332) ? 0xf7 : 0xff;
            }
        }
        prev_vblank = top.vblank;
    }

    top.final();
    if (frames != wanted_frames) {
        std::cerr << "simulation stopped after " << frames << " frames\n";
        return 1;
    }
    if (top.renderer_overrun_debug) {
        std::cerr << "sprite line renderer exceeded a scanline budget\n";
        return 1;
    }
    if (changed_main == 0 || changed_sub == 0 || changed_sprite == 0) {
        std::cerr << "one or more CPU buses did not advance\n";
        return 1;
    }
    if (longest_wait > 5000000ULL) {
        std::cerr << "main/sub handshake held WAIT for " << longest_wait << " master clocks\n";
        return 1;
    }
    if (timing_check && frames > 2 &&
        (shortest_frame < 823879ULL || longest_frame > 823882ULL)) {
        std::cerr << "frame cadence outside rational-clock bounds: "
                  << shortest_frame << ".." << longest_frame << " master clocks\n";
        return 1;
    }
    if (timing_check && watchdog_resets != 0) {
        std::cerr << "watchdog reset occurred during timing check\n";
        return 1;
    }
    if (pcb && cf_writes == 0) {
        std::cerr << "PCB sprite path had no CPU3/CF activity: copies="
                  << sprite_copies << " cf_writes=" << cf_writes << "\n";
        return 1;
    }
    if (pcb && top.cf_overrun_debug) {
        std::cerr << "CF37201 descriptor timing overran the external /PL interval\n";
        return 1;
    }
    if (wanted_frames >= 120 && nonblack_pixels == 0) {
        std::cerr << "all captured frames through the title checkpoint were black\n";
        return 1;
    }
    if (!write_ppm(ppm_path, frame)) {
        std::cerr << "cannot write PPM: " << ppm_path << "\n";
        return 1;
    }
    if (!wav_path.empty() && !write_wav(wav_path, audio_samples)) {
        std::cerr << "cannot write WAV: " << wav_path << "\n";
        return 1;
    }

    std::cout << "RESULT id=" << int(game_id)
              << " profile=" << int(top.profile_debug)
              << " frames=" << frames
              << " cycles=" << cycles
              << " nonblack=" << nonblack_pixels
              << " audio_samples_nonzero=" << audio_nonzero
              << " longest_wait=" << longest_wait
              << " adpcm_strobes=" << adpcm_strobes
              << " sprite_copies=" << sprite_copies
              << " cf_writes=" << cf_writes
              << " cf_irqs=" << cf_irq_rises
              << " cf_reg2=0x" << std::hex << int(top.cf_reg2_debug) << std::dec
              << " cursor_rises=" << cursor_rises
              << " watchdog_resets=" << watchdog_resets
              << " frame_cycles=" << (shortest_frame == UINT64_MAX ? 0 : shortest_frame)
              << ".." << longest_frame
              << "\n";
    return 0;
}
