import std.typecons;
import std.stdio;
import std.conv;
import std.algorithm;
import std.string;
import std.base64;
import std.encoding;
import spaminexexception;

immutable string utfSeqStart = "=?";
immutable string utfSeqEnd = "?=";
immutable string space = x"20";
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

textEncodingType getCharsetTypeEncodingType(in string text) @safe pure
{
  textEncodingType te;
  immutable auto first = indexOf(text,"?");

  if (text[0..first].toLower == "utf-8")
    te.charset = charsetType.UTF8;
  else if (text[0..first].toLower == "iso-8859-1")
    te.charset = charsetType.ISO8859_1;
  else if (text[0..first].toLower == "iso-8859-2")
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

void base64Decode(ref string text)
{
  string output;
  ubyte[] array = cast(ubyte[])text;
  auto decoded = Base64.decode(array);
  text = "";
  foreach(ref x; decoded) {
    // Rebuild text as decoded characters;
    text~=x;
  }

}

string decode2(string text)
{
  string output;
  int index;
  immutable textEncodingType te = getCharsetTypeEncodingType(text);
  index += te.encodeHeaderLength;
  text = text[index..$];

  if (te.encoding == encodingType.BASE64) {
    text.base64Decode;
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
{
  T decodedText;
  string output;
  int index;

  while(index < text.length) {

    if (text[index] == '=') {
      if ((index + 3) > text.length) {
	throw new SpaminexException("Message format error","Incomplete code");
      }
      static if(is(T == string)) {
	immutable string hchars = text[index+1..index+3];
	decodedText~=hextoChar!char(hchars);
      }
      static if (is(T == Latin1String)) {
	immutable string hchars = text[index+1..index+3].to!string;
	decodedText~=hextoChar!Latin1Char(hchars);
      }
      /* Some earlier compilers may not support Latin2String.
	 Only decode to Latin2String if possible, othewise default to UTF-8. */
      
      static if (is(Latin2String)) {
	static if (is(T == Latin2String)) {
	  immutable string hchars = text[index+1..index+3].to!string;
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

string decodeText(string text)
{
  string output;

  int x;
  while(x < text.length) {
    if (x < (text.length - 2)) {
      if (text[x..x+2] == utfSeqStart) {
	// Found an atom.
	x+=2;
	// Find where the atom ends.
	auto zend = countUntil(text[x..$], "?=");
	output~= decode2(text[x..(x+zend)]);
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
  writeln(decodeText("=?ISO-8859-2?Q?SDF?="));

  assert(getCharsetTypeEncodingType("utf-8?Q?stuff").charset == charsetType.UTF8);
  assert(getCharsetTypeEncodingType("utf-8?Q?stuff").encoding == encodingType.ASCII);

  assert(getCharsetTypeEncodingType("uTF-8?B?stuff").charset == charsetType.UTF8);
  assert(getCharsetTypeEncodingType("uTF-8?B?stuff").encoding == encodingType.BASE64);
  writeln(decodeText("Subject: =?utf-8?Q?Re:_New_loan_listing_=E2=80=93_$75k_for_36_months_?==?utf-8?Q?@15.5%_p.a._Secured_=E2=80=93_1_week_listing_only!?="));
  writeln(decodeText("Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?="));
  writeln(decodeText("=?UTF-8?B?2KfZhNiu2LfZiNin2Kog2KfZhNiq2Yog2KrYrNmF2Lkg2KjZitmG?= =?UTF-8?B?INit2YHYuCDYp9mE2YLYsdin2ZPZhiDYp9mE2YPYsdmK2YUg2YjZgQ==?= =?UTF-8?B?2YfZhdmHINmF2YXYpyDYp9mU2YXZhNin2Ycg2KfZhNi52YTYp9mF?= =?UTF-8?B?2Kkg2LnYqNivINin2YTZhNmHINin2YTYutiv2YrYp9mGLnBkZg==?="));
  writeln(decodeUTF8!Latin1String("Keld_J=F8rn_Simonsen"));
}
