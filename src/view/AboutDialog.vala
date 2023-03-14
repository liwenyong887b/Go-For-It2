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
public class AboutDialog : Gtk.AboutDialog {
    public AboutDialog () {
        /* Initalization */
        this.set_default_size (450, 500);
        this.get_content_area ().margin = 10;
        this.title = "About Go For It!";
        setup_content ();

        /* Action Handling */
        this.response.connect ((s, response) => {
            if (response == Gtk.ResponseType.DELETE_EVENT) {
                this.destroy ();
            }
        });
    }
    
    /** 
     * Displays a welcome message with basic information about Go For It!
     */
    private void setup_content () {
        program_name = "Go For It!";
        logo_icon_name = "go-for-it";
        
        comments = "A stylish to-do list with built-in productivity timer.";
        website = "http://manuel-kehl.de/projects/go-for-it";

        authors = { "<a href='http://manuel-kehl.de'>Manuel Kehl</a>" };
        artists = { "<a href='http://traumad91.deviantart.com'>Micah Ilbery</a>" };
    }
}
