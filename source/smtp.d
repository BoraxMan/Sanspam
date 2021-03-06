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

module SMTP_mod;
import std.string;
import std.exception;
import std.conv;
import std.typecons;
import socket;
import buffer;
import config;
import message;
import conversion;
import mailprotocol;
import sanspamexception;
import processline;
import exceptionhandler;

string[] successCodes = ["220","250","354","221","334","235"];
string[] failureCodes = ["5","503","504","501","432","534","538","454","530"];

enum SMTP_Authentication
  {
   None,
   Login,
   CRAM_MD5
  }

class SMTP : MailProtocol
{
  SMTP_Authentication authenticationMethod = SMTP_Authentication.None;
  
private:
  bool evaluateMessage(ref string message) const @safe
  {
    //  Whether there response is OK or ERROR.
    if (message[0] == '2' || message[0] == '3') {
      return true;
    } else if(message[0] == '5' || message[0] == '4') {
      return false;
    } else {
      throw new SanspamException("Malformed server response","Could not determine message success.");
    }
  }
  
public:
  this() {}


  final this(in configstring server, in ushort port, in configstring smtp_authtype) @safe
  {
    m_socket = new MailSocket(server, port);
    auto b = m_socket.receive.bufferToString;
    if(!evaluateMessage(b)) {
      throw new SanspamException("Cannot create socket","Could not create connection with server.");
    }

    if (!smtp_authtype.isNull)
      {  //  Only determine if an authtype option was defined.
	switch (smtp_authtype.get.toLower)
	  {
	  case "none":
	    authenticationMethod = SMTP_Authentication.None;
	    break;
	  case "login":
	    authenticationMethod = SMTP_Authentication.Login;
	    break;
	  case "cram-md5":
	    authenticationMethod = SMTP_Authentication.CRAM_MD5;
	    break;
	  default:
	    authenticationMethod = SMTP_Authentication.None;
	    break;
	  }
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
    return "";
  }

  override final bool login(in configstring username, in configstring password) @safe
  {
    queryResponse response;
    
    string loginQuery = "HELO "~username.get;
    auto x = query(loginQuery);
    if (x.status == MessageStatus.BAD)
      return false;

    m_connected = true;
    
    if (authenticationMethod == SMTP_Authentication.Login)
      {
	loginQuery = "AUTH LOGIN";
	response = query(loginQuery);
	if (response.status == MessageStatus.BAD) {
	  throw new SanspamException("SMTP Message","Failed to login");
	}

	loginQuery = base64Encode(username.get);
	response = query(loginQuery);
	if (response.status == MessageStatus.BAD) {
	  throw new SanspamException("SMTP Message","Failed to login");
	}
	loginQuery = base64Encode(password.get);
	response = query(loginQuery);
	if (response.status == MessageStatus.BAD) {
	  throw new SanspamException("SMTP Message","Failed to login");
	}
	return true;
      }
    return false;
  }
  
  override final queryResponse query(in string command, Flag!"multiline" multiline = No.multiline) @safe 
  {
    queryResponse response;
    m_socket.send(command~endline);
    string message = m_socket.receive().bufferToString;

    // Evaluate response.
    immutable bool isOK = evaluateMessage(message);
    
    if (isOK) {
      response.status = MessageStatus.OK;
      response.contents = message;
    } else if(!isOK) {
      response.status = MessageStatus.BAD;
      response.contents = message;
    }
    return response;
  }

  override final string getQueryFormat(Command command) @safe pure
  {
    string commandText;
    
    switch(command)
      {
      case Command.Close:
	commandText = "QUIT";
	break;
      case Command.Logout:
	commandText = "LOGOUT";
	break;
      default:
	break;
	
      }
    return commandText;
  }

  override final bool loadMessages() @safe
  {
    return true;
  }

  override final void selectFolder(ref Folder folder) @safe
  {
    return;
  }

  override final FolderList folderList() @safe
  {
    return m_folderList;
  }
  


  final bounceMessage(in string recipient, in string domain, in string message)
  {
    auto messageQuery = "MAIL FROM: <MAILER-DAEMON@"~domain~">";
    auto response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("SMTP Message","Failed to send SMTP message");
    }

    messageQuery = "RCPT TO:"~recipient;
    response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("SMTP Message","Failed to send SMTP message 2");
    }

    messageQuery = "DATA";
    response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("SMTP Message","Failed to send SMTP message 3");
    }

    messageQuery = message;
    response = query(messageQuery);
    if (response.status == MessageStatus.BAD) {
      throw new SanspamException("SMTP Message","Failed to send SMTP message 5");
    }
    close;
  }
}

unittest
{
}
