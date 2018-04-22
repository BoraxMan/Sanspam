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

module unfoldtext;
import conversion;
import std.string;

class UnfoldText
{
private:
  string m_UnfoldedText; // Final unfolded
  string[] m_textArray;

public:

  @property size_t length() const @safe
  {
    return m_textArray.length;
  }

  void addLine(in string text) @trusted
  {
    /* We need to decode before unfolding the text, because for Base64 encoded multi-lines
       in email headers, they are encoded separately. */
    m_textArray~=text.decodeText;
  }

  void clear() @safe
  {
    m_textArray.length = 0;
    m_UnfoldedText="";
  }

  string unfolded() @safe
  {
    scope(exit) clear;

    foreach(line; m_textArray) {
	string newstring = chomp(line);
	m_UnfoldedText~=newstring;
      }
    // Add end line back on.
    //m_UnfoldedText~="\r\n";
    m_UnfoldedText = m_UnfoldedText.strip;
    return m_UnfoldedText;
  }
}

unittest
{
  UnfoldText u = new UnfoldText();
  string text2 = "A single line message.\r\n";
  
  string text31 = "A multline message on\r\n";
  string text32 = " multiple\r\n";
  string text33 = " lines.\r\n";

  u.addLine(text2);
  auto result2 = u.unfolded;
  assert(result2 == "A single line message.");
  u.clear;
  assert(u.length == 0);

  u.addLine(text31);
  u.addLine(text32);
  u.addLine(text33);
  auto result3 = u.unfolded;
  assert(result3 == "A multline message on multiple lines.");  
}


