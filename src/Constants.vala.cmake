/* Copyright 2014-2016 Go For It! developers
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
 * The GOFI namespace is a central collection of static constants that are 
 * realted to "Go For It!".
 */
namespace GOFI {
    /* Strings */
    const string APP_NAME = "@APP_NAME@";
    const string EXEC_NAME = "@EXEC_NAME@";
    const string APP_SYSTEM_NAME = "@APP_SYSTEM_NAME@";
    const string APP_ID = "@APP_ID@";
    const string APP_VERSION = "@VERSION@";
    const string ICON_NAME = "@ICON_NAME@";
    const string FILE_CONF = "@FILE_CONF@";
    const string PROJECT_WEBSITE = "@PROJECT_WEBSITE@";
    const string PROJECT_REPO = "@PROJECT_REPO@";
    const string PROJECT_DONATIONS = "@PROJECT_DONATIONS@";
    const string INSTALL_PREFIX = "@INSTALL_PREFIX@";
    const string GETTEXT_PACKAGE = "@GETTEXT_PACKAGE@";
    const string[] TEST_DIRS = {
        "Todo", "todo", ".todo", 
        "Dropbox/Todo", "Dropbox/todo"
    };
}
