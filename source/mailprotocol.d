// Super class for Mail protocol handling.
import std.typecons : Tuple;
import socket;
import std.string;
import config;
import message;
import std.stdio;
import processline;

alias queryResponse = Tuple!(bool, "isValid", string, "contents");

struct Encrypted {} // May get implemented later.
struct ConfigOption {} // May be used later.

struct Messages
{ /* The only real purpose of this struct is to use a numbering system which coincides with
     the numbers that the server gives messages.  D starts its array index at 0, whereas we want 1 to be the first element.

     This way we don't have to keep adjusting the index by one. */
  
  int begin = 1;
  int end;
  Message[] m_messages;
  
  final void add(Message message) @safe
  {
    m_messages~=message;
  }
  

  final bool empty() @safe const
  {
    return ((begin - 1) == m_messages.length);
  }

  final void popFront() @safe
  {
    ++begin;
  }

  final size_t length() @safe const
  {
    return m_messages.length;
  }
  
  final Message front() @safe
  {
    return(m_messages[begin-1]);
  }
  
  final auto opIndex(int n)
    in
      {
	assert(n <= m_messages.length);
      }
  body
    {    
      return m_messages[n-1];
    }
}


class MailProtocol

{
  string m_mailboxName;
  Messages m_messages;

  bool m_connected = false;
  int m_mailboxSize;
  bool m_supportUID = false;
  bool m_supportTOP = false;

  @ConfigOption string m_popServer;
  @ConfigOption string m_smtpServer;
  @ConfigOption ushort m_port;
  @ConfigOption string m_username;
  @ConfigOption @Encrypted string m_password;

  MailSocket m_socket;
  string endline = "\r\n";
  char[65536] m_buffer;
  string[] m_capabilities;
  
public:
  abstract bool login(in string username, in string password) @safe;
  abstract string getUID(in int messageNumber) @safe;

  void close() @safe
  {
    m_socket.close;
  }

}


