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

import mailprotocol;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.array;
import std.conv;
import std.stdio;
import std.string;
import std.format;
import config;
import exceptionhandler;
import spaminexexception;
import mailbox;
import ui;
import uidefs;

version(DMD) {
  import etc.linux.memoryerror;
}

int main()
{
  version(DMD) {
    static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();
  }

  scope(exit) {
    curs_set(1);
    endwin;
  }

  initCurses;
  curs_set(0);

  /* Spaminex is not going to be very useful with a mini terminal.
     Better to quit, than let the user deal with stuck windows.
     Who is going to use a terminal that small, at least for this app?
  */
  if (LINES < 24 || COLS < 80) {
    writeln("Spaminex requires a terminal of at least 80x24 characters");
    return 1;
  }

  mainWindow;
  createStatusWindow;
  string account;
  
  while((account = accountSelectMenu) != "")
    {
      editAccount(account);
      // No text, means the user wanted to quit.
     }

  return 0;
}

