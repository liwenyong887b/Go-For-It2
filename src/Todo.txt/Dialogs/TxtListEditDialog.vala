/* Copyright 2019 Go For It! developers
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

using GOFI.DialogUtils;

class GOFI.TXT.TxtListEditDialog : Gtk.Dialog {
    private TxtListManager list_manager;
    private ListSettings lsettings;
    private string? old_todo_uri;
    private string? old_done_uri;

    /* GTK Widgets */
    private Gtk.Grid main_layout;
    private Gtk.Label error_label;
    private Gtk.Revealer error_revealer;

    private Gtk.Switch timer_default_switch;
    private Gtk.SpinButton reminder_spin;
    private Gtk.Label timer_sect_lbl;
    private Gtk.Label reminder_lbl1;
    private Gtk.Label reminder_lbl2;
    private Gtk.Label timer_default_lbl;
    private TimerScheduleWidget sched_widget;
    private Gtk.Revealer sched_widget_revealer;

    private Gtk.Label log_timer_lbl;
    private Gtk.Switch log_timer_switch;

    private Gtk.Label name_lbl;
    private Gtk.Entry name_entry;
    private Gtk.Label todo_uri_lbl;
    private Gtk.Label done_uri_lbl;
    private Gtk.FileChooserButton todo_uri_btn;
    private Gtk.FileChooserButton done_uri_btn;
    private bool showing_name_error;
    private bool showing_todo_uri_error;
    private bool showing_done_uri_error;

    private FileConflictDialogWrapper conflict_dialog_wrapper;

    private string todo_uri_text = _("Store to-do tasks in") + ":";
    private string done_uri_text = _("Store completed tasks in") + ":";
    private string name_lbl_text = _("List name") + ":";

    string todo_replace_info = _("Task list location has been changed to \"%s\" (was \"%s\"), but this file already exists.");
    string done_replace_info = _("Completed task file has been changed to \"%s\" (was \"%s\"), but this file already exists.");

    public signal void add_list_clicked (ListSettings lsettings, ConflictChoices? file_operations);

    public TxtListEditDialog (
        Gtk.Window? parent, TxtListManager list_manager,
        ListSettings? lsettings = null
    ) {
        this.set_transient_for (parent);
        this.list_manager = list_manager;
        if (lsettings == null) {
            this.lsettings = new ListSettings.empty ();
            this.lsettings.log_timer_in_txt = true;
            this.title = _("New to-do list");
            this.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            this.add_button (_("Add list"), Gtk.ResponseType.ACCEPT);
            old_todo_uri = null;
            old_done_uri = null;
        } else {
            this.lsettings = lsettings;
            this.title = _("Edit to-do list properties");
            this.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            this.add_button (_("Apply"), Gtk.ResponseType.ACCEPT);
            this.old_todo_uri = lsettings.todo_uri;
            this.old_done_uri = lsettings.done_uri;
        }

        /* Initalization */
        main_layout = new Gtk.Grid ();

        /* General Settigns */
        // Default to minimum possible size
        this.set_default_size (1, 1);
        this.get_content_area ().margin = 10;
        this.get_content_area ().pack_start (main_layout);
        this.set_modal (true);
        main_layout.visible = true;
        main_layout.orientation = Gtk.Orientation.VERTICAL;
        apply_grid_spacing (main_layout);

        setup_settings_widgets ();

        /* Action Handling */
        this.response.connect (on_response);

        set_add_sensitive ();
    }

    private void on_response (int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.ACCEPT:
                var conflicts = collect_file_conflicts ();
                handle_conflicts (conflicts);
                break;
            default:
                this.destroy ();
                break;
        }
    }

    private void set_add_sensitive () {
        set_response_sensitive (Gtk.ResponseType.ACCEPT, check_valid ());
    }

    private void setup_settings_widgets () {
        int row = 0;
        showing_todo_uri_error = false;
        showing_name_error = false;
        error_label = new Gtk.Label ("");
        setup_txt_settings_widgets (main_layout, ref row);
        setup_timer_settings_widgets (main_layout, ref row);
        setup_error_widgets (main_layout, ref row);
    }

    /**
     * Generates a red error message
     */
    private string gen_error_markup (string error) {
        return @"<span foreground=\"red\">$error*</span>";
    }

    private void setup_error_widgets (Gtk.Grid grid, ref int row) {
        error_revealer = new Gtk.Revealer ();

        error_label.hexpand = true;
        error_label.wrap = true;
        error_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        error_label.width_request = 200;
        error_label.use_markup = true;
        error_label.halign = Gtk.Align.START;

        error_revealer.add (error_label);
        error_revealer.set_reveal_child (false);

        grid.attach (error_revealer, 0, row, 3, 1);
        row++;
    }

    private void setup_txt_settings_widgets (Gtk.Grid grid, ref int row) {
        /* Declaration */
        Gtk.Label txt_sect_lbl;
        Gtk.Label log_timer_expl_lbl;

        /* Instantiation */
        txt_sect_lbl = new Gtk.Label ("Todo.txt");

        todo_uri_btn = new Gtk.FileChooserButton (
            _("Select file to store to-do tasks in"), Gtk.FileChooserAction.SAVE
        );
        todo_uri_lbl = new Gtk.Label (todo_uri_text);

        done_uri_btn = new Gtk.FileChooserButton (
            _("Select file to store completed tasks in"), Gtk.FileChooserAction.SAVE
        );
        done_uri_lbl = new Gtk.Label (done_uri_text);

        name_lbl = new Gtk.Label (name_lbl_text);
        name_entry = new Gtk.Entry ();

        log_timer_lbl = new Gtk.Label (_("Log the time spent working on each task") + ":");
        log_timer_expl_lbl = new Gtk.Label (_("This information will be stored in the todo.txt files."));
        log_timer_switch = new Gtk.Switch ();

        /* Configuration */
        todo_uri_lbl.set_line_wrap (false);
        todo_uri_lbl.set_use_markup (true);
        todo_uri_btn.create_folders = true;
        if (old_todo_uri != null) {
            todo_uri_btn.set_uri (old_todo_uri);
        }
        done_uri_lbl.set_line_wrap (false);
        done_uri_lbl.set_use_markup (true);
        done_uri_btn.create_folders = true;
        if (old_done_uri != null) {
            done_uri_btn.set_uri (old_done_uri);
        }

        name_lbl.use_markup = true;
        if (lsettings.name == null) {
            name_entry.text = "";
        } else {
            name_entry.text = lsettings.name;
        }

        log_timer_switch.active = lsettings.log_timer_in_txt;

        /* Signal Handling */
        todo_uri_btn.file_set.connect (on_todo_uri_changed);
        done_uri_btn.file_set.connect (on_done_uri_changed);
        name_entry.notify["text"].connect (on_name_entry_update);
        log_timer_switch.notify["active"].connect (() => {
            lsettings.log_timer_in_txt = log_timer_switch.active;
        });

        add_section (main_layout, txt_sect_lbl, ref row);
        add_option (main_layout, todo_uri_lbl, todo_uri_btn, ref row);
        add_option (main_layout, done_uri_lbl, done_uri_btn, ref row);
        add_option (main_layout, name_lbl, name_entry, ref row);
        add_option (main_layout, log_timer_lbl, log_timer_switch, ref row);
        add_explanation (main_layout, log_timer_expl_lbl, ref row);
    }

    private void on_todo_uri_changed () {
        lsettings.todo_uri = todo_uri_btn.get_file ().get_uri ();
        set_add_sensitive ();
    }

    private void on_done_uri_changed () {
        lsettings.done_uri = done_uri_btn.get_file ().get_uri ();
        set_add_sensitive ();
    }

    private void on_name_entry_update () {
        var name = name_entry.text;
        if (name != "" || lsettings.name != null) {
            lsettings.name = name.strip ();
            set_add_sensitive ();
        }
    }

    private void setup_timer_settings_widgets (Gtk.Grid grid, ref int row) {
        /* Instantiation */
        timer_sect_lbl = new Gtk.Label (_("Timer"));
        timer_default_lbl = new Gtk.Label (_("Use default settings") + (":"));
        reminder_lbl1 = new Gtk.Label (_("Reminder before task ends") +":");
        reminder_lbl2 = new Gtk.Label (_("seconds"));

        timer_default_switch = new Gtk.Switch ();

        sched_widget = new TimerScheduleWidget ();
        sched_widget_revealer = new Gtk.Revealer ();

        // More than ten minutes would not make much sense
        reminder_spin = new Gtk.SpinButton.with_range (0, 600, 1);

        /* Configuration */
        if (lsettings.reminder_time < 0 || lsettings.schedule == null) {
            reminder_spin.value = settings.reminder_time;
            sched_widget.load_schedule (settings.schedule);
            timer_default_switch.active = true;
            sched_widget_revealer.reveal_child = false;
        } else {
            reminder_spin.value = lsettings.reminder_time;
            sched_widget.load_schedule (lsettings.schedule);
            timer_default_switch.active = false;
            sched_widget_revealer.reveal_child = true;
        }

        /* Signal Handling */
        reminder_spin.value_changed.connect (on_reminder_value_changed);
        timer_default_switch.notify["active"].connect (toggle_timer_settings);
        sched_widget.schedule_updated.connect ((sched) => {
            lsettings.schedule = sched;
        });

        /* Add widgets */
        add_section (grid, timer_sect_lbl, ref row);
        add_option (grid, timer_default_lbl, timer_default_switch, ref row);

        // reminder_lbl* and reminder_spin are not added to a Gtk.Revealer as
        // this messes up the horizontal allignment. During testing it somehow
        // also caused an increase in the required minimum width of the dialog.
        add_option (grid, reminder_lbl1, reminder_spin, ref row, 1, reminder_lbl2);

        sched_widget_revealer.add (sched_widget);
        grid.attach (sched_widget_revealer, 0, row, 3, 1);
        row++;
    }

    private void on_reminder_value_changed () {
        lsettings.reminder_time = reminder_spin.get_value_as_int ();
    }

    public override void show_all () {
        base.show_all ();
        if (timer_default_switch.active) {
            reminder_lbl1.hide ();
            reminder_lbl2.hide ();
            reminder_spin.hide ();
        }
    }

    private void toggle_timer_settings () {
        if (timer_default_switch.active) {
            lsettings.reminder_time = -1;
            lsettings.schedule = null;
            reminder_lbl1.hide ();
            reminder_lbl2.hide ();
            reminder_spin.hide ();
            sched_widget_revealer.reveal_child = false;
        } else {
            lsettings.reminder_time = reminder_spin.get_value_as_int ();
            lsettings.schedule = sched_widget.generate_schedule ();
            reminder_lbl1.show ();
            reminder_lbl2.show ();
            reminder_spin.show ();
            sched_widget_revealer.reveal_child = true;
        }
    }

    private bool check_valid () {
        bool is_valid = true;
        string[] error_msgs = {};
        if (lsettings.todo_uri == null || lsettings.done_uri == null) {
            // This setting hasn't been changed by the user
            is_valid = false;
        } else {
            if (!list_manager.todo_uri_available (lsettings)) {
                // The user has selected an invalid directory, so we show an error.
                error_msgs += gen_error_markup (
                    _("The configured to-do file is already in use by another list.")
                );
                is_valid = false;
                if (!showing_todo_uri_error) {
                    todo_uri_lbl.label = gen_error_markup (todo_uri_text);
                    showing_todo_uri_error = true;
                }
            } else if (showing_todo_uri_error) {
                // Restore the label text
                todo_uri_lbl.label = todo_uri_text;
                showing_todo_uri_error = false;
            }

            if (!list_manager.done_uri_available (lsettings)) {
                // The user has selected an invalid directory, so we show an error.
                error_msgs += gen_error_markup (
                    _("Another todo.txt list uses the file chosen to archive completed tasks to to store its to-do tasks.")
                );
                is_valid = false;
                if (!showing_done_uri_error) {
                    done_uri_lbl.label = gen_error_markup (done_uri_text);
                    showing_done_uri_error = true;
                }
            } else if (showing_done_uri_error) {
                // Restore the label text
                done_uri_lbl.label = done_uri_text;
                showing_done_uri_error = false;
            }
        }

        if (lsettings.name == null) {
            // This setting hasn't been changed by the user
            is_valid = false;
        } else if (lsettings.name == "") {
            // The user entered an empty string (or just whitespace)
            error_msgs += gen_error_markup (
                _("Please assign a name to the list.")
            );
            is_valid = false;
            if (!showing_name_error) {
                name_lbl.label = gen_error_markup (name_lbl_text);
                showing_name_error = true;
            }
        } else if (showing_name_error) {
            // Restore the label text
            name_lbl.label = name_lbl_text;
            showing_name_error = false;
        }
        error_revealer.set_reveal_child (!is_valid);
        if (is_valid) {
            return true;
        }
        error_label.label = string.joinv ("\n", error_msgs);
        return false;
    }

    private ConflictChoices? collect_file_conflicts () {
        string new_done_uri = lsettings.done_uri;
        string new_todo_uri = lsettings.todo_uri;

        if (old_done_uri == null && old_todo_uri == null) {
            return null;
        }

        bool todo_txt_updated = old_todo_uri != new_todo_uri;
        bool done_txt_updated = old_done_uri != new_done_uri;

        if (!todo_txt_updated && !done_txt_updated) {
            return null;
        }

        var conflicts = new ConflictChoices ();

        if (old_todo_uri == new_done_uri && old_done_uri == new_todo_uri) {
            conflicts.add_simple_swap (new FileConflict (null, old_todo_uri, new_todo_uri));
            return conflicts;
        }

        if (todo_txt_updated) {
            var txt_conflict_info = todo_replace_info.printf (new_todo_uri, old_todo_uri);
            var conflict = new FileConflict (txt_conflict_info, old_todo_uri, new_todo_uri);
            var todo_txt = File.new_for_uri (new_todo_uri);
            bool todo_exists = todo_txt.query_exists ();
            if (todo_exists) {
                conflicts.add_conflict (conflict);
            } else {
                conflicts.add_simple_replace (conflict);
            }
        }

        if (done_txt_updated) {
            var done_conflict_info = done_replace_info.printf (new_done_uri, old_done_uri);
            var conflict = new FileConflict (done_conflict_info, old_done_uri, new_done_uri);
            var done_txt = File.new_for_uri (new_done_uri);
            bool done_exists = done_txt.query_exists ();
            if (done_exists) {
                conflicts.add_conflict (conflict);
            } else {
                conflicts.add_simple_replace (conflict);
            }
        }

        return conflicts;
    }

    private void handle_conflicts (ConflictChoices? conflicts) {
        if (conflicts == null || conflicts.get_next_conflict () == null) {
            add_list_clicked (lsettings, null);
            return;
        }

        conflict_dialog_wrapper = new FileConflictDialogWrapper ();
        conflict_dialog_wrapper.show_conflict_dialog (this, conflicts);
        conflict_dialog_wrapper.aborted.connect (clean_up_conflict_dialog);
        conflict_dialog_wrapper.choices_made.connect (on_conflict_choices_made);
    }

    private void on_conflict_choices_made (ConflictChoices choices) {
        clean_up_conflict_dialog ();
        add_list_clicked (lsettings, choices);
    }

    private void clean_up_conflict_dialog () {
        conflict_dialog_wrapper.aborted.disconnect (clean_up_conflict_dialog);
        conflict_dialog_wrapper.choices_made.disconnect (on_conflict_choices_made);
        conflict_dialog_wrapper = null;
    }
}
