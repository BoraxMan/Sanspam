import std.stdio;
import std.conv;
import std.typecons : Tuple;
import std.string;
import imapparse;
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
  
  string chompQueryPrefix(in string message, in string prefix) @safe pure
  {
    string response;
    foreach(line; message.lineSplitter)
      {
	if (!line.startsWith(prefix)) {
	  response~=(line~endline);
	}
      }
    return response;
  }
  
  final bool evaluateMessage(in string message, in string commandPrefix) const @safe
  {
    foreach(ref line; message.lineSplitter) {
      if (line.startsWith(commandPrefix)) {
	auto x = split(line);
	if (x[1] == "OK") {
	  return true;
	} else {
	  return false;
	}
      }
    }
    return true;
  }


public:
  
  this(in string server, in ushort port) @safe 
  {
    m_socket = new MailSocket(server, port);
    immutable string b = m_socket.receive();
    if(!evaluateMessage(b,".")) {
      throw new SpaminexException("Cannot create socket","Could not create connection with server.");
    }
  }

  override final bool login(in string username, in string password) @safe
  {
    auto x = query("LOGIN "~username~" "~password,false);
    if (!x.isValid)
      return false;
    return true;
  }

  override final FolderList folderList() @safe
  {
    getIMAPFolderList;
    return m_folderList;
  }
  
  final void getIMAPFolderList() @safe
  {
    queryResponse response;
    immutable string thisQuery = "LIST \"\" \"*\"";
    response = query(thisQuery,false);
    if (!response.isValid) {
      return;
    }
    m_folderList = parseFolderList(response.contents);
    return;
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
	string messageQuery = "FETCH "~x.to!string~" BODY[HEADER]";
	immutable auto response = query(messageQuery,true);
	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);

	messageQuery = "FETCH "~x.to!string~" UID";
	immutable auto response = query(messageQuery,true);
	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}

	string uid = parseUID(response.contents);
	writeln("UID ", uid);

	
	m_messages.add(m);

      }
    return true;
  }
    

  override final void selectFolder(in ref Folder folder) @safe
  {
    queryResponse response;
    writeln(folder.name);
    response = query("SELECT "~folder.name);
    writeln(response.contents);

    if(!response.isValid) {
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
    writeln(m_mailboxSize);
    return;
  }
		  
  final queryResponse query(in string command, bool multiline = false) @safe
  {
    queryResponse response;
    m_socket.send(prefix()~command~endline);
    immutable string message = m_socket.receive(multiline);

    // Evaluate response.
    immutable bool isOK = evaluateMessage(message, prefix.currentPrefix);

    if (isOK) {
      response.isValid = true;
      response.contents = chompQueryPrefix(message, prefix.currentPrefix);
    } else if (!isOK) {
      response.isValid = false;
      response.contents = chompQueryPrefix(message, prefix.currentPrefix);

    }
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
  assert(p() == "Spaminex1 ");
  assert(p() == "Spaminex2 ");
}
