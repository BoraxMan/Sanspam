import std.stdio;
import core.time;
import std.socket;
import std.string;
import std.conv: to;
import spaminexexception;

import deimos.openssl.conf;
import deimos.openssl.err;
import deimos.openssl.ssl;
import deimos.openssl.crypto;

enum EncryptionMethod : uint
{
    None, // No encryption is used
    //	SSLv23,  // SSL version 3 but rollback to 2
    //	SSLv3,   // SSL version 3 encryption
    TLSv1, // TLS version 1 encryption
    TLSv1_1, // TLS version 1.1 encryption
    TLSv1_2, // TLS version 1.2 encryption
}


class MailSocket
{
private:
  TcpSocket m_socket;
  char[65536] m_buffer;
  string m_server;
  int m_port;
  static const int socketTimeout = 20;

  SSL_METHOD *m_sslMethod;
  SSL_CTX* m_sslCTX;
  SSL* m_ssl;
  X509* m_x509;
  bool m_verified;


  void endSSL()
  {
    if (m_ssl !is null)
      {
	SSL_shutdown(m_ssl);
	m_ssl = null;
      }
    
    if (m_x509 !is null)
      {
	X509_free(m_x509);
	m_x509 = null;
      }
    
    if (m_ssl !is null)
      {
	SSL_free(m_ssl);
	m_ssl = null;
      }
    
    if (m_sslCTX !is null)
      {
	SSL_CTX_free(m_sslCTX);
	m_sslCTX = null;
      }
  }

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
  
  void close() @trusted
  {
    endSSL;
    m_socket.close;
  }

  bool send(in string message) @trusted
  {
    bool status;
    try {
      if (m_ssl !is null) {
	status = SSL_write(m_ssl,message.ptr, message.length.to!int) >= 0;
      } else {
	status = m_socket.send(message) == message.length;
      }
    } catch (SocketException e) {
      throw new SpaminexException(e.msg, "Failure to receive message.");
    }

    return status;
  }
  
  

  string receive(in bool multiline = false) @trusted
  {
    string end = multiline ? "\r\n.\r\n" : "\r\n";
    string result;
    ptrdiff_t len;

    do {
      try {
	if (m_ssl !is null) {
	  len = SSL_read(m_ssl, m_buffer.ptr, m_buffer.length);
	} else {
	  len = m_socket.receive(m_buffer);
	}
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

  final bool startSSL(EncryptionMethod method = EncryptionMethod.TLSv1_2) @trusted
  {
    
    OPENSSL_config("");
    //    SSL_library_init();
    //    SSL_load_error_strings();

    switch(method)
      {
      case EncryptionMethod.TLSv1:
	m_sslMethod = cast(SSL_METHOD*) TLSv1_client_method();
	break;
      case EncryptionMethod.TLSv1_1:
	m_sslMethod = cast(SSL_METHOD*) TLSv1_2_client_method();
	break;
      case EncryptionMethod.TLSv1_2:
	m_sslMethod = cast(SSL_METHOD*) TLSv1_2_client_method();
	break;
      case EncryptionMethod.None:
	return false;
      default:
	return false;
      }
 
    m_sslCTX = SSL_CTX_new(cast(const(SSL_METHOD*))(m_sslMethod));
    if (m_sslCTX is null) {
      throw new SpaminexException("SSL Error", "Could not create SSL Socket Connection");
    }
    
    m_ssl = SSL_new(m_sslCTX);
    if (m_ssl is null) {
      throw new SpaminexException("SSL Error", "Could not initiate new SSL connection");
      
    }
    
    SSL_set_fd(m_ssl, m_socket.handle);
    
    m_x509 = SSL_get_peer_certificate(m_ssl);
    if(m_x509 is null) {
      throw new SpaminexException("SSL Error", "Could not get peer x509 certificate.");
    }
    
    if (SSL_get_verify_result(m_ssl) != X509_V_OK) {
      m_verified = true;
    } else {
      m_verified = false;
    }
    return false; 
  }



}

