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

// This has common UI definitions and functions.

import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;

const int SIGWINCH = 28;
bool termResized = false;

enum ColourPairs : int {
  MainBorder = 1,
    MainTitleText,
    StatusBar,
    MenuFore,
    MenuBack,
    AccountMenuFore,
    AccountMenuBack,
    StandardText
    }

WINDOW *accountSelectionWindow = null;
WINDOW *accountEditWindow = null;
WINDOW *statusWindow = null;
WINDOW *headerWindow = null;

void writeStatusMessage(in string message)
{
  clearStatusMessage;
  wattron(statusWindow, COLOR_PAIR(ColourPairs.StatusBar));
  mvwprintw(statusWindow,0,0,message.toStringz);
  wrefresh(statusWindow);
  wattroff(statusWindow, COLOR_PAIR(ColourPairs.StatusBar));
}

void createStatusWindow()
{
  statusWindow = newwin(1,COLS,LINES-1,0);
  wbkgd(statusWindow, A_NORMAL|ColourPairs.StatusBar);
}
    
void clearStatusMessage()
{
  wmove(statusWindow,0,0);
  wclrtobot(statusWindow);
  wrefresh(statusWindow);
  return;
}


WINDOW* create_newwin(int height, int width, int starty, int startx, ColourPairs border, ColourPairs text, string title = "")
{
  WINDOW* local_win;
  local_win = newwin(height, width, starty, startx);
  wattron(local_win, COLOR_PAIR(border));
  box(local_win, A_NORMAL , A_NORMAL);
  wattroff(local_win, COLOR_PAIR(border));
  wbkgd(local_win, COLOR_PAIR(text));
  if (title != "") {
    wattron(local_win, A_BOLD);
    mvwprintw(local_win, 0,cast(int)((width/2)-(title.length/2)), "%s", title.toStringz);
    wattroff(local_win, A_BOLD);
  }
  wrefresh(local_win);                    // Show that box
  return local_win;
}
