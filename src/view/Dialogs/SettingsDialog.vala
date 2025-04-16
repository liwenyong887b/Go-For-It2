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
 * A dialog for changing the application's settings.
 */
class GOFI.SettingsDialog : Gtk.Dialog {
    private SettingsManager settings;
    /* GTK Widgets */
    private Gtk.Grid main_layout;

    public SettingsDialog (Gtk.Window? parent, SettingsManager settings) {
        this.set_transient_for (parent);
        this.settings = settings;
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
        main_layout.row_spacing = 10;
        main_layout.column_spacing = 10;

        this.title = _("Settings");
        setup_settings_widgets ();
        this.add_button (_("Close"), Gtk.ResponseType.CLOSE);

        /* Action Handling */
        this.response.connect ((s, response) => {
            if (response == Gtk.ResponseType.CLOSE) {
                this.destroy ();
            }
        });

        this.show_all ();
    }

    private void setup_settings_widgets () {
        int row = 0;
        setup_timer_settings_widgets (main_layout, ref row);
        setup_appearance_settings_widgets (main_layout, ref row);
    }

    private void add_section (Gtk.Grid grid, Gtk.Label label, ref int row) {
        label.set_markup ("<b>%s</b>".printf (label.get_text ()));
        label.halign = Gtk.Align.START;

        grid.attach (label, 0, row, 2, 1);
        row++;
    }

    private void add_option (Gtk.Grid grid, Gtk.Widget label,
                             Gtk.Widget switcher, ref int row)
    {
        label.hexpand = true;
        label.margin_start = 20; // indentation relative to the section label
        label.halign = Gtk.Align.START;

        switcher.hexpand = true;
        switcher.halign = Gtk.Align.FILL;

        if (switcher is Gtk.Switch || switcher is Gtk.Entry) {
            switcher.halign = Gtk.Align.START;
        }

        grid.attach (label, 0, row, 1, 1);
        grid.attach (switcher, 1, row, 1, 1);
        row++;
    }

    private void setup_timer_settings_widgets (Gtk.Grid grid, ref int row) {
        /* Declaration */
        Gtk.Label timer_sect_lbl;
        Gtk.Label task_lbl;
        Gtk.SpinButton task_spin;
        Gtk.Label break_lbl;
        Gtk.SpinButton break_spin;
        Gtk.Label reminder_lbl;
        Gtk.SpinButton reminder_spin;

        /* Instantiation */
        timer_sect_lbl = new Gtk.Label (_("Timer"));
        task_lbl = new Gtk.Label (_("Task duration (minutes)") + ":");
        break_lbl = new Gtk.Label (_("Break duration (minutes)") + ":");
        reminder_lbl = new Gtk.Label (_("Reminder before task ends (seconds)") +":");

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
        add_section (grid, timer_sect_lbl, ref row);
        add_option (grid, task_lbl, task_spin, ref row);
        add_option (grid, break_lbl, break_spin, ref row);
        add_option (grid, reminder_lbl, reminder_spin, ref row);
    }

    private void setup_appearance_settings_widgets (Gtk.Grid grid, ref int row) {
        Gtk.Label appearance_sect_lbl;
        Gtk.Label dark_theme_lbl;
        Gtk.Switch dark_theme_switch;
        Gtk.Label small_icons_lbl;
        Gtk.Switch small_icons_switch;
        Gtk.Label use_text_lbl;
        Gtk.Switch use_text_switch;

        /* Instantiation */
        appearance_sect_lbl = new Gtk.Label (_("Appearance"));
        dark_theme_lbl = new Gtk.Label (_("Dark theme"));
        dark_theme_switch = new Gtk.Switch ();

        small_icons_lbl = new Gtk.Label (_("Use small toolbar icons"));
        small_icons_switch = new Gtk.Switch ();

        use_text_lbl = new Gtk.Label (_("Use text for the activity switcher"));
        use_text_switch = new Gtk.Switch ();

        /* Configuration */
        dark_theme_switch.active = settings.use_dark_theme;
        small_icons_switch.active =
            settings.toolbar_icon_size == Gtk.IconSize.SMALL_TOOLBAR;
        use_text_switch.active = !settings.switcher_use_icons;

        /* Signal Handling */
        dark_theme_switch.notify["active"].connect ( () => {
            settings.use_dark_theme = dark_theme_switch.active;
        });
        small_icons_switch.notify["active"].connect ( () => {
            if (small_icons_switch.active) {
                settings.toolbar_icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            } else {
                settings.toolbar_icon_size = Gtk.IconSize.LARGE_TOOLBAR;
            }
        });
        use_text_switch.notify["active"].connect ( () => {
            settings.switcher_use_icons = !use_text_switch.active;
        });

        small_icons_switch.notify["active"].connect ( () => {
            if (small_icons_switch.active) {
                settings.toolbar_icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            } else {
                settings.toolbar_icon_size = Gtk.IconSize.LARGE_TOOLBAR;
            }
        });

        /* Add widgets */
        add_section (grid, appearance_sect_lbl, ref row);
        add_option (grid, dark_theme_lbl, dark_theme_switch, ref row);
        add_option (grid, small_icons_lbl, small_icons_switch, ref row);
        add_option (grid, use_text_lbl, use_text_switch, ref row);

        if (GOFI.Utils.desktop_hb_status.config_useful ()) {
            setup_csd_settings_widgets (main_layout, ref row);
        }
    }

    private void setup_csd_settings_widgets (Gtk.Grid grid, ref int row) {
        Gtk.Label headerbar_lbl;
        Gtk.Switch headerbar_switch;

        /* Instantiation */
        headerbar_lbl = new Gtk.Label (_("Use a header bar") + (":"));
        headerbar_switch = new Gtk.Switch ();

        /* Configuration */
        headerbar_switch.active = settings.use_header_bar;

        /* Signal Handling */
        headerbar_switch.notify["active"].connect ( () => {
            settings.use_header_bar = headerbar_switch.active;
        });

        /* Add widgets */
        add_option (grid, headerbar_lbl, headerbar_switch, ref row);
    }
}
