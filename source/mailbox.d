import spaminexexception;
import processline;
import std.conv;
import std.string;
import std.stdio;
import message;
public import pop3;
public import imap;
import config;
import mailprotocol;

class Mailbox
{
private:
  MailProtocol m_connection;
  Config m_config;

public:
  
  auto opApply(int delegate(ref Message) operations) {
    int result;
    for (int x = 1; x <= m_connection.m_messages.length; x++) {
      Message m = m_connection.m_messages[x];
      result = operations(m);
      
      if (result) {
	break;
      }
    }
    return result;
  }
  
  
  final @property size_t size() @safe const
  {
    return m_connection.m_messages.length;
  }


  final this(in string mboxName) @safe
  {
    writeln(mboxName);
    m_config = getConfig(mboxName);
    auto port = m_config.getSetting("port").to!ushort;
    auto type = m_config.getSetting("type");

    if (type.toLower == "pop") {
      auto server = m_config.getSetting("pop");
      m_connection = new Pop3(server, port);

    } else if (type.toLower == "imap") {
      auto server = m_config.getSetting("imap");
      m_connection = new IMAP(server, port);
    }
  }

  final void selectFolder(in ref Folder folder) @safe
  {
    return m_connection.selectFolder(folder);
  }
  
  final ~this()
  {
    destroy(m_connection);
  }
  /* We DON'T call QUIT on the pop server when the destructor is called,
     as it may be called due to an exception.  We assume the user only
     wants to delete for sure.
  */

  
  FolderList folderList() @safe
  {
    return m_connection.folderList;
  }
  
  final bool login()
  {
    auto username = m_config.getSetting("username");
    auto password = m_config.getSetting("password");
    m_connection.login(username, password);
    password = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    return true;
  }


  
}
