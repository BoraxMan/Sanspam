import std.array;
import std.conv;
import std.string;
import std.format;
import spaminexexception;
import processline;
import message;
public import pop3;
public import imap;
import config;
import mailprotocol;
import SMTP_mod;


enum Protocol {
  POP3,
  IMAP,
  SMTP,
  Unknown
}

const string bounceFormat = "From: <MAILER-DAEMON@%s>\r\nSubject: Returned mail: see Transcript for details.\r\n\r\n   ----- The following addresses had permanent fatal errors -----\r\n<%s>\r\n(reason: 550 5.1.1 <%s>... User unknown)\r\n\r\n   ----- Transcript of session follows -----\r\n... while talking to mlsrv.%s.:\r\n>>> DATA\n<<< 550 5.1.1 <%s>... User unknown\r\n550 5.1.1 <%s>... User unknown\r\n<<< 503 5.0.0 Need RCPT (recipient)\r\n\r\n.";

string getDomainFromEmailAddress(in string address)
{
  auto index = indexOf(address,'@');
  if (index == -1) {
    return "";
  }
  return address[index+1..$];
}

class Mailbox
{
private:
  MailProtocol m_connection;
  Config m_config;
  Protocol m_protocol;
  
public:

  @property Protocol protocol()
  {
    return m_protocol;
  }

  @property size_t size()
  {
    return m_connection.m_messages.length;
  }
  
  auto opApply(int delegate(ref Message) operations) {
    int result;
    for (int x = 1; x <= m_connection.m_messages.length; x++) {
      Message *m = m_connection.m_messages[x];
      result = operations(*m);
      
      if (result) {
	break;
      }
    }
    return result;
  }

  bool bounceMessage(in int count)
  {
    SMTP smtp;
    string domain;
    string smtp_server;
    ushort smtp_port;

    scope(failure)
      {
	if (smtp !is null) {
	  smtp.close;
	}
      }

    string recipient = m_connection.m_messages[count].from;
    if(m_config.hasSetting("domain")) {
	domain = m_config.getSetting("domain");
      } else { // Try to guess from the account details
	string uname = m_config.getSetting("username");
	domain = getDomainFromEmailAddress(uname);
	if (domain == "") {
 	  throw new SpaminexException("Failed to bounce message","Email domain not specified.  Add \"domain = insert.domain.here'\" option to Spaminex configuration file.");
	}
      }

    if(!m_config.hasSetting("smtp")) {
      throw new SpaminexException("Failed to bounce message","SMTP server not specified.  Add \"smtp = smtp.server'\" option to Spaminex configuration file.");
    }

    if(!m_config.hasSetting("smtp_port")) {
      throw new SpaminexException("Failed to bounce message","SMTP port not specified.  Add \"smtp_port = port'\" option to Spaminex configuration file.");
    }

    smtp_server = m_config.getSetting("smtp");
    smtp_port = m_config.getSetting("smtp_port").to!ushort;
    smtp = new SMTP(smtp_server,smtp_port);
    smtp.login(m_config.getSetting("username"),"");
    auto message = appender!string();
    message.formattedWrite(bounceFormat,domain,m_connection.m_messages[count].to,m_connection.m_messages[count].to,domain,m_connection.m_messages[count].to, m_connection.m_messages[count].to);
    smtp.bounceMessage(recipient, domain,message.data);

    return true;
}

  
  final @property size_t size() @safe const
  {
    return m_connection.m_messages.length;
  }

  void close()
  {
    m_connection.close;
  }
  
  final this(in string mboxName) @safe
  {
    m_config = getConfig(mboxName);
    auto port = m_config.getSetting("port").to!ushort;
    auto type = m_config.getSetting("type");
    if (type.toLower == "pop") {
      auto server = m_config.getSetting("pop");
      m_connection = new Pop3(server, port);
      m_protocol = Protocol.POP3;
    } else if (type.toLower == "imap") {
      auto server = m_config.getSetting("imap");
      m_connection = new IMAP(server, port);
      m_protocol = Protocol.IMAP;
    } else {
      m_protocol = Protocol.Unknown;
      throw new SpaminexException("Account type not specified","Configuration needs to include 'type = xxx' where xxx is pop or imap");
    }
  }

  final void selectFolder(ref Folder folder) @safe
  {
    return m_connection.selectFolder(folder);
  }


  final bool remove(in int messageNumber, in string uidl = "", in string trashFolder = "")
  {
    return m_connection.remove(messageNumber, uidl, trashFolder);
  }
  
  final bool remove(in string uidl)
  {
    return m_connection.remove(uidl);
  }
  
  
  /* We DON'T call QUIT on the pop server when the destructor is called,
     as it may be called due to an exception.  We assume the user only
     wants to delete for sure.
  */


  void loadMessages()
  {
    m_connection.loadMessages;
  }
  
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

unittest
{
  assert(getDomainFromEmailAddress("de@test.com") == "test.com");
  assert(getDomainFromEmailAddress("sdf.asf@test.com.au") =="test.com.au");
  assert(getDomainFromEmailAddress("sdf") == "");
  assert(getDomainFromEmailAddress("Dennis_Katsonis@yahoooooo.com.u")== "yahoooooo.com.u");
}
