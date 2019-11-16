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

import std.traits;
import std.algorithm;
import std.string;
import std.datetime;
import std.conv;
import std.regex;
import unfoldtext;
import processline;

struct Mandatory {}; // User Defined Attribute.  Set on all Message fields which cannot be left blank.


/****
 * This extracts the e-mail address component from a string where the e-mail
 * address is contained within angled brackets.
 */

string cleanEmailAddress(in string _email)
{

  string email;
  ptrdiff_t i = _email.indexOfAny("<"); // This means the e-mail address is enclosed in brackets.
  // If so, extract e-mail address.
  
  if (i != -1)
    {
      auto result = matchFirst(_email, regex(r"<.+>"));
      if (result.empty) {
	// If the regex extraction failed, set back to the orginal and hope for the best
	email = _email;
      } else {
	email = result.hit[1..$-1]; // 1..$-1 is to remove the parenthesis.
      }
    } else {
    email = _email;
  }

  return email;
}

unittest {
  assert(cleanEmailAddress("Recipient <test@test.com>") == "test@test.com");
  assert(cleanEmailAddress("<test@test2.com.au> Recipient") == "test@test2.com.au");
  assert(cleanEmailAddress("test@test.com") == "test@test.com");
  assert(cleanEmailAddress("<test@test.com>") == "test@test.com");
}

class Message
{
private:
  char[] m_message;
  string m_uidl;
  @Mandatory string m_subject;
  string m_date;
  @Mandatory string m_to;
  @Mandatory string m_from;
  string m_returnPath;
  string m_received;
  @Mandatory string m_message_ID;
  bool m_deleted = false;
  bool m_bounce = false;
  bool m_isSpam = false; // Innocent until proven guilty.
  bool m_loaded = false;
  bool m_isRead = false;
  uint m_messageNum; // The message number as per the server.  For POP
                        // servers this starts at 1 and is incremented.
  
public:

  this(in string _subject,
       in string _date,
       in string _to,
       in string _from,
       in string _returnPath,
       in string _received,
       in string _message_id,
       in string _uidl = "") @safe
  {
    m_uidl = _uidl;
    m_subject = _subject;
    m_date = _date;
    m_to = _to;
    m_from = _from;
    m_returnPath = _returnPath;
    m_received = _received;
    m_message_ID = _message_id;

    foreach(member; __traits(allMembers, Message))
      {
	static if(hasUDA!(__traits(getMember, Message, member), Mandatory))
	  {
	    if (__traits(getMember, this, member) == "") {
	      __traits(getMember, this, member) = "(none)";
	    }
	  }
      }
  }
  // Properties

  @property uint number() @safe const pure nothrow
  {
    return m_messageNum;
  }

  @property void number(uint num) @safe pure nothrow
  {
    m_messageNum = num;
  }
  
  @property bool loaded() @safe const pure nothrow
  {
    return m_loaded;
  }

  @property void loaded(in bool _loaded) @safe pure nothrow
  {
    m_loaded = _loaded;
  }
  
  @property bool deleted() @safe const pure nothrow
  {
    return m_deleted;
  }

  @property void deleted(in bool d) @safe pure nothrow
  {
    m_deleted = d;
  }

  @property void isRead(in bool d) @safe pure nothrow
  {
    m_isRead = d;
  }

  @property bool isRead() @safe const pure nothrow
  {
    return m_isRead;
  }
  
  @property string uidl() @safe const pure nothrow
  {
    return m_uidl;
  }

  @property void uidl(in string text) @safe pure nothrow
  {
    m_uidl = text;
  }
  
  @property string subject() @safe const pure nothrow
  {
    return m_subject;
  }
 
  @property string to() @safe const pure nothrow
  {
    return m_to;
  }

  @property string from() @safe const pure nothrow
  {
    return m_from;
  }
  
  @property string date() @safe const pure nothrow
  {
    return m_date;
  }
  
  @property string returnPath() @safe const pure nothrow
  {
    return m_returnPath;
  }

  @property string received() @safe const pure
  {
    string returnString;
    returnString = tr(m_received, ";", "\n");
    return returnString;
  }

  @property string message_id() @safe const pure nothrow
  {
    return m_message_ID;
  }

  
  @property bool isSpam() @safe const pure nothrow
  {
    return m_isSpam;
  }

  @property void isSpam(bool n) @safe pure nothrow
  {
    m_isSpam = n;
  }

  @property void bounce(bool n) @safe pure nothrow
  {
    m_bounce = n;
  }

  @property bool bounce() @safe pure nothrow
  {
    return m_bounce;
  }
  
}
