/* Copyright 2014-2017 Go For It! developers
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
class TxtListManager {
    private KeyFile key_file;
    private string list_file;
    private List<ListSettings> settings_list;

    private string[] list_ids {
        owned get {
            return get_string_list ("Lists", "lists", {});
        }
        set {
            set_string_list ("Lists", "lists", value);
        }
    }

    public bool first_run {
        public get;
        private set;
    }

    /**
     * Constructs a SettingsManager object from a configuration file.
     * Reads the corresponding file and creates it, if necessary.
     */
    public TxtListManager (string list_file) {
        this.list_file = list_file;
        // Instantiate the key_file object
        key_file = new KeyFile ();
        first_run = true;

        if (!FileUtils.test (list_file, FileTest.EXISTS)) {
            int dir_exists = DirUtils.create_with_parents (
                GOFI.Utils.config_dir, 0775
            );
            if (dir_exists != 0) {
                error (_("Couldn't create directory: %s"), GOFI.Utils.config_dir);
            }
        } else {
            // If it does exist, read existing values
            first_run = false;
            try {
                key_file.load_from_file (list_file,
                   KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS);
            } catch (Error e) {
                stderr.printf ("Reading %s failed", list_file);
                error ("%s", e.message);
            }
        }

        create_settings_instances ();
    }

    public ListCreateDialog get_creation_dialog (Gtk.Window? parent) {
        return new ListCreateDialog (parent, this);
    }

    /**
     * Checks if the path is used by another TxtList
     * The path must be absolute
     */
    public bool location_available (string path) {
        foreach (string id in list_ids) {
            if (get_todo_txt_location (id) == path) {
                return false;
            }
        }
        return true;
    }

    /**
     * Availability of the location must have been checked in advance
     */
    public void add_list (string location, string name, int task_duration = -1, int break_duration = -1, int reminder_time = -1) {

    }

    public TxtList get_list (string id) {
        var list_settings = settings_list.search<string> (id, (settings, _id) => {
            return strcmp (settings.id, _id);
        }).data;

        return new TxtList (list_settings);
    }

    public unowned List<TodoListInfo> get_list_infos () {
        return settings_list;
    }

    private void create_settings_instances () {
        settings_list = new List<ListSettings> ();

        foreach (string list_id in list_ids) {
            settings_list.append (create_settings_instance (list_id));
        }
    }

    private ListSettings create_settings_instance (string list_id) {
        var list_settings = new ListSettings (
            list_id,
            get_name (list_id),
            get_todo_txt_location (list_id)
        );

        list_settings.task_duration = get_task_duration (list_id);
        list_settings.break_duration = get_break_duration (list_id);
        list_settings.reminder_time = get_reminder_time (list_id);

        return list_settings;
    }

    public void add_settings_instance (string name, string txt_location) {
        var list_settings = new ListSettings (
            "test",
            name,
            txt_location
        );
        connect_settings_signals (list_settings);
        settings_list.append (list_settings);
    }

    private void connect_settings_signals (ListSettings list_settings) {
        list_settings.notify.connect ((object, pspec) => {
            var list = (ListSettings) object;
            switch (pspec.name) {
                case "name":
                    set_name (list.id, list.name);
                    break;
                case "todo-txt-location":
                    set_todo_txt_location (list.id, list.todo_txt_location);
                    break;
                case "task-duration":
                    set_task_duration (list.id, list.task_duration);
                    break;
                case "break-duration":
                    set_task_duration (list.id, list.break_duration);
                    break;
                case "reminder-time":
                    set_task_duration (list.id, list.reminder_time);
                    break;
            }
        });
    }

    public string get_todo_txt_location (string list_id) {
        return get_value (list_id, "location");
    }
    public void set_todo_txt_location (string list_id, string value) {
        set_value (list_id, "location", value);
    }

    public string get_name (string list_id) {
        return get_value (list_id, "name");
    }
    public void set_name (string list_id, string value) {
        set_value (list_id, "name", value);
    }

    /*---Overrides------------------------------------------------------------*/
    public int get_task_duration (string list_id) {
        var duration = get_value (list_id, "task_duration", "1500");
        return int.parse (duration);
    }
    public void set_task_duration (string list_id, int value) {
        set_value (list_id, "task_duration", value.to_string ());
    }

    public int get_break_duration (string list_id) {
        var duration = get_value (list_id, "break_duration", "300");
        return int.parse (duration);
    }
    public void set_break_duration (string list_id, int value) {
        set_value (list_id, "break_duration", value.to_string ());
    }

    public int get_reminder_time (string list_id) {
        var time = get_value (list_id, "reminder_time", "60");
        return int.parse (time);
    }
    public void set_reminder_time (string list_id, int value) {
        set_value (list_id, "reminder_time", value.to_string ());
    }

    /**
     * Provides read access to a setting, given a certain group and key.
     * Public access is granted via the SettingsManager's attributes, so this
     * function has been declared private
     */
    private string get_value (string group, string key, string default = "") {
        try {
            // use key_file, if it has been assigned
            if (key_file != null
                && key_file.has_group (group)
                && key_file.has_key (group, key)) {
                    return key_file.get_value (group, key);
            } else {
                return default;
            }
        } catch (Error e) {
                error ("An error occured while reading the setting"
                    +" %s.%s: %s", group, key, e.message);
        }
    }

    /**
     * Provides write access to a setting, given a certain group key and value.
     * Public access is granted via the SettingsManager's attributes, so this
     * function has been declared private
     */
    private void set_value (string group, string key, string value) {
        if (key_file != null) {
            try {
                key_file.set_value (group, key, value);
                write_key_file ();
            } catch (Error e) {
                error ("An error occured while writing the setting"
                    +" %s.%s to %s: %s", group, key, value, e.message);
            }
        }
    }

    private string[] get_string_list (string group, string key, string[] default = {}) {
        try {
            // use key_file, if it has been assigned
            if (key_file != null
                && key_file.has_group (group)
                && key_file.has_key (group, key)) {
                    return key_file.get_string_list (group, key);
            } else {
                return default;
            }
        } catch (Error e) {
                error ("An error occured while reading the setting"
                    +" %s.%s: %s", group, key, e.message);
        }
    }

    private void set_string_list (string group, string key, string[] string_list) {
        if (key_file != null) {
            try {
                key_file.set_string_list (group, key, string_list);
                write_key_file ();
            } catch (Error e) {
                error (
                    "An error occured while writing the setting" +
                    " %s.%s to {%s}: %s",
                     group, key, string.joinv (", ", string_list), e.message
                );
            }
        }
    }

    private void write_key_file () throws Error {
        GLib.FileUtils.set_contents (list_file, key_file.to_data ());
    }
}
