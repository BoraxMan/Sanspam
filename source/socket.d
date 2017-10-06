import core.time;
import std.socket;
import std.string;
import std.conv: to;
import spaminexexception;

class MailSocket
{
private:
  TcpSocket m_socket;
  char[65536] m_buffer;
  string m_server;
  int m_port;
  static const int socketTimeout = 20;

public:
  this(in string server, in int port) @safe
  {
    Duration r ;
    try {
      m_socket = new TcpSocket();
      auto addresses = getAddress(server, cast(ushort)port);
      m_socket.connect(addresses[0]);
      m_socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO,dur!"seconds"(socketTimeout));
    } catch (SocketException e) {
      throw new SpaminexException(e.msg, "Cannot connect to address "~server~" at port "~(port.to!string));
    }
  }

  ~this()
  {
    if(m_socket.isAlive == true)
      close;
  }
  
  void close() @safe
  {
    m_socket.close;
  }

  bool send(in string message) @safe
  {
    try {
      m_socket.send(message);
    } catch (SocketException e) {
      throw new SpaminexException(e.msg, "Failure to receive message.");
    }

    return true;
  }

  string receive(in bool multiline = false) @safe 
  {
    string end = multiline ? "\r\n.\r\n" : "\r\n";
    string result;
    ptrdiff_t len;

    do {
      try {
	len = m_socket.receive(m_buffer);
      }
      catch (SocketException e) {
	throw new SpaminexException(e.msg, "Failure to receive message.");
      }
      if (len == 0) {
	throw new SpaminexException("Connection closed.","No data received");
      } else if (len == Socket.ERROR) {
	throw new SpaminexException("Failure receiving data.","Socket Error");
      }
      result~=m_buffer[0..cast(int)len].to!string;
    } while (!result.endsWith(end));

    return result;
  }
}

