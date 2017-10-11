import std.stdio;
import std.conv;
import std.typecons : Tuple;
import std.string;
import socket;
import mailprotocol;
import spaminexexception;
import std.exception;
import exceptionhandler;

immutable string seen = "\\Seen";
immutable string answered = "\\Answered";
immutable string deleted = "\\Deleted";
immutable string recent = "\\Recent";
immutable string prefix = "Spaminex";

alias queryResponse = Tuple!(bool, "isValid", string, "contents");

struct commandPrefix
{
  int m_sequence;
  string m_prefix = prefix;

  auto opCall()
  {
    ++m_sequence;
    return prefix~m_sequence.to!string~" ";
  }
}

class IMAP : MailProtocol
{
private:
  commandPrefix prefix;

public:
  final bool evaluateMessage(immutable ref string message, const ref string prefix) const @safe
  {
    return true;
  }
  
  this(in string server, in ushort port) @safe 
  {
    m_socket = new MailSocket(server, port);
    immutable auto b = m_socket.receive();
    if(!evaluateMessage(b)) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }
    writeln(b);
  }

  override final bool login(in string username, in string password) @safe
  {
    string loginQuery = "LOGIN "~username~" "~password;
    auto x = query(loginQuery);
    if (!x.isValid)
      return false;
    return true;
  }


  final queryResponse query(in string command, bool multiline = false) @safe
  {
    queryResponse response;
    m_socket.send(prefix()~command~endline);
    immutable string message = m_socket.receive(multiline);
    writeln("Command :", command);
    writeln("Contents :", message);
    return response;
  }
    
  override final string getUID(in int messageNumber) @safe
  {
    return "";
  }
}

unittest
{
  commandPrefix p;
  assert(p() == "Spaminex1");
  assert(p() == "Spaminex2");
}
