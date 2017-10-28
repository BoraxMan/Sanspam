import std.stdio;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.conv;
import std.string;
import config;
import exceptionhandler;
import spaminexexception;
import mailbox;
import mailprotocol;

enum ColourPairs : int {
  MainBorder = 1,
    MainTitleText,
    StatusBar,
    MenuFore,
    MenuBack
    }

WINDOW *accountSelectionWindow = null;
WINDOW *accountEditWindow = null;
WINDOW *statusWindow = null;
WINDOW *headerWindow = null;

void clearStatusMessage()
{

  return;
}
void writeStatusMessage(in string message)
{
  wattron(statusWindow, COLOR_PAIR(ColourPairs.StatusBar));
  mvwprintw(statusWindow,1,1,message.toStringz);
  wrefresh(statusWindow);
  wattroff(statusWindow, COLOR_PAIR(ColourPairs.StatusBar));

}
  
void editAccount(in string account)
{

  MENU* messageMenu = null;
  ITEM*[] messageItems;
  ITEM* currentItem;
  Mailbox mailbox;

  scope(exit)
    {
      foreach(ref x; messageItems ) {
	free_item(x);
      }
      
      if (messageMenu != null) {
	free_menu(messageMenu);
	messageMenu = null;
      }

      if (accountEditWindow != null) {
	
	wclear(accountEditWindow);
	wrefresh(accountEditWindow);
	delwin(accountEditWindow);
	accountEditWindow = null;
      }
      
    }
  
  accountEditWindow = newwin(LINES-5,COLS-2,1,1);
  int x;
  immutable a = toStringz("SDF");
  writeStatusMessage("Logging in...");

  try {
    mailbox = new Mailbox(account);
    mailbox.login;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
  }

  try {
    mailbox.loadMessages;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
  }
  foreach(m; mailbox) {
    x++;
    currentItem=new_item(m.from.toStringz,m.subject.toStringz);
    if (currentItem == null) {
      writeStatusMessage("Could not process"~m.from);
    }
    messageItems~=currentItem;
  }

  messageMenu = new_menu(messageItems.ptr);
  set_menu_win(messageMenu, accountEditWindow);
  set_menu_sub(messageMenu, derwin(accountEditWindow,LINES-20,COLS-190,0,0));
  set_menu_mark(messageMenu, " * ");
  set_menu_format(messageMenu,LINES-20,1);
  keypad(accountEditWindow, true);
  post_menu(messageMenu);
  wrefresh(accountEditWindow);
  

  //  writeStatusMessage("(D)elete, (B)ounce and delete, (Q)uit, (C)ancel and quit");

  int c;
  while ((c = wgetch(accountEditWindow)) != 'q')
    {
      switch (c)
        {
        case KEY_DOWN:
	  menu_driver(messageMenu, REQ_DOWN_ITEM);
	  break;
        case KEY_UP:
	  menu_driver(messageMenu, REQ_UP_ITEM);
	  break;
        case KEY_NPAGE:
	  menu_driver(messageMenu, REQ_SCR_DPAGE);
	  break;
        case KEY_PPAGE:
	  menu_driver(messageMenu, REQ_SCR_UPAGE);
	  break;
	case 'D':
	  menu_driver(messageMenu, REQ_TOGGLE_ITEM);
	  refresh;
	  return;
        default:
	  break;
        }
      wrefresh(accountSelectionWindow);
    }

  
  wrefresh(accountEditWindow);
}

void createStatusWindow()
{
  statusWindow = create_newwin(3,COLS,LINES-3,0,ColourPairs.StatusBar,ColourPairs.StatusBar,"STATUS");
}

void mainWindow()
{
  headerWindow = create_newwin(LINES-3,COLS,0,0,ColourPairs.MainBorder, ColourPairs.MainTitleText,"--== SPAMINEX ==--");
}

void initCurses()
{
  initscr;
  start_color;
  init_pair(ColourPairs.MainTitleText, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(ColourPairs.MainBorder, COLOR_CYAN, COLOR_BLACK);
  init_pair(ColourPairs.StatusBar, COLOR_YELLOW, COLOR_BLUE);
  init_pair(ColourPairs.MenuFore, COLOR_YELLOW, COLOR_BLUE);
  init_pair(ColourPairs.MenuBack, COLOR_GREEN, COLOR_BLACK);
  cbreak;
  noecho;
  keypad(stdscr,true);
  refresh;
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

string accountSelectMenu()
{
  accountSelectionWindow = create_newwin(10, COLS-10,(LINES/2-5),5,ColourPairs.MainTitleText, ColourPairs.MainBorder,"Select Account");

  auto xx = configurations.byKey();
  MENU* mailboxMenu = null;
  ITEM*[] mailboxes;
  ITEM* currentItem = null;
  int c;
  string account;
  
  scope(exit) {
    foreach(ref x; mailboxes) {
	free_item(x);
      }
      
      if (mailboxMenu != null) {
	free_menu(mailboxMenu);
	mailboxMenu = null;
      }

      if (accountSelectionWindow != null) {
	
	wclear(accountSelectionWindow);
	wrefresh(accountSelectionWindow);
	delwin(accountSelectionWindow);
	accountSelectionWindow = null;
      }
      
  }
  foreach(conf; xx) {
    //    mailboxes~=new_item(conf.to!string.toStringz,conf.to!string.toStringz);
    mailboxes~=new_item(conf.to!string.toStringz,"".toStringz);

  }
  mailboxMenu = new_menu(mailboxes.ptr);

  set_menu_win(mailboxMenu, accountSelectionWindow);
  set_menu_sub(mailboxMenu,derwin(accountSelectionWindow,6,38,3,1));
  set_menu_mark(mailboxMenu," * ");
  set_menu_fore(mailboxMenu, COLOR_PAIR(ColourPairs.MenuFore));
  set_menu_back(mailboxMenu, COLOR_PAIR(ColourPairs.MenuBack));


  keypad(accountSelectionWindow,true);
  post_menu(mailboxMenu);
  wrefresh(accountSelectionWindow);

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
	case 'D':
	  menu_driver(mailboxMenu, REQ_TOGGLE_ITEM);
	  account = item_name(current_item(mailboxMenu)).to!string;
	  return account;
        default:
	  break;
        }
      wrefresh(accountSelectionWindow);
    }
  return account;
}
