/* Copyright 2014 Manuel Kehl (mank319)
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
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
 * The widget for selecting, displaying and controlling the active task.
 */
public class SettingsDialog : Gtk.Dialog {
    private SettingsManager settings;
    /* GTK Widgets */
    private Gtk.Grid main_layout;
    private Gtk.Label welcome_lbl;
    private Gtk.Label settings_lbl;
    private Gtk.Label directory_lbl;
    private Gtk.FileChooserButton directory_btn;
    private Gtk.Label task_lbl;
    private Gtk.SpinButton task_spin;
    private Gtk.Label break_lbl;
    private Gtk.SpinButton break_spin;
    private Gtk.Label reminder_lbl;
    private Gtk.SpinButton reminder_spin;
    
    public SettingsDialog (bool first_start, SettingsManager settings) {
        this.settings = settings;
        /* Initalization */
        main_layout = new Gtk.Grid ();
        
        /* General Settigns */
        this.set_default_size (450, 500);
        this.get_content_area ().margin = 10;
        this.get_content_area ().pack_start (main_layout);
        main_layout.visible = true;
        main_layout.orientation = Gtk.Orientation.VERTICAL;
        main_layout.row_spacing = 15;
        
        /* Differentiate between "First Start" or "Regular Settings Dialog" */
        if (first_start) {
            this.title = "Welcome";
            setup_welcome ();
            setup_settings_widgets (false);
            this.deletable = false;
            this.add_button ("Let's go!", Gtk.ResponseType.CLOSE);
            // Make sure, that the user does not abort the initial dialog
            this.close.connect ((e) => {
                var new_dia = new SettingsDialog (true, settings);
                new_dia.show ();
            });
        } else {
            this.title = "Settings";
            setup_settings_widgets (true);
            this.add_button ("Close", Gtk.ResponseType.CLOSE);
        }
        
        /* Settings that apply for all widgets in the dialog */
        foreach (var child in main_layout.get_children ()) {
            child.visible = true;
            child.halign = Gtk.Align.START;
        }
        
        /* Action Handling */
        this.response.connect ((s, response) => {
            if (response == Gtk.ResponseType.CLOSE) {
                this.destroy ();
            }
        });
    }
    
    /** 
     * Displays a welcome message with basic information about Go For It!
     */
    private void setup_welcome () {
        welcome_lbl = new Gtk.Label (
"""<b>Welcome to <i>Go For It!</i></b>

Your stylish to-do list with built-in productivity timer.

To develop cool, new features and keep the project 
running, I rely on your <a href="https://github.com/mank319/Go-For-It">contributions</a> and <a href="http://manuel-kehl.de/donations">donations</a>.

Thank you!
""");
        
        /* Configuration */
        welcome_lbl.set_use_markup (true);
        welcome_lbl.set_line_wrap (false);
        
        /* Add widgets */
        main_layout.add (welcome_lbl);
    }
    
    private void setup_settings_widgets (bool advanced) {
        /* Instantiation */
        settings_lbl = new Gtk.Label("""<b>Settings</b>""");
        directory_btn = new Gtk.FileChooserButton ("Todo.txt directory",
            Gtk.FileChooserAction.SELECT_FOLDER);
        directory_lbl = new Gtk.Label (
            """<a href="http://todotxt.com">Todo.txt</a> directory:""");
        
        /* Configuration */
        settings_lbl.set_use_markup (true);
        directory_lbl.set_use_markup (true);
        directory_btn.create_folders = true;
        directory_btn.set_current_folder (settings.todo_txt_location);
        
        /* Signal Handling */
        directory_btn.file_set.connect ((e) => {
            var todo_dir = directory_btn.get_file ().get_path ();
            settings.todo_txt_location = todo_dir;
        });
        
        /* Add widgets */
        main_layout.add (settings_lbl);
        main_layout.add (directory_lbl);
        main_layout.add (directory_btn);
        
        if (advanced) {
            setup_advanced_settings_widgets ();
        }
        
    }
    
    private void setup_advanced_settings_widgets () {
        /* Instantiation */
        task_lbl = new Gtk.Label ("Task Duration in Minutes:");
        break_lbl = new Gtk.Label ("Break Duration in Minutes:");
        reminder_lbl = new Gtk.Label ("Reminder Time in Seconds (0 to disable):");
        // No more than one day: 60 * 24 -1 = 1439
        task_spin = new Gtk.SpinButton.with_range (1, 1439, 1);
        break_spin = new Gtk.SpinButton.with_range (1, 1439, 1);
        // More than ten minutes would not make much sense
        reminder_spin = new Gtk.SpinButton.with_range (0, 600, 1);
        
        /* Configuration */
        task_spin.value = settings.task_duration / 60;
        break_spin.value = settings.break_duration / 60;
        reminder_spin.value = settings.reminder_time;
        
        /* Signal Handling */
        task_spin.value_changed.connect ((e) => {
            settings.task_duration = task_spin.get_value_as_int () * 60;
        });
        break_spin.value_changed.connect ((e) => {
            settings.break_duration = break_spin.get_value_as_int () * 60;
        });
        reminder_spin.value_changed.connect ((e) => {
            settings.reminder_time = reminder_spin.get_value_as_int ();
        });
        
        /* Add widgets */
        main_layout.add (task_lbl);
        main_layout.add (task_spin);
        main_layout.add (break_lbl);
        main_layout.add (break_spin);
        main_layout.add (reminder_lbl);
        main_layout.add (reminder_spin);
    }
}
