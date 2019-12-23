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

import std.typecons;
import std.conv;
import std.algorithm;
import std.string;
import std.base64;
import std.encoding;
import sanspamexception;

enum utfSeqStart = "=?";
enum utfSeqEnd = "?=";
enum space = hexString!"20";

enum encodingLabelUTF8 = "utf-8";
enum encodingLabelISO_8859_1 = "iso-8859-1";
enum encodingLabelISO_8859_2 = "iso-8859-2";

alias textEncodingType = Tuple!(charsetType, "charset", encodingType, "encoding", ptrdiff_t, "encodeHeaderLength");
// encodeHeaderLength is where the encoding information ends, and the encoded text starts.
// We use this to determine where we should start decoding the text.

enum charsetType {
  CLEAR_TEXT,
  UTF8,
  ISO8859_1,
  ISO8859_2,
  UNKNOWN
}

enum encodingType {
  ASCII,
  BASE64
} 

textEncodingType getTextEncodingType(in string text) @safe pure
{
  /* Function to determine the encoding type from supplied text.
     This return the text Encoding Type, which is a tuple containing both the character
     set used, and whether ASCII or BASE64 encoded. */
  textEncodingType te;
  immutable auto first = indexOf(text,"?");

  if (text[0..first].toLower == encodingLabelUTF8)
    te.charset = charsetType.UTF8;
  else if (text[0..first].toLower == encodingLabelISO_8859_1)
    te.charset = charsetType.ISO8859_1;
  else if (text[0..first].toLower == encodingLabelISO_8859_2)
    te.charset = charsetType.ISO8859_2;
  else
    te.charset = charsetType.UNKNOWN;

  if (text[first+1].toUpper == 'Q')
    te.encoding = encodingType.ASCII;
  else if (text[first+1].toUpper == 'B')
     te.encoding = encodingType.BASE64;
  else
    te.encoding = encodingType.ASCII;

  te.encodeHeaderLength = first+3;
  return te;
}

T hextoChar(T)(string input) @safe pure
  if (is(T == char) || is(T == Latin1Char) || is(T == Latin2Char))
  in
    {
      assert(input.length == 2);
      assert(input[0] >= '0');
      assert(input[0] <= 'F');
      assert(input[1] >= '0');
      assert(input[1] <= 'F');
    }
body
  {
    return cast(T)(parse!int(input,16));
  }

string base64Encode(string text) pure @trusted
{
  string output;
  return Base64.encode(cast(ubyte[])text);
}

string base64Decode(string text) pure
{

  string output;
  ubyte[] array = cast(ubyte[])text;
  auto decoded = Base64.decode(array);
  //text = "";
  foreach(x; decoded) {
    // Rebuild text as decoded characters;
    output~=x;
  }
  return output;
}

string decodeText(string text) 
{
  string output;
  int index;
  immutable textEncodingType te = getTextEncodingType(text);
  index += te.encodeHeaderLength;
  text = text[index..$];
  if (te.encoding == encodingType.BASE64) {
    text = text.base64Decode;
  }
  
  if (te.charset == charsetType.UTF8) {
    output ~= decodeUTF8!string(text);
  } else if (te.charset == charsetType.ISO8859_1) {
    output ~= decodeUTF8!Latin1String(text);
  } else if (te.charset == charsetType.ISO8859_2) {
    static if (is(Latin2String)) {
      // Some earlier compilers may not support Latin2String.
      // Only decode to Latin2String if possible, othewise default to UTF-8.
      output ~= decodeUTF8!Latin2String(text);
    } else {
      output ~= decodeUTF8!string(text);
    }
  } else if (te.charset == charsetType.UNKNOWN) {
    output ~= decodeUTF8!string(text); // If not known, use UTF-8 and hope for the best.
  }
  
  return output;
}

string decodeUTF8(T)(string text)
  if (is(T == string) || is(T == Latin1String) || is(T == Latin2String))
    
 {
  T decodedText;
  string output;
  int index;

  while(index < text.length) {

    if (text[index] == '=') {
      if ((index + 3) > text.length) {
	throw new SanspamException("Message format error","Incomplete code");
      }
      static if(is(T == string)) {
	string hchars = text[index+1..index+3];
	decodedText~=hextoChar!char(hchars);
      }
      static if (is(T == Latin1String)) {
	string hchars = text[index+1..index+3].to!string;
	decodedText~=hextoChar!Latin1Char(hchars);
      }
      /* Some earlier compilers may not support Latin2String.
	 Only decode to Latin2String if possible, othewise default to UTF-8. */
      
      static if (is(Latin2String)) {
	static if (is(T == Latin2String)) {
	  string hchars = text[index+1..index+3].to!string;
	  decodedText~=hextoChar!Latin2Char(hchars);
 	}
	
      } else {
      }
      index+=3;

    } else if (text[index] == '_') {
      static if(is(T == string)) {
	decodedText~=space;
      }
      static if(is(T == Latin1String)) {
	T converted;
	transcode(space, converted);
	decodedText~=converted;
      }
      static if (is(Latin2String)) {
	static if(is(T == Latin2String)) {
	  T converted;
	  transcode(space, converted);
	  decodedText~=converted;
	}
      }
      index++;

    } else {
      static if(is(T == string)) {
	decodedText~=text[index++];
      }
      static if(is(T == Latin1String)) {
	  T converted;
	  transcode(text[index++].to!string, converted);
	  decodedText~=converted;
	}

      static if (is(Latin2String)) {
	static if(is(T == Latin2String)) {
	  T converted;
	  transcode(text[index++].to!string, converted);
	  decodedText~=converted;
	}
	
      }
    }
  }
  
  static if(is(T == string)) {
    return decodedText;
  }
  static if(is(T == Latin1String)) {
    transcode(decodedText, output);
    return output;
  }
  static if (is(Latin2String)) {
    static if(is(T == Latin2String)) {
      transcode(decodedText, output);
      return output;
    }
  } else {
  }
}

string convertText(string text)
{
  string output;
  /* This function will convert the ASCII subject string
     into an actual UTF8 or ISO-8859 string.  It does this by looking
     for character sequences which indicate the start and end of a UTF8
     sequence, and then decoding the sequence and if necessary, doing base64 decode
     and storing the result as a UTF8 string.  If the start/end markers are not found
     the string is used as is.  If the string is less than two characters, it is skipped.
  */
  
  int x;
  while(x < text.length) {
    if (x < (text.length - 2) && text.length >= 2) {
      if (text[x..x+2] == utfSeqStart) {
	// Found an atom.
	x+=2;
	int z = x;
	// Find where the atom ends.
	if (text[x..$].toUpper.startsWith(encodingLabelUTF8.toUpper)) {
	  z+=encodingLabelUTF8.length+3;
	} else if (text[x..$].toUpper.startsWith(encodingLabelISO_8859_1.toUpper)) {
	  z+=encodingLabelISO_8859_1.length+3;
	} else if (text[x..$].toUpper.startsWith(encodingLabelISO_8859_2.toUpper)) {
	  z+=encodingLabelISO_8859_2.length+3;
	} else z+=2;
	
	auto zend = countUntil(text[x..$], utfSeqEnd);
	if (zend + x < z) {
	  auto zend2 = countUntil(text[z..$], utfSeqEnd);
	  zend = zend2 + (z-x);
	  }
	
	output~= decodeText(text[x..(x+zend)]);
	x+=zend+2;
	continue;
      }
      output~=text[x++];
    } else
      output~=text[x++];
  }
  return output;
}

unittest
{
  import std.stdio;

  assert(hextoChar!char("E2") == 226);
  assert(hextoChar!char("10") == 16);
  assert(hextoChar!Latin1Char("10") == 16);
  static if (is(Latin2String)) {
    assert(hextoChar!Latin2Char("10") == 16);
  }
  assert(hextoChar!char("FF") == 255);
  assert(hextoChar!char("00") == 0);
  static if (is(Latin2String)) {
    assert(hextoChar!Latin2Char("00") == 0);
  }
  assert(hextoChar!Latin1Char("00") == 0);
  assert(getTextEncodingType("utf-8?Q?stuff").charset == charsetType.UTF8);
  assert(getTextEncodingType("utf-8?Q?stuff").encoding == encodingType.ASCII);

  assert(getTextEncodingType("uTF-8?B?stuff").charset == charsetType.UTF8);
  assert(getTextEncodingType("uTF-8?B?stuff").encoding == encodingType.BASE64);
  assert(convertText("Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?=") == "Subject: If you can read this yo");

}
