/*
 * Spaminex: Mailbox utility to delete/bounce spam on server interactively.
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

import mailprotocol;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;
import std.string;
import std.regex;

string TOK_FLAGS="FLAGS";

capabilities parse_capability_list(in string response) @safe pure
{
  /*
    capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    *(SP capability)
    ; Servers MUST implement the STARTTLS, AUTH=PLAIN,
    ; and LOGINDISABLED capabilities
    ; Servers which offer RFC 1730 compatibility MUST
    ; list "IMAP4" as the first capability. */
  auto listedCapabilities = findSplitAfter(response,"CAPABILITY");
  capabilities capability = listedCapabilities[1].strip.split(" ");
  return capability;
}

size_t parseStatus(in string response) @safe 
{
  return parseUID(response).to!int;
}

string parseUID(in string response) @safe
{
  auto text = matchFirst(response, regex(r"\([[Uu][Ii][Dd] 0-9]+\)"));
  if (text.length == 0) {
    return "";
  }
  auto uid = text.hit[5..$-1]; // Convert the digits only.
  return uid;
}
  
flaglist parse_flag_list(in string response) @safe pure
{
  // flag-list       = "(" [flag *(SP flag)] ")"
  
  /*
    flag            = "\Answered" / "\Flagged" / "\Deleted" /
    "\Seen" / "\Draft" / flag-keyword / flag-extension
    ; Does not include "\Recent"
    
    Here we are receiving the flag-list contained within the parenthesis.
  */
  
  flaglist flags = response.strip.split("\\");
  foreach(ref x; flags) {
    x = x.strip;  // Strip space at the end and start, if any.
  }
  return flags[1..$];  // First flag is empty
}


FolderList parseFolderList(in string response) @safe
 {
   /*   mailbox-list    = "(" [mbx-list-flags] ")" SP
	(DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox. 
	Everything up to the space is the mbx-list-flags   
*/

   //Find the [mb-list-flags]
   FolderList folders;
   foreach(line; lineSplitter(response)) {
     if (line.startsWith("*")) {
       Folder folder;
       size_t closepos;
       auto result = matchFirst(line, regex(r"\(.+\)"));
       if (result.length == 0) {
	 continue;
       }
       auto mailboxFlags = result.hit[1..$-1]; // 1..$-1 is to remove the parenthesis.
       folder.flags = parse_flag_list(mailboxFlags);
       result = matchFirst(line, regex("\".*\""));
       folder.quotedchar = result.hit[1..$-1];
       folder.name = strip(result.post);
       folders~=folder;
     }
   }
   
   return folders;
   
 }

unittest {
  size_t pos;
  assert(parseUID("TEST (UID 444) STUFF") == "444");
  auto flags = parse_flag_list("\\Answered \\Flagged \\Deleted \\Seen \\Draft NonJunk");

  assert(parseUID("NULL") == "");

  assert(canFind(flags,"Answered") == true);
  assert(canFind(flags,"Flagged") == true);
  assert(canFind(flags,"Deleted") == true);
  assert(canFind(flags,"Seen") == true);
  assert(canFind(flags,"Draft NonJunk") == true);
  
}
