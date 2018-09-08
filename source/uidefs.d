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

// This has common UI definitions and functions.

import deimos.ncurses;
import deimos.ncurses.menu;
import std.conv;
import std.string;
import std.typecons;

__gshared string _version = "0.1.3";
__gshared const int SIGWINCH = 28;
__gshared int messageWaitDuration = 1000;
__gshared bool termResized = false;
__gshared alias ncursesColourPair = Tuple!(short, "foreground", short, "background");

WINDOW *accountSelectionWindow = null;
WINDOW *accountEditWindow = null;
WINDOW *statusWindow = null;
WINDOW *headerWindow = null;
WINDOW *inspectorWindow = null;
WINDOW *passwordWindow = null;

enum ColourPairs : short {
  MainBorder = 1,
    MainTitleText,
    StatusBar,
    MenuFore,
    MenuBack,
    AccountMenuFore,
    AccountMenuBack,
    StandardText,
    GreenText,
    RedText,
    PasswordBox
    }

ncursesColourPair[ColourPairs] neon;
ncursesColourPair[ColourPairs] blue;
ncursesColourPair[ColourPairs] white;

static this()
{
  neon[ColourPairs.MainTitleText] = ncursesColourPair(COLOR_MAGENTA, COLOR_BLACK);
  neon[ColourPairs.MainBorder] = ncursesColourPair(COLOR_CYAN, COLOR_BLACK);
  neon[ColourPairs.StatusBar] = ncursesColourPair(COLOR_WHITE, COLOR_RED);
  neon[ColourPairs.MenuFore] = ncursesColourPair(COLOR_YELLOW, COLOR_BLUE);
  neon[ColourPairs.MenuBack] = ncursesColourPair(COLOR_GREEN, COLOR_BLACK);
  neon[ColourPairs.AccountMenuFore] = ncursesColourPair(COLOR_WHITE, COLOR_RED);
  neon[ColourPairs.AccountMenuBack] = ncursesColourPair(COLOR_WHITE, COLOR_BLACK);
  neon[ColourPairs.StandardText] = ncursesColourPair(COLOR_WHITE, COLOR_BLACK);
  neon[ColourPairs.GreenText] = ncursesColourPair(COLOR_GREEN, COLOR_BLACK);
  neon[ColourPairs.RedText] = ncursesColourPair(COLOR_RED, COLOR_BLACK);
  neon[ColourPairs.PasswordBox] = ncursesColourPair(COLOR_YELLOW, COLOR_BLUE);

  blue[ColourPairs.MainTitleText] = ncursesColourPair(COLOR_WHITE, COLOR_BLUE);
  blue[ColourPairs.MainBorder] = ncursesColourPair(COLOR_YELLOW, COLOR_BLUE);
  blue[ColourPairs.StatusBar] = ncursesColourPair(COLOR_WHITE, COLOR_RED);
  blue[ColourPairs.MenuFore] = ncursesColourPair(COLOR_BLACK, COLOR_GREEN);
  blue[ColourPairs.MenuBack] = ncursesColourPair(COLOR_GREEN, COLOR_BLUE);
  blue[ColourPairs.AccountMenuFore] = ncursesColourPair(COLOR_WHITE, COLOR_RED);
  blue[ColourPairs.AccountMenuBack] = ncursesColourPair(COLOR_WHITE, COLOR_BLUE);
  blue[ColourPairs.StandardText] = ncursesColourPair(COLOR_WHITE, COLOR_BLUE);
  blue[ColourPairs.GreenText] = ncursesColourPair(COLOR_GREEN, COLOR_BLUE);
  blue[ColourPairs.RedText] = ncursesColourPair(COLOR_RED, COLOR_BLUE);
  blue[ColourPairs.PasswordBox] = ncursesColourPair(COLOR_YELLOW, COLOR_BLUE);

  white[ColourPairs.MainTitleText] = ncursesColourPair(COLOR_BLACK, COLOR_WHITE);
  white[ColourPairs.MainBorder] = ncursesColourPair(COLOR_BLACK, COLOR_WHITE);
  white[ColourPairs.StatusBar] = ncursesColourPair(COLOR_WHITE, COLOR_RED);
  white[ColourPairs.MenuFore] = ncursesColourPair(COLOR_GREEN, COLOR_BLACK);
  white[ColourPairs.MenuBack] = ncursesColourPair(COLOR_GREEN, COLOR_WHITE);
  white[ColourPairs.AccountMenuFore] = ncursesColourPair(COLOR_MAGENTA, COLOR_WHITE);
  white[ColourPairs.AccountMenuBack] = ncursesColourPair(COLOR_BLACK, COLOR_WHITE);
  white[ColourPairs.StandardText] = ncursesColourPair(COLOR_BLACK, COLOR_WHITE);
  white[ColourPairs.GreenText] = ncursesColourPair(COLOR_GREEN, COLOR_WHITE);
  white[ColourPairs.RedText] = ncursesColourPair(COLOR_RED, COLOR_WHITE);
  white[ColourPairs.PasswordBox] = ncursesColourPair(COLOR_BLUE, COLOR_WHITE);  
}

void initCursesColors(in ref ncursesColourPair[ColourPairs] _pairs)
{
  foreach(key, value; _pairs)
    {
      init_pair(key.to!short, value.expand);
    }
}

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


WINDOW* create_newwin(int height, int width, int starty, int startx, ColourPairs border, ColourPairs text, string title = "", Flag!"hasBox" hasBox = No.hasBox)
{
  WINDOW* local_win;
  local_win = newwin(height, width, starty, startx);
  if (hasBox == Yes.hasBox) {
    wattron(local_win, COLOR_PAIR(border));
    box(local_win, A_NORMAL , A_NORMAL);
    wattroff(local_win, COLOR_PAIR(border));
  }
  wbkgd(local_win, COLOR_PAIR(text));
  if (title != "") {
    wattron(local_win, A_BOLD);
    mvwprintw(local_win, 0,cast(int)((width/2)-(title.length/2)), "%s", title.toStringz);
    wattroff(local_win, A_BOLD);
  }
  wrefresh(local_win);                    // Show that box
  return local_win;
}
