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

immutable string TOK_FLAGS="FLAGS";

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

size_t parseStatus(in string response) @safe pure
{
  return parseUID(response).to!int;
}
  
  

string parseUID(in string response) @safe pure
{
  size_t pos;
  auto text = parenthesisContents(response,'(',')', pos);
  auto uid = text.split;
  return uid[1].to!string;
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
  return flags[1..$];  // First flag is empty
}

string parenthesisContents(in string text, in char openparen, in char closeparen, ref size_t closeParenPos) @safe pure
{
  auto openParenPos = text.countUntil(openparen);
  closeParenPos = (text[openParenPos+1..$].countUntil(closeparen)) + openParenPos + 1;
  return text[openParenPos+1..closeParenPos];
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
       auto mailboxFlags = parenthesisContents(line,'(',')', closepos);
       folder.flags = parse_flag_list(mailboxFlags);
       folder.quotedchar = parenthesisContents(line,'\"','\"', closepos);
       folder.name = strip(line[++closepos..$]);
       folders~=folder;
     }
   }
   
   return folders;
   
 }

unittest {
  size_t pos;
  writeln("FLAGS");
  writeln(parse_flag_list("\\Answered \\Flagged \\Deleted \\Seen \\Draft NonJunk"));
  FolderList f = parseFolderList("* LIST (\\HasNoChildren \\TEST) \"/\" Sent\n* LIST (\\A) \"a\" DENNIS KATSONIS\nSpaminex3 OK\n");
  writeln(f);
  writeln(parenthesisContents("This is a(test).",'(',')',pos));
  writeln(parse_capability_list("* CAPABILITY STARTTLS IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE SORT SORT=DISPLAY THREAD=REFERENCES THREAD=REFS THREAD=ORDEREDSUBJECT MULTIAPPEND URL-PARTIAL CATENATE UNSELECT CHILDREN NAMESPACE UIDPLUS LIST-EXTENDED I18NLEVEL=1 CONDSTORE QRESYNC ESEARCH ESORT SEARCHRES WITHIN CONTEXT=SEARCH LIST-STATUS SPECIAL-USE BINARY MOVE SEARCH=FUZZY QUOTA"));
  writeln("SDFSDFSDFSDF");
  //  writeln(parenthesisContents("\"no@test.com\" NO TEST",'\"','\"',pos));
}
