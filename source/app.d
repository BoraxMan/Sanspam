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
  // bounceMessage("dennisk@netspace.net.au","netspace.net.au");
  scope(exit) {
    endwin;
  }
  /*
  Mailbox mailbox;
  FolderList d;
  
  try {
    mailbox = new Mailbox("Nostromo");
    mailbox.login;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
  }

  d = mailbox.folderList;
  mailbox.selectFolder(d[4]);
  foreach(o;d)
    {
      writeln(o.name);
    }
  
  try {
    mailbox.loadMessages;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
  }


  foreach(ref m; mailbox)
    {
      writeln(m.subject);
      writeln(m.uidl);
    }
  //  writeln( mailbox.remove(1, mailbox.front));
  return 0;
  */
  
  initCurses;
  mainWindow;
  createStatusWindow;
  string account;
  
  while((account = accountSelectMenu) != "")
  {
    editAccount(account);
    // No text, means the user wanted to quit.

  }
  
  endwin;
  //  writeln(account);
  
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
      
    }
  */
  return 0;

}

