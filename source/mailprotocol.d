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

// Super class for Mail protocol handling.

import std.typecons;
import std.string;
import std.array;
import std.format;
import std.algorithm;
import processline;
import config;
import message;
import socket;
import sanspamexception;
import processline;

struct Encrypted {} // May get implemented later.
struct ConfigOption {} // May be used later.

alias string[] flaglist;
alias string[] capabilities;
alias Folder[] FolderList;

enum defaultBufferSize = 65536;
enum MessageStatus {
  OK,
  BAD,
  INCOMPLETE
}

enum Command {
  Delete,
  Close,
  Logout,
  Capability,
  Copy  // IMAP Only.
}

struct Folder {
  flaglist flags;
  string quotedchar;
  string name;
  size_t numberMessages;
}

alias queryResponse = Tuple!(MessageStatus, "status", string, "contents");


string insertValue(in string format, in int value, in string text = "") pure
{
  /* Convienence function to insert a value in a specified place 
     within a string, or if required, a value and text.
  */
  auto message = appender!string();
  if (text != "") {
    message.formattedWrite(format,value,text);
  } else {
    message.formattedWrite(format,value);
  }
  return(message.data);
}


struct Messages
{
  Message[] m_messages;

  this(Messages _messages)
  {
    this.m_messages = _messages.m_messages;
  }
  
  final void add(Message message) @safe
  {
    m_messages~=message;
  }
  
  final void clear() @safe
  {
    m_messages.length = 0;
  }
  
  final bool empty() @safe const pure
  {
    return (m_messages.length == 0);
  }

  final void popFront() @safe
  {
    m_messages = m_messages[1..$];
  }

  final size_t length() @safe const pure
  {
    return m_messages.length;
  }
  
  final Message front() @safe pure
  {
    return(m_messages[0]);
  }
  
  final ref auto opIndex(int n)
    in
      {
	assert(n <= m_messages.length);
	assert(n >= 0);
      }
  body
    {
      return m_messages[n];
    }

}


class MailProtocol

{
  string m_mailboxName;
  Messages m_messages;

  bool m_connected = false;
  int m_mailboxSize;
  bool m_supportUID = false;
  bool m_supportTOP = false;

  @ConfigOption string m_popServer;
  @ConfigOption string m_smtpServer;
  @ConfigOption ushort m_port;
  @ConfigOption string m_username;
  @ConfigOption @Encrypted string m_password;

  MailSocket m_socket;
  string endline = "\r\n";
  char[defaultBufferSize] m_buffer;
  string[] m_capabilities;
  FolderList m_folderList;


public:
  abstract bool login(in configstring username, in configstring password) @safe;
  abstract string getUID(in int messageNumber) @safe;
  FolderList folderList() @safe
  {
    return m_folderList;
  }
  abstract bool loadMessages() @safe;
  abstract void selectFolder(ref Folder folder) @safe;
  abstract queryResponse query(in string command, Flag!"multiline" multiline = No.multiline) @safe;
  abstract string getQueryFormat(Command command) @safe pure;

 @property final ref Messages messages() @safe pure
  {
    return m_messages;
  }
  
  final bool startTLS(EncryptionMethod method = EncryptionMethod.TLSv1_2) @trusted
  {
    string message = "STARTTLS";
    auto x = query(message);
    if (x.status == MessageStatus.BAD)
      return false;

    m_socket.startSSL(method);
    return true;
  }

  bool close() @safe
  {
    string messageQuery = getQueryFormat(Command.Close);
    auto response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException(response.contents,response.contents);
    }
    
    // Now, logout...
    m_socket.close;
    return true;
  }
   

  bool checkUID(in string uidl, in int messageNumber)
  {
    string thisUID;
    /*  Lets double check to make sure that the message we are deleting is the one
	we want to delete.
	We will get the UID again and compare against the string provided, if one exists.
	This makes sure that we don't delete the wrong message, in case something else has happened which
	has changed the mailbox since this program was started, or some other software issue or strange
	bug or occurence.
    */
    
    {
      thisUID = getUID(messageNumber);
      if (uidl.length > 0) {
	if (thisUID != uidl) {
	  return false;
	}
      }
    }
    return true;
  }

  
  final bool remove(in string uidl)
  {
    bool result;
    auto m = m_messages.find!(a => a.uidl == uidl).front;
    result = remove(m.number, m.uidl);
    return result;
  }

 
  final bool remove(in int messageNumber, in string uidl = "", in string trashFolder = "")
    in
      {
	assert (messageNumber >= 0);
      }

  body {
    auto targetMessage = messages.find!(a => a.number == messageNumber).front;
    
    // Check the UID matches the message number we are deleting, if we have UID supported that is.
    if (m_supportUID) {
      immutable bool result = checkUID(uidl, targetMessage.number);
      if (!result) {
	throw new SanspamException("Message mismatch", "Was trying to delete message with UID "~uidl~" but got "~getUID(targetMessage.number)~" instead.");
      }
      // If we got this far, we don't have a UID to check against, or the check passed.  So delete the message.

      // But first, if we have specified a Trash folder, copy to trash.
      if (trashFolder != "") { // A folder has been specified.
	string trashMessageQuery = insertValue(getQueryFormat(Command.Copy),targetMessage.number, trashFolder);
	auto trashResponse = query(trashMessageQuery);
	if (trashResponse.status == MessageStatus.BAD) {
	  throw new SanspamException("Could not move message to Trash", "Error moving message to "~trashFolder~".  Options are to check the correct Trash folder is specified, or delete the message without moving to Trash.");
	}
      }

      string messageQuery = insertValue(getQueryFormat(Command.Delete), targetMessage.number);
      auto response = query(messageQuery);
      if (response.status == MessageStatus.OK) {
	targetMessage.deleted = true;
	return true;
      }
    }
    return false;
  }
}


unittest
{
  import std.stdio;
  string test1 = "TEST %d TEST";
  string result1;
  result1 = insertValue(test1,44);

  assert(result1 == "TEST 44 TEST");

  string test2 = "TEST %d %s TEST";
  string result2;
  result2 = insertValue(test2,414, "DENNIS");

  assert(result2 == "TEST 414 DENNIS TEST");
}
