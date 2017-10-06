import core.thread;
import std.stdio;
import std.socket;
import std.string;
import std.file;
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
  Pop3 pop3connection;
  Mailbox mailbox;
  
  try {
    mailbox = new Mailbox("netspace");
    mailbox.login;
  }
  
  catch (SpaminexException e) {
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
  mailbox.remove("000088563f211667");
  mailbox.close;
  return 0;
}
