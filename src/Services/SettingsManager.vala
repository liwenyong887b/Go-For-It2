/* Copyright 2014-2019 Go For It! developers
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* Go For It! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Go For It!. If not, see http://www.gnu.org/licenses/.
*/

/**
 * A class that handles access to settings in a transparent manner.
 * Its main motivation is the option of easily replacing Glib.KeyFile with
 * another settings storage mechanism in the future.
 */
private class GOFI.SettingsManager : Object {

    private GLib.Settings _settings;
    private GLib.Settings timer_settings;
    private GLib.Settings saved_state;

    /*
     * A list of settings values with their corresponding access methods.
     * The "heart" of the SettingsManager class.
     */

    // Whether or not Go For It! has been started for the first time
    public bool first_start = false;

    /*---GROUP:Todo.txt-------------------------------------------------------*/
    public string todo_txt_location {
        owned get { return ""; }
    }
    /*---GROUP:Behavior-------------------------------------------------------*/
    public bool new_tasks_on_top {
        public get;
        public set;
    }
    /*---GROUP:Timer----------------------------------------------------------*/
    const string KEY_TASK_DURATION = "task-duration";
    const string KEY_BREAK_DURATION = "break-duration";
    const string KEY_LBREAK_DURATION = "long-break-duration";
    const string KEY_POMODORO_PERIOD = "pomodoro-period";
    const string KEY_REMINDER_TIME = "reminder-time";
    const string KEY_TIMER_MODE = "timer-mode";
    const string KEY_SCHEDULE = "schedule";
    const string KEY_RESUME_TASKS_AFTER_BREAK = "resume-tasks-after-break";
    const string KEY_RESET_TIMER_ON_TASK_SWITCH = "reset-timer-on-task-switch";

    public int task_duration {
        get {
            int _task_duration = timer_settings.get_int (KEY_TASK_DURATION);
            if (_task_duration <= 0) {
                _task_duration = get_default_timer_int (KEY_TASK_DURATION);
            }
            return _task_duration;
        }
        set {
            timer_settings.set_int (KEY_TASK_DURATION, value);
            build_schedule ();
            timer_duration_changed ();
        }
    }
    public int break_duration {
        get {
            int _break_duration = timer_settings.get_int (KEY_BREAK_DURATION);
            if (_break_duration <= 0) {
                _break_duration = get_default_timer_int (KEY_BREAK_DURATION);
            }
            return _break_duration;
        }
        set {
            timer_settings.set_int (KEY_BREAK_DURATION, value);
            build_schedule ();
            timer_duration_changed ();
        }
    }
    public int long_break_duration {
        get {
            int _long_break_duration = timer_settings.get_int (KEY_LBREAK_DURATION);
            if (_long_break_duration <= 0) {
                _long_break_duration = get_default_timer_int (KEY_LBREAK_DURATION);
            }
            return _long_break_duration;
        }
        set {
            timer_settings.set_int (KEY_LBREAK_DURATION, value);
            build_schedule ();
            timer_duration_changed ();
        }
    }
    public int pomodoro_period {
        get {
            int _pomodoro_period = timer_settings.get_int (KEY_POMODORO_PERIOD);
            if (_pomodoro_period < 1) {
                _pomodoro_period = get_default_timer_int (KEY_POMODORO_PERIOD);
            }
            return _pomodoro_period;
        }
        set {
            timer_settings.set_int (KEY_POMODORO_PERIOD, value);
            build_schedule ();
            timer_duration_changed ();
        }
    }

    public int reminder_time {
        get { return _reminder_time; }
        set {
            if (value < 0) {
                _reminder_time = get_default_timer_int (KEY_REMINDER_TIME);
            } else {
                _reminder_time = value;
            }
        }
    }
    int _reminder_time;

    public bool reminder_active {
        get {
            return (_reminder_time > 0);
        }
    }

    public TimerMode timer_mode {
        public get;
        public set;
    }

    public Schedule schedule {
        get {
            return _schedule;
        }
        set {
            _schedule.import_raw (value.export_raw ());
            save_schedule ();
            timer_duration_changed ();
        }
    }
    Schedule _schedule;

    public bool resume_tasks_after_break {
        get;
        set;
    }

    public bool reset_timer_on_task_switch {
        get;
        set;
    }

    /*---GROUP:UI-------------------------------------------------------------*/
    public bool use_header_bar {
        get {
            switch (prefers_header_bar) {
                case OverrideBool.TRUE:
                    return true;
                case OverrideBool.FALSE:
                    return false;
                default:
                    return GOFI.Utils.desktop_hb_status.use_feature (true);
            }
        }
        set {
            if (value) {
                prefers_header_bar = OverrideBool.TRUE;
            } else {
                prefers_header_bar = OverrideBool.FALSE;
            }
        }
    }
    public OverrideBool prefers_header_bar {
        get;
        set;
    }
    public ColorScheme color_scheme {
        get {
            return _color_scheme;
        }
        set {
            use_dark_theme_changed (use_dark_theme);
        }
    }
    ColorScheme _color_scheme;
    public bool use_dark_theme {
        get {
            switch (_color_scheme) {
                case ColorScheme.LIGHT:
                    return false;
                case ColorScheme.DARK:
                    return true;
                default:
                    return system_theme_is_dark;
            }
        }
    }
    public bool system_theme_is_dark {
        get {
            return _system_theme_is_dark;
        }
        set {
            _system_theme_is_dark = value;
            if (_color_scheme == ColorScheme.DEFAULT) {
                use_dark_theme_changed (value);
            }
        }
    }
    bool _system_theme_is_dark = false;
    public Theme theme {
        get {
            var theme_str = _settings.get_string ("theme");
            var theme_val = Theme.from_string (theme_str);
            if (theme_val != Theme.INVALID) {
                return theme_val;
            }

            warning ("Unknown theme setting: %s", theme_str);
            return Theme.from_string (
                _settings.get_default_value ("theme").get_string ()
            );
        }
        set {
            _settings.set_string ("theme", value.to_string ());
            theme_changed (value);
        }
    }
    public Gtk.IconSize toolbar_icon_size {
        get {
            if (_use_small_toolbar_icons) {
                return Gtk.IconSize.SMALL_TOOLBAR;
            }
            return Gtk.IconSize.LARGE_TOOLBAR;
        }
    }
    public bool use_small_toolbar_icons {
        get {
            return _use_small_toolbar_icons;
        }
        set {
            _use_small_toolbar_icons = value;
            toolbar_icon_size_changed (toolbar_icon_size);
        }
    }
    bool _use_small_toolbar_icons;
    public bool switcher_use_icons {
        get {
            return _switcher_use_icons;
        }
        set {
            _switcher_use_icons = value;
            switcher_use_icons_changed (value);
        }
    }
    bool _switcher_use_icons;
    /*---GROUP:LISTS----------------------------------------------------------*/
    public List<ListIdentifier?> lists {
        owned get {
            List<ListIdentifier?> identifiers = new List<ListIdentifier?> ();

            var lists_value = _settings.get_value ("lists");
            var n_lists = lists_value.n_children ();

            for (size_t i = 0; i < n_lists; i++) {
                string provider, id;
                lists_value.get_child (i, "(ss)", out provider, out id);
                if (provider != "" && id != "") {
                    identifiers.prepend (new ListIdentifier (provider, id));
                }
            }
            return identifiers;
        }
        set {
            Variant[] _lists = {};
            foreach (unowned ListIdentifier identifier in value) {
                _lists += new Variant.tuple ({
                    new Variant.string (identifier.provider),
                    new Variant.string (identifier.id)
                });
            }
            _settings.set_value ("lists", new Variant.array (new VariantType ("(ss)"), _lists));
        }
    }

    /*---Saved state----------------------------------------------------------*/
    public void set_window_position (int x, int y) {
        saved_state.set ("window-position", "(ii)", x, y);
    }
    public void get_window_position (out int x, out int y) {
        saved_state.get ("window-position", "(ii)", out x, out y);
    }
    public void set_window_size (int width, int height) {
        saved_state.set ("window-size", "(ii)", width, height);
    }
    public void get_window_size (out int width, out int height) {
        saved_state.get ("window-size", "(ii)", out width, out height);
    }
    public ListIdentifier? list_last_loaded {
        owned get {
            string provider, id;
            saved_state.get ("last-loaded-list", "(ss)", out provider, out id);
            if (provider != "" && id != "") {
                return new ListIdentifier (provider, id);
            }
            return null;
        }
        set {
            if (value == null) {
                saved_state.set ("last-loaded-list", "(ss)", "", "");
            } else {
                saved_state.set ("last-loaded-list", "(ss)", value.provider, value.id);
            }
        }
    }

    /* Signals */
    public signal void todo_txt_location_changed ();
    public signal void timer_duration_changed ();
    public signal void theme_changed (Theme theme);
    public signal void use_dark_theme_changed (bool use_dark);
    public signal void toolbar_icon_size_changed (Gtk.IconSize size);
    public signal void switcher_use_icons_changed (bool use_icons);

    public SettingsManager () {
        init_with_backend (null);
    }

    private void init_with_backend (GLib.SettingsBackend? backend) {
        _schedule = new Schedule ();
        if (backend != null) {
            _settings = new GLib.Settings.with_backend (GOFI.APP_ID + ".settings", backend);
            timer_settings = new GLib.Settings.with_backend (GOFI.APP_ID + ".timer", backend);
            saved_state = new GLib.Settings.with_backend (GOFI.APP_ID + ".saved-state", backend);
        } else {
            _settings = new GLib.Settings (GOFI.APP_ID + ".settings");
            timer_settings = new GLib.Settings (GOFI.APP_ID + ".timer");
            saved_state = new GLib.Settings (GOFI.APP_ID + ".saved-state");
        }

        bind_settings ();
    }

// Broken due to bad gio vapi bindings
/**/
    public SettingsManager.key_file_backend (string path) {
        var key_file_backend = GLib.SettingsBackend.keyfile_settings_backend_new (path, "/", null);
        init_with_backend (key_file_backend);
    }
/**/

    private void bind_settings () {
        var sbf = GLib.SettingsBindFlags.DEFAULT;
        _settings.bind ("new-tasks-on-top", this, "new_tasks_on_top", sbf);
        _settings.bind ("switcher-use-icons", this, "switcher_use_icons", sbf);
        _settings.bind ("small-toolbar-icons", this, "use_small_toolbar_icons", sbf);
        _settings.bind ("color-scheme", this, "color_scheme", sbf);
        _settings.bind ("use-header-bar", this, "prefers_header_bar", sbf);

        timer_settings.bind (KEY_REMINDER_TIME, this, "reminder_time", sbf);
        timer_settings.bind (KEY_TIMER_MODE, this, "timer_mode", sbf);
        timer_settings.bind (KEY_RESUME_TASKS_AFTER_BREAK, this, "resume_tasks_after_break", sbf);
        timer_settings.bind (KEY_RESET_TIMER_ON_TASK_SWITCH, this, "reset_timer_on_task_switch", sbf);

        if (timer_mode == TimerMode.CUSTOM) {
            restore_saved_schedule ();
        } else {
            build_schedule ();
        }
    }

    private void restore_saved_schedule () {
        _schedule.load_variant (timer_settings.get_value (KEY_SCHEDULE));
        if (!_schedule.valid) {
            warning (
                "Timer-mode is set to custom, but no schedule has been configured!" +
                "populating schedule with a pomodoro schedule!"
            );
            build_pomodoro_schedule ();
        }
    }

    private void save_schedule () {
        timer_settings.set_value (KEY_SCHEDULE, _schedule.to_variant ());
    }

    private int get_default_timer_int (string key) {
        return timer_settings.get_default_value (key).get_int32 ();
    }

    private void build_schedule () {
        switch (timer_mode) {
            case TimerMode.SIMPLE:
                _schedule.import_raw ({task_duration, break_duration});
                return;
            case TimerMode.POMODORO:
                build_pomodoro_schedule ();
                return;
            default:
                return;
        }
    }

    private void build_pomodoro_schedule () {
        var arr_size = pomodoro_period * 2;
        var durations = new int[arr_size];
        for (int i = 0; i < arr_size - 2; i += 2) {
            durations[i] = task_duration;
            durations[i+1] = break_duration;
        }
        durations[arr_size - 2] = task_duration;
        durations[arr_size - 1] = long_break_duration;
        _schedule.import_raw (durations);
    }
}

namespace GOFI.LegacySettings {

    /*
     * A list of constants that define settings group names
     */
    private const string GROUP_TODO_TXT = "Todo.txt";
    private const string GROUP_BEHAVIOR = "Behavior";
    private const string GROUP_TIMER = "Timer";
    private const string GROUP_UI = "Interface";
    private const string GROUP_LISTS = "Lists";

    private void importtimer_settings (KeyFile key_file) throws GLib.KeyFileError {
        if (!key_file.has_group (GROUP_TIMER)) {
            return;
        }

        if (key_file.has_key (GROUP_TIMER, "task_duration")) {
            settings.task_duration =
                key_file.get_integer (GROUP_TIMER, "task_duration");
        }
        if (key_file.has_key (GROUP_TIMER, "break_duration")) {
            settings.break_duration =
                key_file.get_integer (GROUP_TIMER, "break_duration");
        }
        if (key_file.has_key (GROUP_TIMER, "long_break_duration")) {
            settings.long_break_duration =
                key_file.get_integer (GROUP_TIMER, "long_break_duration");
        }
        if (key_file.has_key (GROUP_TIMER, "reminder_time")) {
            settings.reminder_time =
                key_file.get_integer (GROUP_TIMER, "reminder_time");
        }
        if (key_file.has_key (GROUP_TIMER, "pomodoro_period")) {
            settings.pomodoro_period =
                key_file.get_integer (GROUP_TIMER, "pomodoro_period");
        }
        if (key_file.has_key (GROUP_TIMER, "resume_tasks_after_break")) {
            settings.resume_tasks_after_break =
                key_file.get_boolean (GROUP_TIMER, "resume_tasks_after_break");
        }
        if (key_file.has_key (GROUP_TIMER, "reset_timer_on_task_switch")) {
            settings.reset_timer_on_task_switch =
                key_file.get_boolean (GROUP_TIMER, "reset_timer_on_task_switch");
        }
        if (key_file.has_key (GROUP_TIMER, "timer_mode")) {
            var timer_mode = TimerMode.from_string (key_file.get_value (GROUP_TIMER, "timer_mode"));
            if (timer_mode == TimerMode.CUSTOM && key_file.has_key (GROUP_TIMER, "schedule")) {
                var schedule = new Schedule ();
                var durations = key_file.get_integer_list (GROUP_TIMER, "schedule");
                if (durations.length >= 2) {
                    schedule.import_raw (durations);
                    return;
                }
            }
            settings.timer_mode = timer_mode;
        } else {
            settings.timer_mode = TimerMode.SIMPLE;
        }
    }

    private void import_ui_settings (KeyFile key_file) throws GLib.KeyFileError {
        if (!key_file.has_group (GROUP_UI)) {
            return;
        }

        if (key_file.has_key (GROUP_UI, "use_header_bar")) {
            if (key_file.get_boolean (GROUP_UI, "use_header_bar")) {
                settings.prefers_header_bar = OverrideBool.TRUE;
            } else {
                settings.prefers_header_bar = OverrideBool.FALSE;
            }
        }
        if (key_file.has_key (GROUP_UI, "use_dark_theme")) {
            if (key_file.get_boolean (GROUP_UI, "use_dark_theme")) {
                settings.color_scheme = ColorScheme.DARK;
            } else {
                settings.color_scheme = ColorScheme.LIGHT;
            }
        }
        if (key_file.has_key (GROUP_UI, "switcher_label_type")) {
            settings.switcher_use_icons =
                key_file.get_value (GROUP_UI, "switcher_label_type") != "text";
        }
        if (key_file.has_key (GROUP_UI, "theme")) {
            settings.theme =
                Theme.from_string (key_file.get_value (GROUP_UI, "theme"));
        }
        if (key_file.has_key (GROUP_UI, "toolbar_icon_size")) {
            settings.use_small_toolbar_icons =
                key_file.get_value (GROUP_UI, "toolbar_icon_size") == "small";
        }

        int x, y, width, height;
        width = key_file.get_integer (GROUP_UI, "win_width");
        height = key_file.get_integer (GROUP_UI, "win_height");

        settings.set_window_size (width, height);

        x = key_file.get_integer (GROUP_UI, "win_x");
        y = key_file.get_integer (GROUP_UI, "win_y");

        settings.set_window_position (x, y);
    }

    private void import_list_settings (KeyFile key_file) throws GLib.KeyFileError {
        if (!key_file.has_group (GROUP_LISTS)) {
            return;
        }

        if (key_file.has_key (GROUP_LISTS, "lists")) {
            List<ListIdentifier?> identifiers = new List<ListIdentifier?> ();
            var strs = key_file.get_string_list (GROUP_LISTS, "lists");

            foreach (string id_str in strs) {
                var identifier = ListIdentifier.from_string (id_str);
                if (identifier != null) {
                    identifiers.prepend ((owned) identifier);
                } else {
                    warning ("Can't decode list information! (%s)", id_str);
                }
            }
            settings.lists = identifiers;
        }

        if (key_file.has_key (GROUP_LISTS, "last")) {
            var encoded_id = key_file.get_value (GROUP_LISTS, "last");
            ListIdentifier list_identifier = null;
            if (encoded_id != "" && (list_identifier = ListIdentifier.from_string (encoded_id)) != null) {
                settings.list_last_loaded = list_identifier;
            }
        }
    }

    private void import_behavior_settings (KeyFile key_file) throws GLib.KeyFileError {
        if (!key_file.has_group (GROUP_BEHAVIOR)) {
            return;
        }

        if (key_file.has_key (GROUP_BEHAVIOR, "new_tasks_on_top")) {
            settings.new_tasks_on_top = key_file.get_boolean (GROUP_BEHAVIOR, "new_tasks_on_top");
        }
    }

    internal static void import_settings () {
        // Instantiate the key_file object
        var key_file = new KeyFile ();

        if (FileUtils.test (GOFI.Utils.config_file, FileTest.EXISTS)) {
            // If it does exist, read existing values
            try {
                key_file.load_from_file (GOFI.Utils.config_file,
                   KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS);
            } catch (Error e) {
                stderr.printf ("Reading %s failed", GOFI.Utils.config_file);
                warning ("%s", e.message);
                return;
            }
        } else {
            return;
        }

        try {
            import_list_settings (key_file);
            importtimer_settings (key_file);
            import_ui_settings (key_file);
            import_behavior_settings (key_file);
        } catch (Error e) {
            warning ("An error occured while importing the settings from"
                +" %s: %s", GOFI.Utils.config_file, e.message);
        }
    }
}

private enum GOFI.OverrideBool {
    DEFAULT = 0,
    FALSE = 1,
    TRUE = 2;
}

private enum GOFI.ColorScheme {
    DEFAULT = 0,
    LIGHT = 1,
    DARK = 2;
}

private enum GOFI.TimerMode {
    SIMPLE = 0,
    POMODORO = 1,
    CUSTOM = 2;

    public const string STR_SIMPLE = "simple";
    public const string STR_POMODORO = "pomodoro";
    public const string STR_CUSTOM = "custom";

    public const TimerMode DEFAULT_TIMER_MODE = TimerMode.SIMPLE;

    public static TimerMode from_string (string str) {
        switch (str) {
            case STR_SIMPLE: return SIMPLE;
            case STR_POMODORO: return POMODORO;
            case STR_CUSTOM: return CUSTOM;
            default: return DEFAULT_TIMER_MODE;
        }
    }

    public string to_string () {
        switch (this) {
            case SIMPLE:
                return STR_SIMPLE;
            case POMODORO:
                return STR_POMODORO;
            case CUSTOM:
                return STR_CUSTOM;
            default:
                assert_not_reached();
        }
    }
}
