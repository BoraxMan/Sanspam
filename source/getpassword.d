import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.conv;
import std.typecons;
import uidefs;


const char CharDel = 127;

string getPassword()
{
  char[512] text;
  size_t endPosition;
  const char CharDelete = 127;
  size_t charPos;
  int c;

  passwordWindow = create_newwin(3,COLS-10,(LINES/2)-2,5,ColourPairs.PasswordBox, ColourPairs.PasswordBox,"Enter Password", Yes.hasBox);
  wmove(passwordWindow, 1,1);
  noecho();

  for(;;) {
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