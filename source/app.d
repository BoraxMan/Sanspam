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


int main()
{

  init;

  initCurses;
  cbreak;
  noecho;
  scope(exit) {
    endwin;
  }
  keypad(stdscr,true);

  refresh;
  auto headerWindow = create_newwin(LINES-3,COLS,0,0,ColourPairs.MainBorder, ColourPairs.MainTitleText,"--== SPAMINEX ==--");
  auto statusWindow = create_newwin(3,COLS,LINES-3,0,ColourPairs.StatusBar,ColourPairs.StatusBar,"STATUS");
  auto accountSelectionWindow = create_newwin(10, COLS-10,(LINES/2-5),5,ColourPairs.MainTitleText, ColourPairs.MainBorder,"Select Account");

  auto xx = configurations.byKey();
  int ypos = 1;
  MENU* mailboxMenu;
  ITEM*[] mailboxes;
  ITEM* currentItem;
  int c;
  foreach(conf; xx) {
    //    mailboxes~=new_item(conf.to!string.toStringz,conf.to!string.toStringz);
    mailboxes~=new_item(conf.to!string.toStringz,"".toStringz);

  }
  mailboxMenu = new_menu(mailboxes.ptr);
  set_menu_win(mailboxMenu, accountSelectionWindow);
  set_menu_sub(mailboxMenu,derwin(accountSelectionWindow,6,38,3,1));
  set_menu_mark(mailboxMenu," * ");
  keypad(accountSelectionWindow,true);
  post_menu(mailboxMenu);
  
  //    mvwprintw(accountSelectionWindow, ypos++,1,c.to!string.toStringz);
  wrefresh(accountSelectionWindow);
  refresh;

  while ((c = wgetch(accountSelectionWindow)) != KEY_F(1))
    {
      switch (c)
        {
        case KEY_DOWN:
            menu_driver(mailboxMenu, REQ_DOWN_ITEM);
            break;
        case KEY_UP:
            menu_driver(mailboxMenu, REQ_UP_ITEM);
            break;
        case KEY_NPAGE:
            menu_driver(mailboxMenu, REQ_SCR_DPAGE);
            break;
        case KEY_PPAGE:
            menu_driver(mailboxMenu, REQ_SCR_UPAGE);
            break;
        default:
            break;
        }
        wrefresh(accountSelectionWindow);
    }


  getch;
  /*
    
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
  */
  /*
  Mailbox mailbox = new Mailbox("iinet");
  mailbox.login;
  FolderList f = mailbox.folderList;
  writeln(f);
  mailbox.selectFolder(f[0]);
  mailbox.loadMessages;
  foreach(a; mailbox)
    {
      write(a.subject," ", a.from);
      writeln;
      
    }*/
  return 0;
}

