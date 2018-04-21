import std.algorithm;
import std.conv;
import std.typecons;
import std.string;
import std.format;
import std.array;
import std.exception;
import buffer;
import imapparse;
import socket;
import mailprotocol;
import message;
import processline;
import spaminexexception;
import exceptionhandler;

immutable string seen = "\\Seen";
immutable string answered = "\\Answered";
immutable string deleted = "\\Deleted";
immutable string recent = "\\Recent";

immutable string prefix = "Spaminex";

struct commandPrefix
{
  int m_sequence;
  string m_prefix = prefix;
  auto currentPrefix()
  {
    return prefix~m_sequence.to!string~" ";
  }
  auto opCall()
  {
    ++m_sequence;
    return currentPrefix;
  }
}


class IMAP : MailProtocol
{
private:
  commandPrefix prefix;
  Folder currentFolder;
  
  string chompQueryPrefix(in string message, in string prefix) @safe pure
  {
    string response;
    foreach(line; message.lineSplitter)
      {
	if (!line.startsWith(prefix)) {
	  response~=(line~endline);
	} else {
	  response~=(findSplitAfter(line,prefix)[1])~endline;
	}
      }
    return response;
  }


  
  final MessageStatus evaluateMessage(in string message, in string commandPrefix) const @safe
  {
    //  Change to enum
    // Good = OK response.
    // Bad = BAD response.
    // If command prefix not found, send "INCOMPLETE" and try to receive more information.
    foreach(ref line; message.lineSplitter) {
      if (line.startsWith(commandPrefix)) {
	auto x = split(line);
	if (x[1] == "OK") {
	  return MessageStatus.OK;
	} else {
	  return MessageStatus.BAD;
	}
      }
    } // If we didn't find the command prefix, it is incomplete. 
    return MessageStatus.INCOMPLETE;
  }


public:

  this(){}
  
  this(in string server, in ushort port) @safe 
  {
    m_socket = new MailSocket(server, port);
    if (port == 993) {
      if(m_socket.startSSL == false) {
	throw new SpaminexException("Failed to create SSL socket", "SSL Socket failure.");
      }
    }

    immutable string b = m_socket.receive.bufferToString();
    if(!evaluateMessage(b,".")) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }
  }

  override final bool login(in string username, in string password) @safe
  {
    auto x = query("LOGIN "~username~" "~password,No.multiline);
    if (x.status == MessageStatus.BAD)
      return false;
    getCapabilities(x.contents);
    m_folderList = folderList;

    foreach(folder; m_folderList)
      {
	if (folder.name.toUpper == "INBOX") {
	  currentFolder = folder;
	}
      }
    selectFolder(currentFolder);
    return true;
  }

  final void getCapabilities(in string serverResponse) @safe
  {
    m_capabilities = parse_capability_list(serverResponse);
    foreach(ref x; m_capabilities) {
      switch (x.toLower) {
      case "uid":
	m_supportUID = true;
	break;
      case "uidplus":
	m_supportUID = true;
	break;
      default:
	break;
      }
      
    }
    
  }
  override final string getQueryFormat(Command command) @safe pure
  {
    string commandText;
    
    switch(command)
      {
      case Command.Delete:
	commandText = "STORE %d +FLAGS (\\Deleted)";
	break;
      case Command.Close:
	commandText = "CLOSE";
	break;
      case Command.Logout:
	commandText = "LOGOUT";
	break;
      case Command.Copy:
	commandText = "COPY %d %s";
	break;
      default:
	break;
      }
    return commandText;
  }


  override final FolderList folderList() @safe
  {
    getIMAPFolderList;
    return m_folderList;
  }
  
  final void getIMAPFolderList() @safe
  {
    queryResponse response;
    immutable string thisQuery = "LIST \"\" \"%\"";
    response = query(thisQuery, No.multiline);
    if (response.status == MessageStatus.BAD) {
      return;
    }
    m_folderList = parseFolderList(response.contents);
    return;
  }


  
  override final bool loadMessages() @safe
  {
    selectFolder(currentFolder);

    queryResponse response;
    string messageQuery;
    m_messages.clear; // We load all again.  Clear any existing messages.
    
    ProcessMessageData pmd = new ProcessMessageData();
    
    for(int x = 1; x <= m_mailboxSize; x++)
      {
	Message m;
	messageQuery = "FETCH "~x.to!string~" BODY[HEADER]";
	response = query(messageQuery, Yes.multiline);

	if (response.status == MessageStatus.BAD) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);
	if (m_supportUID) {
	  messageQuery = "FETCH "~x.to!string~" UID";
	  auto response2 = query(messageQuery, No.multiline);
	  if (response.status == MessageStatus.BAD) {
	    throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	  }
	  string uid = parseUID(response2.contents);
	  m.uidl = uid;
	}
	m_messages.add(m);

      }
    return true;
  }
  
  final int getNumberOfMessages() @trusted
  // Returns the number of e-mails, or -1 in case of error.
  {
    immutable auto response = query("STAT");
    if (response.status == MessageStatus.BAD)
      return 0;

    immutable auto result = response.contents.split;
    auto numberOfMessages = result[0].to!int;
    m_mailboxSize = numberOfMessages;
    return m_mailboxSize;

  }


  override final void selectFolder(ref Folder folder) @safe
  {
    currentFolder = folder;
    queryResponse response;
    response = query("SELECT "~currentFolder.name);

    if(response.status == MessageStatus.BAD) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }

    // Parse folder flags or the quantity of messages in the folder.
    // Not interested in the rest, for now.

    foreach(ref lines; response.contents.lineSplitter) {
      if (lines.endsWith("EXISTS")) {
	  auto x = split(lines);
	  m_mailboxSize = x[x.length-2].to!int;
      }
    }
    return;
  }
  
  
  override final queryResponse query(in string command, Flag!"multiline" multiline = No.multiline) @safe
  {
    string end = (multiline == Yes.multiline) ? "\r\n.\r\n" : "\r\n";
    queryResponse response;
    m_socket.send(prefix()~command~endline);
    
    Buffer buffer = m_socket.receive;
    response.contents = buffer.text;
    debug { import std.stdio; writeln(" MESSAGE : ", response.contents);}

    // Evaluate response.
    immutable MessageStatus isOK = evaluateMessage(response.contents, prefix.currentPrefix);
    debug prefix.currentPrefix.writeln;
    while (isOK == MessageStatus.INCOMPLETE) {
      buffer.reset;
      buffer = m_socket.receive;
      response.contents ~= buffer.text;
    }
    /*
    if (isOK == MessageStatus.OK) {
      response.contents = chompQueryPrefix(message, prefix.currentPrefix);
    } else if (!isOK) {
      response.isValid = false;
      response.contents = chompQueryPrefix(message, prefix.currentPrefix);
    } else if
    }
    */
    return response;
  }
    
  override final string getUID(in int messageNumber) @safe
  {
    string UIDquery = "FETCH "~messageNumber.to!string~" UID";
    immutable auto UIDresponse = query(UIDquery);
    if (UIDresponse.status == MessageStatus.BAD) {
      throw new SpaminexException("IMAP transfer failure", "Failed to execute query "~UIDquery);
    } else {
      immutable auto results = parseUID(UIDresponse.contents);
      return results;
    }
  }


  override bool close() @safe
  {
    // First expunge
    auto response = query("EXPUNGE");
    if (response.status == MessageStatus.BAD) {
      throw new SpaminexException("Failed delete messages on server.","E-mails marked for deletion may not be deleted.");
    }

    
    auto messageQuery = getQueryFormat(Command.Close);
    response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SpaminexException("Failed close connection with server.","E-mails marked for deletion may not be deleted.");
    }

    
    // Now, logout...
    m_socket.close;
    return true;
  }

}

unittest
{
  MailProtocol d = new IMAP;
  commandPrefix p;
  assert(p() == "Spaminex1 ");
  assert(p() == "Spaminex2 ");
  assert(insertValueAndString(d.getQueryFormat(Command.Copy),4,"TEST") == "COPY 4 TEST");
  assert(insertValue(d.getQueryFormat(Command.Delete),4) == "STORE 4 +FLAGS (\\Deleted)");
  assert(d.getQueryFormat(Command.Logout) == "LOGOUT");

}
