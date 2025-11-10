namespace GOFI.DialogUtils {
    public void add_section (Gtk.Grid grid, Gtk.Label label, ref int row) {
        label.set_markup ("<b>%s</b>".printf (label.get_text ()));
        label.halign = Gtk.Align.START;

        grid.attach (label, 0, row, 2, 1);
        row++;
    }

    public void add_option (Gtk.Grid grid, Gtk.Widget label,
                             Gtk.Widget switcher, ref int row, int indent=1)
    {
        label.hexpand = true;
        label.margin_start = indent * 20; // indentation relative to the section label
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

    public void add_explanation (Gtk.Grid grid, Gtk.Label label, ref int row) {
        label.hexpand = true;
        label.margin_start = 20; // indentation relative to the section label
        label.halign = Gtk.Align.START;

        grid.attach (label, 0, row, 2, 1);
        row++;
    }

    public void apply_grid_spacing (Gtk.Grid grid) {
        grid.row_spacing = 6;
        grid.column_spacing = 10;
    }

    public Gtk.Grid create_page_grid () {
        var grid = new Gtk.Grid ();
        apply_grid_spacing (grid);
        return grid;
    }
}
