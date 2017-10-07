import deimos.ncurses;
import core.thread;
import std.array;
import std.conv;
import std.stdio;
import std.socket;
import std.string;
import std.file;
import std.format;
import config;
import exceptionhandler;
import pop3;
import spaminexexception;
import mailbox;
import message;
import processline;


int main()
{
  init;
  initscr;
  scope(exit) {
    endwin;
  }
  auto xx = configurations.byKey();
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
      writer.formattedWrite("Subject : %s", m.subject);
      clear;
      printw(writer.data.toStringz);
      refresh();
      getch();

    }
    mailbox.close;    
  }
  return 0;
}

