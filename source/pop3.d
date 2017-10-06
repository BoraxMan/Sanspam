import std.typecons : Tuple;
import std.string;
import socket;
import spaminexexception;
import std.exception;
import exceptionhandler;

immutable char[] OK = "+OK";
immutable char[] ERROR = "-ERR";

alias pop3Response = Tuple!(bool, "isValid", string, "contents");

class Pop3
{
private:
  MailSocket m_socket;
  string endline = "\r\n";
  char[65536] m_buffer;
  string[] m_capabilities;

  bool evaluateMessage(immutable ref string message) const @safe
  {
    //  Whether there response is OK or ERROR.
    if (message.startsWith(OK)) {
      return true;
    } else if(message.startsWith(ERROR)) {
      return false;
    } else {
      throw new SpaminexException("Malformed server response","Could not determine message success.");
    }
  }
  
public:

  this(in string server, in ushort port) @safe
  {
    m_socket = new MailSocket(server, port);
    immutable auto b = m_socket.receive();
    if(!evaluateMessage(b)) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }
  }

  ~this()
  {
    if(m_socket !is null) {
      destroy(m_socket);
    }
  }

  bool login(in string username, in string password) @safe
  {
    string loginQuery = "USER "~username;
    auto x = query(loginQuery);
    if (!x.isValid)
      return false;

    loginQuery = "PASS "~password;
    x = query(loginQuery);
    if (!x.isValid)
      return false;

    return false;
  }
  
  pop3Response query(in string command, bool multiline = false) @safe
  {
    pop3Response response;
    m_socket.send(command~endline);
    immutable string message = m_socket.receive(multiline);

    // Evaluate response.
    immutable bool isOK = evaluateMessage(message);
    
    if (isOK) {
      response.isValid = true;
      response.contents = message.chompPrefix(OK);
    } else if(!isOK) {
      response.isValid = false;
      response.contents = message.chompPrefix(ERROR);
    }
    import std.stdio;
    writeln("RESPONSE :", response.contents);
    return response;
  }

  void close() @safe
  {
    m_socket.close;
  }
}
