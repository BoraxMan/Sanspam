// Written in the D Programming language.
/*
 * Sanspam: Mailbox utility to delete/bounce spam on server interactively.
 * Copyright (C) 2018  Dennis Katsonis dennisk@netspace.net.au
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import std.exception;
import std.string;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.conv;
import std.typecons;
import uidefs;

import sanspamexception;

class ExceptionHandler
{
private:
  SanspamException m_exception;

public:
  this(SanspamException e) @safe
  {
    m_exception = e;
  }

  void display()
  {
    WINDOW *exceptionDisplay;
    exceptionDisplay = create_newwin(LINES-7,COLS-2,3,1,ColourPairs.MainBorder, ColourPairs.MainTitleText,"Sanspam has encountered a problem.");
    wbkgd(exceptionDisplay, ' '.to!chtype|COLOR_PAIR(ColourPairs.StandardText));
    
    wattron(exceptionDisplay, COLOR_PAIR(ColourPairs.StandardText));
    wattron(exceptionDisplay, A_BOLD);
    mvwprintw(exceptionDisplay, 1, 1, "ERROR : ".toStringz);
    wattroff(exceptionDisplay, A_BOLD);
    wprintw(exceptionDisplay, m_exception.msg.toStringz);

    wattron(exceptionDisplay, A_BOLD);
    mvwprintw(exceptionDisplay, 2, 1, "Details : ".toStringz);
    wattroff(exceptionDisplay, A_BOLD);
    wprintw(exceptionDisplay, m_exception.getErrorType.toStringz);

    touchwin(exceptionDisplay);
    writeStatusMessage("Press any key to return.");
    wgetch(exceptionDisplay);
    wclear(exceptionDisplay);
    wrefresh(exceptionDisplay);
    delwin(exceptionDisplay);
  }
  
}
