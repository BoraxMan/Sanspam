import std.string;
import socket;
import config;
import message;
import mailprotocol;
import spaminexexception;
import std.exception;
import std.stdio;
import std.conv;
import processline;
import exceptionhandler;

immutable char[] OK = "+OK";
immutable char[] ERROR = "-ERR";

class Pop3 : MailProtocol
{
private:
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

  final this(in string server, in ushort port) @safe
  {
    m_socket = new MailSocket(server, port);
    immutable auto b = m_socket.receive();
    if(!evaluateMessage(b)) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }
  }

  final ~this()
  {
    if(m_socket !is null) {
      destroy(m_socket);
    }
  }



  override final string getUID(in int messageNumber) @safe
  {
    string UIDquery = "UID "~messageNumber.to!string;
    immutable auto UIDresponse = query(UIDquery);
    if (UIDresponse.isValid == false) {
      throw new SpaminexException("POP3 transfer failure", "Failed to execute query "~UIDquery);
    } else {
      immutable auto results = UIDresponse.contents.split;
      return results[1];
    }

  }

  final void getCapabilities() @safe
  {
    immutable auto response = query("CAPA");
    if (response.isValid == false)
      return;
    immutable auto results = split(response.contents);
    foreach (x; results) {
      if (x.toUpper == "UID") {
	m_supportUID = true;
      } else if (x.toUpper == "TOP") {
	m_supportTOP = true;
      }
    }
  }
  
  
    
  override final bool login(in string username, in string password) @safe
  {
    string loginQuery = "USER "~username;
    auto x = query(loginQuery);
    if (!x.isValid)
      return false;

    loginQuery = "PASS "~password;
    x = query(loginQuery);
    if (!x.isValid) {
      m_connected = false;
      return false;
    }
    m_connected = true;
    getNumberOfMessages;
    getCapabilities;
    return false;
  }
  
  final queryResponse query(in string command, bool multiline = false) @safe 
  {
    queryResponse response;
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
    return response;
  }


  final bool remove(in int messageNumber, in string uidl = "")
    in
      {
	assert (messageNumber > 0);
      }
      
  body {
    string thisUID;
    /*  Lets double check to make sure that the message we are deleting is the one
	we want to delete.
	We will get the UID again and compare against the string provided, if one exists.
	This makes sure that we don't delete the wrong message, in case something else has happened which
	has changed the mailbox since this program was started.
    */
    
    
    if (m_supportUID) {
      thisUID = getUID(messageNumber);
      writeln(thisUID, ":", uidl);
      if (uidl.length > 0) {
	if (thisUID != uidl) {
	  throw new SpaminexException("Message mismatch", "Was trying to delete message with UID "~uidl~" but got "~thisUID~" instead.");
	}
      }
    }
    // If we got this far, we don't have a UID to check against, or the check passed.  So delete the message.
    string messageQuery = "DELE "~messageNumber.to!string;
    writeln("Deleting message ", messageNumber, " with UID ", thisUID);
    auto response = query(messageQuery);
    if (response.isValid) {
      m_messages[messageNumber-1].deleted = true;
    }
    return response.isValid;
  }
  
  final bool remove(in string uidl)
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


  final int getNumberOfMessages() @trusted
  // Returns the number of e-mails, or -1 in case of error.
  {
    immutable auto response = query("STAT");
    if (response.isValid == false)
      return 0;

    immutable auto result = response.contents.split;
    auto numberOfMessages = result[0].to!int;
    m_mailboxSize = numberOfMessages;
    return m_mailboxSize;

  }

  final bool close() @safe
  {
    immutable string messageQuery = "QUIT";
    immutable auto response = query(messageQuery);
    if (response.isValid == false) {
      throw new SpaminexException("Failed close connection with server.","E-mails marked for deletion may not be deleted.");
    }
    return true;
  }
 
  override final bool loadMessages() @safe
  {
    if (m_mailboxSize == 0) {
      return true;
    }

    ProcessMessageData pmd = new ProcessMessageData();

    for(int x = 1; x <= m_mailboxSize; x++)
      {
	Message m;
	string messageQuery = "TOP "~x.to!string;
	immutable auto response = query(messageQuery,true);
	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);
	
	if(m_supportUID) {
	  m.uidl = getUID(x);
	}
	m_messages.add(m);

      }
    return true;
  }


  override final void selectFolder(in ref Folder folder) @safe
  {
    return;
  }
  

  override final FolderList folderList() @safe
  {
    return m_folderList;
  }
  
}
