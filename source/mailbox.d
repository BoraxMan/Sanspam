import spaminexexception;
import processline;
import std.conv;
import std.string;
import std.stdio;
import message;
import pop3;
import config;

struct Encrypted {} // May get implemented later.
struct ConfigOption {} // May be used later.

struct Messages
{ /* The only real purpose of this struct is to use a numbering system which coincides with
     the numbers that the server gives messages.  D starts its array index at 0, whereas we want 1 to be the first element.

     This way we don't have to keep adjusting the index by one. */
  
  int begin = 1;
  int end;

  void add(Message message) @safe
  {
    m_messages~=message;
  }
  

  bool empty() @safe const
  {
    return ((begin - 1) == m_messages.length);
  }

  void popFront() @safe
  {
    ++begin;
  }

  size_t length() @safe const
  {
    return m_messages.length;
  }
  
  Message front() @safe
  {
    return(m_messages[begin-1]);
  }
  
  Message[] m_messages;

  auto opIndex(int n)
    in
      {
	assert(n <= m_messages.length);
      }
  body
    {    
      return m_messages[n-1];
    }


}

class Mailbox
{
private:
  string m_mailboxName;
  Messages m_messages;
  Pop3 m_connection;
  @ConfigOption string m_popServer;
  @ConfigOption string m_smtpServer;
  @ConfigOption ushort m_port;
  @ConfigOption string m_username;
  @ConfigOption @Encrypted string m_password;
  Config m_config;
  bool m_connected = false;
  int m_mailboxSize;
  bool m_supportUIDL = false;
  bool m_supportTOP = false;

  void getCapabilities() @safe
  {
    immutable auto response = m_connection.query("CAPA");
    if (response.isValid == false)
      return;
    immutable auto results = split(response.contents);
    foreach (x; results) {
      if (x.toUpper == "UIDL") {
	m_supportUIDL = true;
      } else if (x.toUpper == "TOP") {
	m_supportTOP = true;
      }
    }
  }

  string getUIDL(in int messageNumber) @safe
  {
    string UIDLquery = "UIDL "~messageNumber.to!string;
    immutable auto UIDLresponse = m_connection.query(UIDLquery);
    if (UIDLresponse.isValid == false) {
      throw new SpaminexException("POP3 transfer failure", "Failed to execute query "~UIDLquery);
    } else {
      immutable auto results = UIDLresponse.contents.split;
      return results[1];
    }

  }

  
public:
  
  auto opApply(int delegate(ref Message) operations) {
    int result;
    for (int x = 1; x <= m_messages.length; x++) {
      Message m = m_messages[x];
      result = operations(m);
      
      if (result) {
	break;
      }
    }
    return result;
  }
  
  
  @property size_t size() @safe const
  {
    return m_messages.length;
  }


  this(in string mboxName) @safe
  {
    m_config = getConfig(mboxName);
    m_popServer = m_config.getSetting("pop");
    m_port = m_config.getSetting("port").to!ushort;
    m_connection = new Pop3(m_popServer, m_port);
  }

  ~this()
  {
    destroy(m_connection);
  }
  /* We DON'T call QUIT on the pop server when the destructor is called,
     as it may be called due to an exception.  We assume the user only
     wants to delete for sure.
  */

  bool close() @safe
  {
    immutable string query = "QUIT";
    immutable auto response = m_connection.query(query);
    if (response.isValid == false) {
      throw new SpaminexException("Failed close connection with server.","E-mails marked for deletion may not be deleted.");
    }
    m_connection.close;
    return true;
  }
 
  bool loadMessages() @safe
  {
    if (m_mailboxSize == 0) {
      return true;
    }

    ProcessMessageData pmd = new ProcessMessageData();

    for(int x = 1; x <= m_mailboxSize; x++)
      {
	Message m;
	string query = "TOP "~x.to!string;
	immutable auto response = m_connection.query(query,true);
	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);
	
	if(m_supportUIDL) {
	  m.uidl = getUIDL(x);
	}
	m_messages.add(m);

      }
    return true;
  }
  
  bool remove(in int messageNumber, in string uidl = "")
    in
      {
	assert (messageNumber > 0);
      }
      
  body {
    string thisUIDL;
    /*  Lets double check to make sure that the message we are deleting is the one
	we want to delete.
	We will get the UIDL again and compare against the string provided, if one exists.
	This makes sure that we don't delete the wrong message, in case something else has happened which
	has changed the mailbox since this program was started.
    */
    
    
    if (m_supportUIDL) {
      thisUIDL = getUIDL(messageNumber);
      writeln(thisUIDL, ":", uidl);
      if (uidl.length > 0) {
	if (thisUIDL != uidl) {
	  throw new SpaminexException("Message mismatch", "Was trying to delete message with UIDL "~uidl~" but got "~thisUIDL~" instead.");
	}
      }
    }
    // If we got this far, we don't have a UIDL to check against, or the check passed.  So delete the message.
    string query = "DELE "~messageNumber.to!string;
    writeln("Deleting message ", messageNumber, " with UIDL ", thisUIDL);
    auto response = m_connection.query(query);
    if (response.isValid) {
      m_messages[messageNumber-1].deleted = true;
    }
    return response.isValid;
  }
  
  bool remove(in string uidl)
  {
    bool result;
    int x;
    // Search its position in the mailbox.
    foreach(m; m_messages) {
      x++;
      writeln(x);
      if (m.uidl == uidl) {
	result = remove(x, m.uidl);
      }
    }
      
    return result;
  }
  

  bool login()
  {
    m_username = m_config.getSetting("username");
    m_password = m_config.getSetting("password");
    m_connected = m_connection.login(m_username, m_password);
    m_password = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    getNumberOfMessages;
    getCapabilities;
    return m_connected;
  }

   int getNumberOfMessages()
  // Returns the number of e-mails, or -1 in case of error.
  {
    immutable auto response = m_connection.query("STAT");
    if (response.isValid == false)
      return 0;

    immutable auto result = response.contents.split;
    auto numberOfMessages = result[0].to!int;
    m_mailboxSize = numberOfMessages;
    return m_mailboxSize;

  }

  
}
