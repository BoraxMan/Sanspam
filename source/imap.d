// Written in the D Programming language.
/*
 * Sanspam: Mailbox utility to delete/bounce spam on server interactively.
 * Copyright (C) 2018  Dennis Katsonis dennisk@netspace.net.au
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import std.algorithm;
import std.conv;
import std.typecons;
import std.string;
import std.format;
import std.array;
import std.regex;
import std.exception;
import std.range;
import buffer;
import config;
import imapparse;
import socket;
import mailprotocol;
import message;
import processline;
import sanspamexception;
import exceptionhandler;

string seen = "\\Seen";
string answered = "\\Answered";
string deleted = "\\Deleted";
string recent = "\\Recent";

immutable string prefix = "Sanspam";

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
	throw new SanspamException("Failed to create SSL socket", "SSL Socket failure.");
      }
    }

    immutable string b = m_socket.receive.bufferToString();
    if(!evaluateMessage(b,".")) {
      throw new SanspamException("Cannot create socket","Could not create connection with server.");
    }
  }

  override final bool login(in configstring username, in configstring password) @safe
  {
    auto x = query("LOGIN "~username~" "~password,No.multiline);
    if (x.status == MessageStatus.BAD || x.status == MessageStatus.INCOMPLETE) {
      throw new SanspamException("Failed to connect", x.contents~" : Incorrect username or password");
    }

    getCapabilities();
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

  final void getCapabilities() @safe
  {
    immutable auto serverResponse = query(getQueryFormat(Command.Capability));
    m_capabilities = parse_capability_list(serverResponse.contents.toUpper);
    if (serverResponse.status == MessageStatus.BAD) {
      m_supportUID = false;
      throw new SanspamException("Failed to get IMAP Capabilities.", "Capabilities command failed for IMAP.  Using default capabilities.");
    }
    if (find(m_capabilities, "UID").length) m_supportUID = true;
    if (find(m_capabilities, "UIDPLUS").length) m_supportUID = true;
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
      case Command.Capability:
	commandText = "CAPABILITY";
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

    if (m_mailboxSize == 0) {
      return true;  // Nothing more to do, if no messages.
    }
    
    messageQuery = "FETCH 1:"~m_mailboxSize.to!string~" BODY.PEEK[HEADER]";
    response = query(messageQuery, Yes.multiline);
    
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("Read Error","Failed to download e-mails.");
    }

    auto splitEmails = splitter(response.contents,regex(r"^\* [0-9]+ FETCH.*","m"));
    splitEmails.popFront; // Discard the first one, as its the null space between the first "* FETCH" line.

    if (m_supportUID) {
      messageQuery = "FETCH 1:"~m_mailboxSize.to!string~" UID";
      response = query(messageQuery, Yes.multiline);
      
      if (response.status == MessageStatus.BAD) {
	throw new SanspamException("Read Error","Failed to download UIDs.");
      }
    }

    auto splitUIDs = splitter(response.contents,regex(r"^\* [0-9]+ FETCH","m"));
    splitUIDs.popFront; // Discard the first one, as its the null space between the first "* FETCH" line.
    string[] uids;

    foreach(u; splitUIDs) {
      uids~=parseUID(u);
    }
    flaglist flags;

    int counter = 1;
    foreach(enumerator,message; splitEmails.enumerate(0))
      {
	Message m;
	m = pmd.messageFactory(message);

	messageQuery = "FETCH "~counter.to!string~" FLAGS";
	response = query(messageQuery, No.multiline);
	if (response.status == MessageStatus.BAD) {
	  throw new SanspamException("Read Error", "Failed to download FLAGS.");
	}
	flags = getFlags(response.contents);
	if (canFind(flags, "Seen")) {
	    m.isRead = true;
	} else {
	    m.isRead = false;
	}

	flags.length = 0;
	m.number = counter++;
	m_messages.add(m);
	if (m_supportUID) {
	  m.uidl = uids[enumerator];
	}
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
      throw new SanspamException("Cannot create socket","Could not create connection with server.");
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

    // Evaluate response.
    MessageStatus isOK = evaluateMessage(response.contents, prefix.currentPrefix);

    while (isOK == MessageStatus.INCOMPLETE) {
      buffer.reset;
      buffer = m_socket.receive;
      response.contents ~= buffer.text;
      isOK = evaluateMessage(response.contents, prefix.currentPrefix);
    }
    response.status = isOK;
    return response;
  }
    
  override final string getUID(in int messageNumber) @safe
  {
    string UIDquery = "FETCH "~messageNumber.to!string~" UID";
    immutable auto UIDresponse = query(UIDquery, No.multiline);
    if (UIDresponse.status == MessageStatus.BAD) {
      throw new SanspamException("IMAP transfer failure", "Failed to execute query "~UIDquery);
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
      throw new SanspamException("Failed delete messages on server.","E-mails marked for deletion may not be deleted.");
    }

    
    auto messageQuery = getQueryFormat(Command.Close);
    response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("Failed close connection with server.","E-mails marked for deletion may not be deleted.");
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
  assert(p() == "Sanspam1 ");
  assert(p() == "Sanspam2 ");
  assert(insertValue(d.getQueryFormat(Command.Copy),4,"TEST") == "COPY 4 TEST");
  assert(insertValue(d.getQueryFormat(Command.Delete),4) == "STORE 4 +FLAGS (\\Deleted)");
  assert(d.getQueryFormat(Command.Logout) == "LOGOUT");

}
