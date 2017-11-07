import core.stdc.errno;
import std.stdio;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.conv;
import std.string;
import message;
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
    MenuBack,
    AccountMenuFore,
    AccountMenuBack,
    StandardText
    }

WINDOW *accountSelectionWindow = null;
WINDOW *accountEditWindow = null;
WINDOW *statusWindow = null;
WINDOW *headerWindow = null;

void createStatusWindow()
{
  statusWindow = newwin(1,COLS,LINES-1,0);
  wbkgd(statusWindow, A_NORMAL|ColourPairs.StatusBar);
}
    

void clearStatusMessage()
{
  wmove(statusWindow,0,0);
  wclrtoeol(statusWindow);
  wrefresh(statusWindow);
  return;
}

void writeStatusMessage(in string message)
{
  wattron(statusWindow, COLOR_PAIR(ColourPairs.StatusBar));
  mvwprintw(statusWindow,0,0,message.toStringz);
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
      }

      if (accountEditWindow != null) {
	
	wclear(accountEditWindow);
	wrefresh(accountEditWindow);
	delwin(accountEditWindow);
	accountEditWindow = null;
      }
      destroy(mailbox);
      clearStatusMessage;      
    }
  
  accountEditWindow = newwin(LINES-3,COLS-2,1,1);
  menu_opts_off(messageMenu, O_ONEVALUE);
  int x;
  
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

  foreach(ref m; mailbox)
    {
      currentItem = new_item(m.from[0..((m.from.length < COLS/3) ? m.from.length : COLS/3)].toStringz, m.subject.toStringz);
      if (currentItem == null) {
	string error;
	if (errno == E_BAD_ARGUMENT) {
	  error = "Incorrect or out of range argument";
	} else if (errno == E_SYSTEM_ERROR) {
	  error = "System error (out of memory?)";
	} else {
	  error = "Unknown error";
	}
	throw new SpaminexException("Failed creating menu entry for "~m.subject.replace(":","I"),error);
      }
      set_item_userptr(currentItem, &m);
      
      messageItems~= currentItem;
    }
  
  messageItems~=null;
  
  messageMenu = new_menu(messageItems.ptr);
  if (messageMenu == null) {
    throw new SpaminexException("Internal Error","Could not create menu of messages for account "~account);
  }

  set_menu_win(messageMenu, accountEditWindow);
  set_menu_sub(messageMenu, derwin(accountEditWindow,LINES-4,COLS-2,0,0));
  set_menu_mark(messageMenu, "*");
  set_menu_format(messageMenu,LINES-3,1);
  
  set_menu_fore(messageMenu, COLOR_PAIR(ColourPairs.AccountMenuFore));
  set_menu_back(messageMenu, COLOR_PAIR(ColourPairs.AccountMenuBack));

  keypad(accountEditWindow, true);

  post_menu(messageMenu);
  int accountx, accounty;
  string footer;
  getmaxyx(accountEditWindow,accounty, accountx);
  wmove(accountEditWindow,accounty,1);
  if (mailbox.size == 0) {
    footer~="No e-mails.";
  } else if (mailbox.size == 1) {
    footer~="1 e-mail.";
  } else {
    footer~=mailbox.size.to!string~" e-mails.";
  }
  footer~="  Editing account : "~account~".";
  wprintw(accountEditWindow,footer.toStringz);
  wrefresh(accountEditWindow);
  writeStatusMessage("(D)elete, (B)ounce and delete, (Q)uit, (C)ancel and quit");
  
  int c;
  while ((c = wgetch(accountEditWindow)) != 'q')
    {
      switch (c)
	{
	case 'c':
	  goto case;
	case 'C':
	  return;
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
	case 'b':
	  goto case;
	case 'B':
	  (cast(Message*)item_userptr(current_item(messageMenu))).bounce = true;
	  goto case;
	case 'd':
	  goto case;
	case 'D':
	  (cast(Message*)item_userptr(current_item(messageMenu))).deleted = true;
	  menu_driver(messageMenu, REQ_TOGGLE_ITEM);
	  break;
	default:
	  break;
	}
      wrefresh(accountSelectionWindow);
    }

  for (int count = 0; count < item_count(messageMenu); count++) {
    if(item_value(messageItems[count]) == true) { // Has been tagged in the menu.
      if((mailbox.remove(count+1, (cast(Message*)item_userptr(messageItems[count])).uidl)) == false) {
	writeStatusMessage("FAILED to delete message for "~(cast(Message*)item_userptr(messageItems[count])).uidl);
      }
      if(((cast(Message*)item_userptr(messageItems[count])).bounce) == true) {
	writeStatusMessage("Bouncing to "~(cast(Message*)item_userptr(messageItems[count])).from);
	mailbox.bounceMessage(count+1);
	clearStatusMessage;

      }
    }
  }
  
  mailbox.close;
  wrefresh(accountEditWindow);
}

void mainWindow()
{
  headerWindow = create_newwin(LINES-1,COLS,0,0,ColourPairs.MainBorder, ColourPairs.MainTitleText,"--== SPAMINEX ==--");
}

void initCurses()
{
  initscr;
  start_color;
  init_pair(ColourPairs.MainTitleText, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(ColourPairs.MainBorder, COLOR_CYAN, COLOR_BLACK);
  init_pair(ColourPairs.StatusBar, COLOR_WHITE, COLOR_RED);
  init_pair(ColourPairs.MenuFore, COLOR_YELLOW, COLOR_BLUE);
  init_pair(ColourPairs.MenuBack, COLOR_GREEN, COLOR_BLACK);
  init_pair(ColourPairs.AccountMenuFore, COLOR_WHITE, COLOR_RED);
  init_pair(ColourPairs.AccountMenuBack, COLOR_BLUE, COLOR_BLACK);
  init_pair(ColourPairs.StandardText, COLOR_WHITE, COLOR_BLACK);
  
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
  
  
  MENU* mailboxMenu = null;
  ITEM*[] mailboxes;
  ITEM* currentItem = null;
  int c;
  string account;

  scope(exit) {
    clearStatusMessage;
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

  accountSelectionWindow = create_newwin(10, COLS-10,(LINES/2-5),5,ColourPairs.MainTitleText, ColourPairs.MainBorder,"Select Account");
  writeStatusMessage("Up/Down to navigate. Enter to select account.  Q to Quit.");
  auto xx = configurations.byKey();
  foreach(conf; xx) {
    //    mailboxes~=new_item(conf.to!string.toStringz,conf.to!string.toStringz);
    currentItem = new_item(conf.to!string.toStringz,"".toStringz);
    if (currentItem == null) {
      throw new SpaminexException("Could not create menu entry","Failed creating menu entry for "~conf.to!string);

    }
    mailboxes~=currentItem;
  }

  mailboxes~=null;
  mailboxMenu = new_menu(mailboxes.ptr);
  if (mailboxMenu == null) {
    throw new SpaminexException("Internal Error","Could not allocate menu.");
  }
  
  set_menu_win(mailboxMenu, accountSelectionWindow);
  set_menu_sub(mailboxMenu,derwin(accountSelectionWindow,6,38,3,1));
  set_menu_mark(mailboxMenu," * ");
  set_menu_fore(mailboxMenu, COLOR_PAIR(ColourPairs.MenuFore));
  set_menu_back(mailboxMenu, COLOR_PAIR(ColourPairs.MenuBack));

  keypad(accountSelectionWindow,true);
  post_menu(mailboxMenu);
  wrefresh(accountSelectionWindow);

  while ((c = wgetch(accountSelectionWindow)) != 'q')
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
	case ' ':
	case '\n':
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
