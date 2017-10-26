import std.stdio;
import std.conv;
import std.typecons : Tuple;
import std.string;
import std.format;
import std.array;
import std.exception;
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

  this(){}
  
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

  override final string getQueryFormat(Command command) @safe pure
  {
    string commandText;
    
    switch(command)
      {
      case Command.Delete:
	commandText = "STORE %d +FLAGS (\\Deleted)";
	break;
      case Command.Close:
	commandText = "EXPUNGE";
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

    m_messages.clear; // We load all again.  Clear any existing messages.

    ProcessMessageData pmd = new ProcessMessageData();

    for(int x = 1; x <= m_mailboxSize; x++)
      {
	Message m;
	string messageQuery = "FETCH "~x.to!string~" BODY[HEADER]";
	immutable queryResponse response = query(messageQuery,false);

	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);
	messageQuery = "FETCH "~x.to!string~" UID";
	auto response2 = query(messageQuery,false);
	if (response.isValid == false) {
	  throw new SpaminexException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	string uid = parseUID(response2.contents);
	writeln(response2.contents);
	writeln("UID ", uid);

	
	m_messages.add(m);

      }
    return true;
  }
    

  override final void selectFolder(in ref Folder folder) @safe
  {
    queryResponse response;
    response = query("SELECT "~folder.name);

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

  
  override final queryResponse query(in string command, bool multiline = false) @safe
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
  MailProtocol d = new IMAP;
  commandPrefix p;
  assert(p() == "Spaminex1 ");
  assert(p() == "Spaminex2 ");
  assert(insertValueAndString(d.getQueryFormat(Command.Copy),4,"TEST") == "COPY 4 TEST");
  assert(insertValue(d.getQueryFormat(Command.Delete),4) == "STORE 4 +FLAGS (\\Deleted)");
  assert(d.getQueryFormat(Command.Logout) == "LOGOUT");

}
