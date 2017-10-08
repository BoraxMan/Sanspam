import deimos.ncurses;
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


int main()
{
  init;

  initCurses;

  scope(exit) {
    endwin;
  }

  refresh;
  auto headerWindow = create_newwin(LINES-3,COLS,0,0,ColourPairs.MainBorder, ColourPairs.MainTitleText,"--== SPAMINEX ==--");
  auto statusWindow = create_newwin(3,COLS,LINES-3,0,ColourPairs.StatusBar,ColourPairs.StatusBar,"STATUS");
  auto accountSelectionWindow = create_newwin(10, COLS-10,(LINES/2-5),5,ColourPairs.MainTitleText, ColourPairs.MainBorder,"Select Account");

  auto xx = configurations.byKey();
    int ypos = 1;

  foreach(c; xx) {
    mvwprintw(accountSelectionWindow, ypos++,1,c.to!string.toStringz);
  }
    wrefresh(accountSelectionWindow);
    

  getch;

  
    foreach(c; xx) {
    Mailbox mailbox;
    try {
      writeln();
      mailbox = new Mailbox(c.to!string);
      mailbox.login;
    } catch (SpaminexException e) {
      auto except = new ExceptionHandler(e);
      except.display;
    }
    try {
      mailbox.loadMessages;
    }
    catch (SpaminexException e) {
      writeln("Exception");
      ExceptionHandler x = new ExceptionHandler(e);
      x.display;
    }
    foreach(m; mailbox) {
      auto writer = appender!string();
    }
    mailbox.close;    
  }
  return 0;
}

