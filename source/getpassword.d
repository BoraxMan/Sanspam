// Written in the D Programming language.
/*
 * Spaminex: Mailbox utility to delete/bounce spam on server interactively.
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

import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.conv;
import std.typecons;
import spaminexexception;
import uidefs;

string getPassword()
{
  const size_t bufferSize = 512;
  char[bufferSize] text;
  size_t endPosition;
  const char CharDelete = 127;
  size_t charPos;
  int c;

  passwordWindow = create_newwin(3,COLS-10,(LINES/2)-2,5,ColourPairs.PasswordBox, ColourPairs.PasswordBox,"Enter Password", Yes.hasBox);
  wmove(passwordWindow, 1,1);
  noecho();

  for(;;) {
    if (charPos >= bufferSize) {
      throw new SpaminexException("Overflow", "Password entered exceeded allowable maximum");
    }
    c = wgetch(passwordWindow);
    if (c == '\n' || c == '\r') {
      break;
    } else if (c == KEY_BACKSPACE || c == KEY_DC || c == CharDelete) {
      
      if (charPos > 0)
	{
	  --charPos;
	  wprintw(passwordWindow, "\b".toStringz);
	  wprintw(passwordWindow, " ".toStringz);
	  wprintw(passwordWindow, "\b".toStringz);

	}
    } else {
      text[charPos++] = c.to!char;
      wprintw(passwordWindow, "*".toStringz);
    }
  }
	  
  touchwin(passwordWindow);
  wclear(passwordWindow);
  wrefresh(passwordWindow);
  delwin(passwordWindow);
  return text[0..charPos].to!string;
}
