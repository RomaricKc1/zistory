const clap = @import("clap");

pub const banner =
    \\
    \\Terminal history stats viewer using Raylib. Defaults to "~/.zsh_history_backup"
    \\meaning that you have to create a backup of your history file in case anything
    \\goes wrong. I don't think it will, but better be safe.
    \\
    \\Options:
;

pub const params = clap.parseParamsComptime(
    \\-L, --window_width            <WIDTH>             window width (default 800)
    \\-l, --window_height           <HEIGHT>            window height (default 540)
    \\-s, --fps                     <FPS>               fps count (default 60)
    \\-n, --cmd_cnt                 <CMD_CNT>           number of entries to read from the history file (default 103)
    \\-t, --time                    <TIME>              timestamp from which to read the entries (default current time)
    \\-k, --elm_on_list_cnt         <LIST_SHOWN_CNT>    the number of the list's entries to show at once
    \\-f, --history_file            <HIST_FILE>         your history file. default for zsh -> "~/.zsh_history", make a backup ( "~/.zsh_history_backup") for it first
    \\-q, --exit_key                <EXIT_KEY>          key used to exit. default ('a')
    \\-v, --version                 Display version information.
    \\-h, --help                    Display this help and exit.
);

// Style options for the help text
pub const help_options = clap.HelpOptions{
    .spacing_between_parameters = 0,
    .indent = 4,
    .description_on_new_line = false,
};

/// Argument parsers
pub const parsers = .{
    .WIDTH = clap.parsers.int(u16, 0),
    .HEIGHT = clap.parsers.int(u16, 0),
    .FPS = clap.parsers.int(u16, 0),
    .EXIT_KEY = clap.parsers.int(u8, 0),
    .TIME = clap.parsers.int(u64, 0),
    .CMD_CNT = clap.parsers.int(u16, 0),
    .LIST_SHOWN_CNT = clap.parsers.int(u8, 0),
    .HIST_FILE = clap.parsers.string,
};
