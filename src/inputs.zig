const std = @import("std");

const data_st = @import("data_structs");
const MainAppSt = data_st.MainAppSt;
const rl = @import("raylib");

pub fn watch_frames(counter: *u64, base: u64, x_times: u16) bool {
    if (counter.* > @divTrunc(base, x_times)) {
        counter.* = 0;
        return true;
    }
    return false;
}

pub fn handle_inputs(base_t: *MainAppSt, listen_to: rl.KeyboardKey) bool {
    var ready: bool = undefined;

    switch (listen_to) {
        .h => {
            base_t.frame_counters.h_left_key += 1;
            if (rl.isKeyDown(.h)) {
                ready = watch_frames(
                    &base_t.frame_counters.h_left_key,
                    base_t.fps,
                    base_t.times_key_hold,
                );
            }
        },
        .l => {
            base_t.frame_counters.l_right_key += 1;
            if (rl.isKeyDown(.l)) {
                ready = watch_frames(
                    &base_t.frame_counters.l_right_key,
                    base_t.fps,
                    base_t.times_key_hold,
                );
            }
        },
        .j => {
            base_t.frame_counters.j_down_key += 1;
            if (rl.isKeyDown(.j)) {
                ready = watch_frames(
                    &base_t.frame_counters.j_down_key,
                    base_t.fps,
                    base_t.times_key_hold,
                );
            }
        },
        .k => {
            base_t.frame_counters.k_up_key += 1;
            if (rl.isKeyDown(.k)) {
                ready = watch_frames(
                    &base_t.frame_counters.k_up_key,
                    base_t.fps,
                    base_t.times_key_hold,
                );
            }
        },

        else => {},
    }

    return ready;
}

test watch_frames {
    var fps: u64 = 0;
    var ret: bool = watch_frames(&fps, 60, 8);
    try std.testing.expect(!ret);

    fps = 8;
    ret = watch_frames(&fps, 60, 8);
    try std.testing.expect(ret);
}
