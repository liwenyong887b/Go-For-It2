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

using GOFI.TXT.TxtUtils;

/**
 * This class is responsible for loading, saving and managing the user's tasks.
 * Therefore it offers methods for interacting with the set of tasks in all
 * lists. Editing specific tasks (e.g. removing, renaming) is to be done
 * by addressing the corresponding TaskStore instance.
 */
class GOFI.TXT.TaskManager {
    private ListSettings lsettings;
    // The user's todo.txt related files
    private File todo_txt_dir;
    private File todo_txt;
    private File done_txt;
    public TaskStore todo_store;
    public TaskStore done_store;
    private bool read_only;
    private bool io_failed;

    // refreshing
    private bool refresh_queued;
    private FileWatcher todo_watcher;
    private FileWatcher done_watcher;

    private TxtTask active_task;
    private bool active_task_found;

    string[] default_todos = {
        _("Spread the word about \"%s\"").printf (APP_NAME),
        _("Consider a donation to help the project"),
        _("Consider contributing to the project")
    };

    const string error_implications = _("%s won't save or load from the current todo.txt directory until it is either restarted or another location is chosen.");
    string read_error_message = _("Couldn't read the todo.txt file (%s):") + "\n\n%s\n\n";
    string write_error_message = _("Couldn't save the to-do list (%s):") + "\n\n%s\n\n";
    const string txt_dir_error = _("The path to the todo.txt directory does not point to a directory, but to a file or mountable location. Please change the path in the settings to a suitable directory or remove this file.");

    public signal void active_task_invalid ();
    public signal void refreshing ();
    public signal void refreshed ();

    public TaskManager (ListSettings lsettings) {
        this.lsettings = lsettings;

        // Initialize TaskStores
        todo_store = new TaskStore (false);
        done_store = new TaskStore (true);

        refresh_queued = false;

        load_task_stores ();
        connect_store_signals ();

        /* Signal processing */
        lsettings.notify["todo-txt-location"].connect (load_task_stores);
    }

    public void set_active_task (TxtTask? task) {
        active_task = task;
    }

    public TxtTask? get_next () {
        if (active_task == null) {
            return null;
        }
        return (TxtTask) todo_store.get_item (
            todo_store.get_task_position (active_task) + 1
        );
    }

    public TxtTask? get_prev () {
        if (active_task == null) {
            return null;
        }
        var active_pos = todo_store.get_task_position (active_task);
        if (active_pos == 0) {
            return active_task;
        }
        return (TxtTask) todo_store.get_item (
            active_pos - 1
        );
    }

    public void mark_done (TxtTask task) {
        task.done = true;
    }

    /**
     * To be called when adding a new (unfinished) task.
     */
    public void add_new_task (string task) {
        string _task = task.strip ();
        if (_task != "") {
            var todo_task = new TxtTask.from_simple_txt (_task, false);
            if (!todo_task.valid) {
                return;
            }
            if (settings.new_tasks_on_top) {
                todo_store.prepend_task (todo_task);
            } else {
                todo_store.add_task (todo_task);
            }
        }
    }

    /**
     * Transfers a task from one TaskStore to another.
     */
    private void transfer_task (
        TxtTask task, TaskStore source, TaskStore destination
    ) {
        source.remove_task (task);
        destination.add_task (task);
    }

    /**
     * Deletes all task on the "Done" list
     */
    public void clear_done_store () {
        done_store.clear ();
    }

    /**
     * Reloads all tasks.
     */
    public void refresh () {
        stdout.printf ("Refreshing\n");
        refreshing ();
        load_tasks ();
        refreshed ();
    }

    private bool auto_refresh () {
        if (todo_watcher.being_updated || done_watcher.being_updated) {
            return true;
        }

        refresh ();

        refresh_queued = false;

        return false;
    }

    private void connect_store_signals () {
        // Save data, as soon as something has changed
        todo_store.task_data_changed.connect (save_todo_tasks);
        done_store.task_data_changed.connect (save_done_tasks);

        // Move task from one list to another, if done or undone
        todo_store.task_done_changed.connect (task_done_handler);
        done_store.task_done_changed.connect (task_done_handler);

        // Remove tasks that are no longer valid (user has changed description to "")
        todo_store.task_became_invalid.connect (remove_invalid);
        done_store.task_became_invalid.connect (remove_invalid);
    }

    private void load_task_stores () {
        todo_txt_dir = File.new_for_path (lsettings.todo_txt_location);
        todo_txt = todo_txt_dir.get_child ("todo.txt");
        done_txt = todo_txt_dir.get_child ("done.txt");

        if (
            todo_txt_dir.query_exists () &&
            todo_txt_dir.query_file_type (FileQueryInfoFlags.NONE) != FileType.DIRECTORY
        ) {
            io_failed = true;
            show_error_dialog (txt_dir_error);
            warning (txt_dir_error);
        } else {
            io_failed = false;
        }

        if (todo_txt.query_exists ()) {
            lsettings.add_default_todos = false;
        }

        load_tasks ();

        if (!io_failed) {
            watch_files ();
        }
    }

    private void watch_files () {
        todo_watcher = new FileWatcher (todo_txt);
        done_watcher = new FileWatcher (done_txt);

        todo_watcher.changed.connect (on_file_changed);
        done_watcher.changed.connect (on_file_changed);
    }

    private void on_file_changed () {
        if (!refresh_queued) {
            refresh_queued = true;

            // Reload after 0.5 seconds so we can be relatively sure, that the
            // other application has finished, writing
            GLib.Timeout.add (
                500, auto_refresh, GLib.Priority.DEFAULT_IDLE
            );
        }
    }

    private void task_done_handler (TaskStore source, TxtTask task) {
        if (source == todo_store) {
            transfer_task (task, todo_store, done_store);
            if (task == active_task) {
                active_task_invalid ();
            }
        } else if (source == done_store) {
            transfer_task (task, done_store, todo_store);
        }
    }

    private void remove_invalid (TaskStore store, TxtTask task) {
        store.remove_task (task);
        File todo_file = (store == todo_store) ? todo_txt : done_txt;
        write_task_file (store, todo_file);
    }

    private void load_tasks () {
        // read_only flag, so that "clear ()" does not delete the files' content
        read_only = true;
        todo_store.clear ();
        done_store.clear ();
        active_task_found = active_task == null;
        read_task_file (this.todo_txt, false);
        read_task_file (this.done_txt, true);

        if (lsettings.add_default_todos) {
            add_default_todos ();
        }

        read_only = false;

        if (!active_task_found) {
            active_task_invalid ();
        }
    }

    private void add_default_todos () {
        for (int i = 0; i < default_todos.length; i++) {
            todo_store.add_task (new TxtTask (default_todos[i], false));
        }
        lsettings.add_default_todos = false;
    }

    private void save_todo_tasks () {
        if (!read_only) {
            todo_watcher.watching = false;
            write_task_file (this.todo_store, this.todo_txt);
            todo_watcher.watching = true;
        }
    }

    private void save_done_tasks () {
        if (!read_only) {
            done_watcher.watching = false;
            write_task_file (this.done_store, this.done_txt);
            done_watcher.watching = true;
        }
    }

    private void show_error_dialog (string error_message) {
        var dialog = new Gtk.MessageDialog (
            null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR,
            Gtk.ButtonsType.OK, error_message
        );
        dialog.response.connect ((response_id) => {
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void ensure_file_exists (File file) throws Error {
        // Create file and return if it does not exist
        if (!file.query_exists ()) {
            DirUtils.create_with_parents (todo_txt_dir.get_path (), 0700);
            file.create (FileCreateFlags.NONE);
        }
    }

    string remove_carriage_return (string line) {
        int length = line.length;
        if (length > 0) {
            if (line.get_char (length - 1) == 13) {
                if (length == 1) {
                    return "";
                }
                return line.slice (0, length - 1);
            }
        }

        return line;
    }

    private TxtTask? string_to_task (string _line, bool done_by_default) {
        string line = remove_carriage_return (_line).strip ();

        var task = new TxtTask.from_todo_txt (line, done_by_default);
        if (!task.valid) {
            return null;
        }

        if (!active_task_found && !task.done) {
            if (task.description == active_task.description) {
                active_task_found = true;
                return active_task;
            }
        }

        return task;
    }

    /**
     * Reads tasks from a Todo.txt formatted file.
     */
    private void read_task_file (File file, bool done_by_default) {
        if (io_failed) {
            return;
        }
        stdout.printf ("Reading file: %s\n", file.get_path ());

        // Read data from todo.txt and done.txt files
        try {
            ensure_file_exists (file);
            var stream_in = new DataInputStream (file.read ());
            string line;

            while ((line = stream_in.read_line (null)) != null) {
                TxtTask? task = string_to_task (line, done_by_default);
                if (task != null) {
                    if (task.done) {
                        done_store.add_task (task);
                    } else {
                        todo_store.add_task (task);
                    }
                }
            }
        } catch (Error e) {
            io_failed = true;
            var error_message = read_error_message.printf (file.get_path (), e.message) + error_implications.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);
        }
    }

    /**
     * Saves tasks to a Todo.txt formatted file.
     */
    private void write_task_file (TaskStore store, File file) {
        if (io_failed) {
            return;
        }
        stdout.printf ("Writing file: %s\n", file.get_path ());

        try {
            ensure_file_exists (file);
            var file_io_stream =
                file.replace_readwrite (null, true, FileCreateFlags.NONE);
            var stream_out =
                new DataOutputStream (file_io_stream.output_stream);

            uint n_items = store.get_n_items ();
            for (uint i = 0; i < n_items; i++) {
                TxtTask task = (TxtTask)store.get_item (i);
                stream_out.put_string (task.to_txt (lsettings.log_timer_in_txt) + "\n");
            }
        } catch (Error e) {
            io_failed = true;
            var error_message = write_error_message.printf (file.get_path (), e.message) + error_implications.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);
        }
    }
}
