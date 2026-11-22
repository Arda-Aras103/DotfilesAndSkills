Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

screen_w = Window.GetWidth();
screen_h = Window.GetHeight();

if (screen_h >= 900) {
    margin_x = Math.Int(screen_w * 0.07);
    margin_y = 68;
    line_step = 30;
    font_regular = "JetBrainsMono Nerd Font 13";
    font_bold = "JetBrainsMono Nerd Font Bold 13";
} else {
    margin_x = Math.Int(screen_w * 0.05);
    margin_y = 38;
    line_step = 23;
    font_regular = "JetBrainsMono Nerd Font 11";
    font_bold = "JetBrainsMono Nerd Font Bold 11";
}
if (screen_h < 700) {
    margin_y = 20;
    line_step = 18;
}

bar_border_raw = Image("bar-border.png");
bar_bg_raw = Image("bar-bg.png");
bar_fill_raw = Image("bar-fill.png");

top_accent = Sprite(bar_fill_raw.Scale(screen_w, 2));
top_accent.SetPosition(0, 0, 5);

bot_accent = Sprite(bar_fill_raw.Scale(screen_w, 2));
bot_accent.SetPosition(0, screen_h - 2, 5);

bar_x = margin_x;
bar_w = screen_w - (margin_x * 2);
if (bar_w < 160) {
    bar_w = 160;
}
bar_h = 4;
bar_y = screen_h - 44;

border_sprite = Sprite(bar_border_raw.Scale(bar_w + 2, bar_h + 2));
border_sprite.SetPosition(bar_x - 1, bar_y - 1, 8);

bg_sprite = Sprite(bar_bg_raw.Scale(bar_w, bar_h));
bg_sprite.SetPosition(bar_x, bar_y, 9);

fill_sprite = Sprite(bar_fill_raw.Scale(2, bar_h));
fill_sprite.SetPosition(bar_x, bar_y, 10);

lines_left = [];
lines_right = [];
lines_lr = [];
lines_lg = [];
lines_lb = [];
lines_rr = [];
lines_rg = [];
lines_rb = [];
lines_bold = [];
lines_spacer = [];
lines_revealed = [];
left_sprites = [];
right_sprites = [];
line_left_w = [];
line_right_w = [];
line_count = 0;

fun add_line(left_text, lr, lg, lb, right_text, rr, rg, rb, bold) {
    lines_left[line_count] = left_text;
    lines_right[line_count] = right_text;
    lines_lr[line_count] = lr;
    lines_lg[line_count] = lg;
    lines_lb[line_count] = lb;
    lines_rr[line_count] = rr;
    lines_rg[line_count] = rg;
    lines_rb[line_count] = rb;
    lines_bold[line_count] = bold;
    if (left_text == "" && right_text == "") {
        lines_spacer[line_count] = 1;
    } else {
        lines_spacer[line_count] = 0;
    }
    lines_revealed[line_count] = 0;
    left_sprites[line_count] = Sprite();
    right_sprites[line_count] = Sprite();
    line_left_w[line_count] = 0;
    line_right_w[line_count] = 0;
    line_count++;
}

mode = Plymouth.GetMode();
if (mode == "shutdown" || mode == "reboot") {
    if (mode == "reboot") {
        add_line("REBOOT SEQUENCE...", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
    } else {
        add_line("SHUTDOWN SEQUENCE...", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
    }
    add_line("MACHINE ID: V1 // __HOSTNAME__", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 0);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("USER SESSION ...................................... ", 0.92, 0.92, 0.94, "OFF", 0.95, 0.12, 0.22, 1);
    add_line("AUDIO / VIDEO ..................................... ", 0.92, 0.92, 0.94, "OFF", 0.95, 0.12, 0.22, 1);
    add_line("STORAGE SYNC ...................................... ", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("GPU / CPU HALT .................................... ", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("SYSTEMS OFFLINE.", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
} else {
    add_line("BOOT UP SEQUENCE...", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
    add_line("READY", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 0);
    add_line("FIRMWARE: FEDORA LINUX 44 // __KERNEL__", 0.62, 0.65, 0.72, "", 1.0, 1.0, 1.0, 0);
    add_line("CALIBRATION: INITIATING HARDWARE CHECK", 0.95, 0.68, 0.20, "", 1.0, 1.0, 1.0, 0);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("__KERNEL_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__CPU_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__GPU_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__MEM_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__AUDIO_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__VIDEO_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("__MECH_LINE__", 0.92, 0.92, 0.94, "OK", 0.29, 0.87, 0.50, 1);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("CALIBRATION COMPLETE.", 0.95, 0.68, 0.20, "", 1.0, 1.0, 1.0, 1);
    add_line("ALL SYSTEMS OPERATIONAL.", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 1);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("STATUS UPDATE:", 0.62, 0.65, 0.72, "", 1.0, 1.0, 1.0, 0);
    add_line("MACHINE ID:        V1 // __HOSTNAME__", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 0);
    add_line("LOCATION:          FEDORA 44 (KDE PLASMA)", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 0);
    add_line("CURRENT OBJECTIVE: BOOT COMPLETE", 0.92, 0.92, 0.94, "", 1.0, 1.0, 1.0, 0);
    add_line("", 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, 0);
    add_line("MANKIND IS DEAD.", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
    add_line("BLOOD IS FUEL.", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
    add_line("HELL IS FULL.", 0.95, 0.12, 0.22, "", 1.0, 1.0, 1.0, 1);
}

cursor_img = Image.Text("_", 0.95, 0.12, 0.22, 1.0, font_bold);
cursor_sprite = Sprite(cursor_img);
cursor_sprite.SetPosition(margin_x, margin_y, 15);
cursor_sprite.SetOpacity(1);

last_active_row = -1;

fun reveal_line(idx) {
    if (idx < 0 || idx >= line_count) {
        return;
    }
    if (lines_revealed[idx] == 1) {
        return;
    }
    lines_revealed[idx] = 1;
    if (lines_spacer[idx] == 1) {
        return;
    }

    y = margin_y + (idx * line_step);
    lfont = font_regular;
    if (lines_bold[idx] == 1 && lines_right[idx] == "") {
        lfont = font_bold;
    }
    if (lines_left[idx] != "") {
        limg = Image.Text(lines_left[idx], lines_lr[idx], lines_lg[idx], lines_lb[idx], 1.0, lfont);
        left_sprites[idx].SetImage(limg);
        left_sprites[idx].SetPosition(margin_x, y, 12);
        line_left_w[idx] = limg.GetWidth();
    }
    if (lines_right[idx] != "") {
        rimg = Image.Text(lines_right[idx], lines_rr[idx], lines_rg[idx], lines_rb[idx], 1.0, font_bold);
        right_sprites[idx].SetImage(rimg);
        right_sprites[idx].SetPosition(margin_x + line_left_w[idx], y, 12);
        line_right_w[idx] = rimg.GetWidth();
    }
    last_active_row = idx;
    cursor_x = margin_x + line_left_w[idx] + line_right_w[idx] + 8;
    cursor_sprite.SetPosition(cursor_x, y, 15);
}

tick = 0;
boot_prog = 0.0;
revealed_count = 0;
last_fill_w = 2;

fun boot_progress_cb(duration, progress) {
    if (progress < 0.0) {
        progress = 0.0;
    }
    if (progress > 1.0) {
        progress = 1.0;
    }
    boot_prog = progress;
}
Plymouth.SetBootProgressFunction(boot_progress_cb);

fun refresh_cb() {
    tick++;
    time_target = Math.Int(tick / 6) + 1;
    prog_target = Math.Int(boot_prog * line_count) + 2;
    if (time_target > prog_target) {
        target_lines = time_target;
    } else {
        target_lines = prog_target;
    }
    if (target_lines > line_count) {
        target_lines = line_count;
    }
    while (revealed_count < target_lines) {
        reveal_line(revealed_count);
        revealed_count++;
    }

    target_fill_w = Math.Int(bar_w * boot_prog);
    if (target_fill_w < 2) {
        target_fill_w = 2;
    }
    if (target_fill_w != last_fill_w) {
        fill_sprite.SetImage(bar_fill_raw.Scale(target_fill_w, bar_h));
        last_fill_w = target_fill_w;
    }

    if (Math.Int(tick / 18) % 2 == 0) {
        cursor_sprite.SetOpacity(1);
    } else {
        cursor_sprite.SetOpacity(0);
    }
}
Plymouth.SetRefreshFunction(refresh_cb);

prompt_sprite = Sprite();
bullets_sprite = Sprite();
msg_sprite = Sprite();

fun display_password_cb(prompt, bullets) {
    p_img = Image.Text("AUTH // " + prompt, 0.95, 0.68, 0.20, 1.0, font_bold);
    prompt_sprite.SetImage(p_img);
    prompt_sprite.SetPosition(margin_x, screen_h - 120, 30);
    prompt_sprite.SetOpacity(1);

    dots = "";
    for (i = 0; i < bullets; i++) {
        dots += "*";
    }
    if (dots == "") {
        dots = "_";
    }
    b_img = Image.Text(dots, 0.92, 0.92, 0.94, 1.0, font_bold);
    bullets_sprite.SetImage(b_img);
    bullets_sprite.SetPosition(margin_x, screen_h - 94, 30);
    bullets_sprite.SetOpacity(1);
}
Plymouth.SetDisplayPasswordFunction(display_password_cb);

fun display_normal_cb() {
    prompt_sprite.SetOpacity(0);
    bullets_sprite.SetOpacity(0);
}
Plymouth.SetDisplayNormalFunction(display_normal_cb);

fun message_cb(text) {
    if (text == "") {
        msg_sprite.SetOpacity(0);
        return;
    }
    m_img = Image.Text(text, 0.62, 0.65, 0.72, 1.0, font_regular);
    msg_sprite.SetImage(m_img);
    msg_sprite.SetPosition(margin_x, screen_h - 68, 25);
    msg_sprite.SetOpacity(1);
}
Plymouth.SetMessageFunction(message_cb);
