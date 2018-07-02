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

// A smart buffer class.  Based on OutBuffer with a few additions

import std.outbuffer;

const standardBufferSize = 32768;

class Buffer : OutBuffer
{
  this() @safe
  {
    reserve(standardBufferSize);
  }

  void reset() @safe
  {
    data.length = 0;
    offset = 0;
  }

  string text() @safe
  {
    return toString();
  }

  size_t length() @safe
  {
    return data.length;
  }
}
